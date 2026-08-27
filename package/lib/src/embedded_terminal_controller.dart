/*
 * Package: Flutter-EmbeddedTerminal
 * Author: Ruturaj V Patki
 * Email: ruturajvpatki@zohomail.com
 *
 * Copyright 2026 Ruturaj V Patki
 * Originally authored by Ruturaj V Patki.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xterm/xterm.dart';
import 'pty/pty_session.dart';
import 'pty/pty_factory.dart';
import 'terminal_events.dart';

/// A controller that manages command execution and terminal interaction.
///
/// It isolates consuming applications from low-level details like process management,
/// streams, PTYs, and xterm internals.
class EmbeddedTerminalController extends ChangeNotifier {
  /// The underlying xterm terminal instance.
  final Terminal terminal;

  /// Controls terminal view interactions like selection and cursor style.
  final TerminalController terminalController;

  PtySession? _ptySession;
  bool _isRunningProgrammatic = false;
  String? _currentCommand;
  String? _workingDirectory;
  Map<String, String>? _environment;

  bool _isInteractive = true;
  DateTime? _commandStartTime;
  StreamSubscription<List<int>>? _outputSubscription;
  bool _isDisposed = false;

  /// Lifecycle callback triggered when a command starts executing.
  void Function(CmdRunStartEvent)? onCmdRunStart;

  /// Lifecycle callback triggered when a command completes successfully or with a non-zero exit code.
  void Function(CmdRunCompleteEvent)? onCmdRunComplete;

  /// Lifecycle callback triggered when a command fails to start or encounters an infrastructure error.
  void Function(CmdRunErrorEvent)? onCmdRunError;

  /// Creates a new [EmbeddedTerminalController].
  EmbeddedTerminalController()
      : terminal = Terminal(),
        terminalController = TerminalController() {
    // Forward user keystrokes from the terminal emulator to the PTY session.
    terminal.onOutput = (data) {
      write(data);
    };
  }

  /// Whether a programmatic command is currently running in the pseudo-terminal.
  bool get isRunning => _isRunningProgrammatic;

  /// The active programmatic command string, or null if no command is running.
  String? get currentCommand => _currentCommand;

  /// Gets the current working directory of the terminal session.
  String? get workingDirectory => _workingDirectory;

  /// Sets the working directory.
  ///
  /// If interactivity is enabled and no programmatic command is running,
  /// this will restart the background interactive shell session in the new directory.
  set workingDirectory(String? value) {
    if (_workingDirectory == value) return;
    _workingDirectory = value;
    notifyListeners();

    if (_isInteractive && !_isRunningProgrammatic) {
      _startBackgroundShell();
    }
  }

  /// Gets whether user input is enabled/interactive.
  bool get isInteractive => _isInteractive;

  /// Sets whether user input is interactive.
  ///
  /// If changed to true and no programmatic command is running, starts the background interactive shell.
  /// If changed to false, stops the background interactive shell and clears the terminal view.
  set isInteractive(bool value) {
    if (_isInteractive == value) return;
    _isInteractive = value;
    notifyListeners();

    if (_isInteractive) {
      if (!_isRunningProgrammatic) {
        _startBackgroundShell();
      }
    } else {
      if (!_isRunningProgrammatic) {
        _cleanupSession();
        terminal.write(
          '\x1B[2J\x1B[H',
        ); // Clear prompt when interactive mode is disabled
      }
    }
  }

  /// Starts executing a specific programmatic command inside the embedded pseudo-terminal (PTY).
  ///
  /// Throws a [StateError] if a command is already running.
  Future<void> runCommand(
    String command, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (_isRunningProgrammatic) {
      throw StateError(
        'A command is already running in this terminal session.',
      );
    }

    // Stop background interactive shell if running
    _cleanupSession();

    _isRunningProgrammatic = true;
    _currentCommand = command;
    final activeWorkingDirectory = workingDirectory ?? _workingDirectory;
    _environment = environment;
    _commandStartTime = DateTime.now();
    notifyListeners();

    final startEvent = CmdRunStartEvent(
      command: command,
      workingDirectory: activeWorkingDirectory,
      startTime: _commandStartTime!,
    );
    onCmdRunStart?.call(startEvent);

    // Clear terminal screen and reset cursor prior to starting
    terminal.write('\x1B[2J\x1B[H');

    try {
      final cols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
      final rows = terminal.viewHeight > 0 ? terminal.viewHeight : 25;

      _ptySession = PtyFactory.start(
        command: command,
        workingDirectory: activeWorkingDirectory,
        environment: environment,
        columns: cols,
        rows: rows,
      );

      _outputSubscription = _ptySession!.output.listen(
        (data) {
          try {
            // Decode binary data with allowMalformed: true to prevent crashing on invalid UTF-8 chunks.
            terminal.write(utf8.decode(data, allowMalformed: true));
          } catch (_) {
            // Fail-safe: write string characters directly if decoder fails completely.
            terminal.write(String.fromCharCodes(data));
          }
        },
        onError: (err) {
          _handleExecutionError(err.toString(), err);
        },
        onDone: () async {
          await _handleExecutionDone();
        },
      );
    } catch (err) {
      _handleExecutionError(err.toString(), err);
      rethrow;
    }
  }

  /// Programmatically stops the currently running command.
  ///
  /// Terminates the process and cleans up PTY resources.
  Future<void> stopCommand() async {
    if (!_isRunningProgrammatic) return;

    final command = _currentCommand ?? '';
    final workingDir = _workingDirectory;
    final startTime = _commandStartTime ?? DateTime.now();

    _cleanupSession();
    _isRunningProgrammatic = false;
    notifyListeners();

    final completeEvent = CmdRunCompleteEvent(
      command: command,
      workingDirectory: workingDir,
      startTime: startTime,
      exitCode: -1, // -1 denotes manually stopped/killed
      completionTime: DateTime.now(),
      duration: DateTime.now().difference(startTime),
    );
    onCmdRunComplete?.call(completeEvent);

    // Auto-restart interactive shell if enabled
    if (_isInteractive) {
      _startBackgroundShell();
    }
  }

  /// Restarts the last executed command, stopping it first if it is still running.
  Future<void> restartCommand() async {
    final commandToRestart = _currentCommand;
    final workingDir = _workingDirectory;
    final env = _environment;

    if (commandToRestart == null) {
      throw StateError('No previous command was run to restart.');
    }

    if (_isRunningProgrammatic) {
      await stopCommand();
    }

    // Small delay to allow process resources to be released
    await Future.delayed(const Duration(milliseconds: 100));

    await runCommand(
      commandToRestart,
      workingDirectory: workingDir,
      environment: env,
    );
  }

  /// Clears the terminal screen.
  Future<void> clear() async {
    terminal.write('\x1B[2J\x1B[H');
  }

  /// Extracts the plain text content of the terminal. If there is a text selection,
  /// returns the selected text; otherwise, returns the entire active buffer content.
  String getTerminalText() {
    final selection = terminalController.selection;
    if (selection != null) {
      return terminal.buffer.getText(selection);
    }

    final buffer = StringBuffer();
    final linesCount = terminal.buffer.lines.length;
    for (var i = 0; i < linesCount; i++) {
      final line = terminal.buffer.lines[i];
      // Get only the trimmed content from the cell buffer up to the last non-empty column
      final lineText = line.getText(0, line.getTrimmedLength());
      buffer.write(lineText);
      // Append a newline only if the current line does not overflow/wrap to the next
      if (!line.isWrapped && i < linesCount - 1) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  /// Programmatically copies the entire terminal text to the system clipboard.
  Future<void> copyToClipboard() async {
    final text = getTerminalText();
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Programmatically saves the entire terminal text to a text file.
  /// Shows a native save file dialog. Returns true if the file was saved,
  /// and false if the dialog was cancelled or saving failed.
  Future<bool> exportTerminalText() async {
    try {
      final text = getTerminalText();
      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'Export Terminal Output',
        fileName: 'terminal_export.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(text);
        return true;
      }
    } catch (_) {
      // Return false on error
    }
    return false;
  }

  /// Programmatically writes raw input data directly to the PTY process.
  ///
  /// This is independent of the widget's interactive state.
  Future<void> write(String input) async {
    if (_ptySession != null) {
      _ptySession!.write(input);
    }
  }

  /// Notifies the PTY of terminal resize events.
  Future<void> resize(int columns, int rows) async {
    if (_ptySession != null) {
      _ptySession!.resize(columns, rows);
    }
  }

  void _startBackgroundShell() {
    _cleanupSession();

    try {
      final cols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
      final rows = terminal.viewHeight > 0 ? terminal.viewHeight : 25;

      // Start PTY session with no command (which starts the default interactive shell)
      _ptySession = PtyFactory.start(
        workingDirectory: _workingDirectory,
        columns: cols,
        rows: rows,
      );

      _outputSubscription = _ptySession!.output.listen(
        (data) {
          try {
            terminal.write(utf8.decode(data, allowMalformed: true));
          } catch (_) {
            terminal.write(String.fromCharCodes(data));
          }
        },
        onError: (_) {},
        onDone: () {
          if (!_isRunningProgrammatic && _ptySession != null) {
            _cleanupSession();
          }
        },
      );
    } catch (_) {
      // Fail silently if native shell cannot start in the background
    }
  }

  void _cleanupSession() {
    _outputSubscription?.cancel();
    _outputSubscription = null;

    try {
      _ptySession?.dispose();
    } catch (_) {
      // Avoid letting native disposal throw
    }
    _ptySession = null;
  }

  void _handleExecutionError(String message, Object? underlying) {
    if (!_isRunningProgrammatic) return;

    final command = _currentCommand ?? '';
    final workingDir = _workingDirectory;
    final startTime = _commandStartTime ?? DateTime.now();

    _cleanupSession();
    _isRunningProgrammatic = false;
    notifyListeners();

    final errorEvent = CmdRunErrorEvent(
      command: command,
      workingDirectory: workingDir,
      startTime: startTime,
      errorMessage: message,
      underlyingError: underlying,
      exitCode: -1,
      duration: DateTime.now().difference(startTime),
    );
    onCmdRunError?.call(errorEvent);

    // Auto-restart interactive shell if enabled
    if (_isInteractive) {
      _startBackgroundShell();
    }
  }

  Future<void> _handleExecutionDone() async {
    if (!_isRunningProgrammatic) return;

    final command = _currentCommand ?? '';
    final workingDir = _workingDirectory;
    final startTime = _commandStartTime ?? DateTime.now();
    int exitCode = 0;

    if (_ptySession != null) {
      try {
        exitCode = await _ptySession!.waitForExit();
      } catch (_) {
        exitCode = -1;
      }
    }

    _cleanupSession();
    _isRunningProgrammatic = false;
    notifyListeners();

    final completeEvent = CmdRunCompleteEvent(
      command: command,
      workingDirectory: workingDir,
      startTime: startTime,
      exitCode: exitCode,
      completionTime: DateTime.now(),
      duration: DateTime.now().difference(startTime),
    );
    onCmdRunComplete?.call(completeEvent);

    // Auto-restart interactive shell if enabled
    if (_isInteractive) {
      _startBackgroundShell();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cleanupSession();
    super.dispose();
  }
}
