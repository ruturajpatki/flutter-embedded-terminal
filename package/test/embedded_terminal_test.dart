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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embedded_terminal/embedded_terminal.dart';
import 'package:embedded_terminal/src/pty/pty_session.dart';
import 'package:embedded_terminal/src/pty/pty_factory.dart';

class FakePtySession implements PtySession {
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final Completer<int> _exitCompleter = Completer<int>();

  final List<String> writtenInputs = [];
  bool wasKilled = false;
  bool wasDisposed = false;
  int? resizedCols;
  int? resizedRows;

  @override
  Stream<List<int>> get output => _outputController.stream;

  @override
  void write(String data) {
    writtenInputs.add(data);
  }

  @override
  void writeBytes(List<int> data) {
    writtenInputs.add(String.fromCharCodes(data));
  }

  @override
  void resize(int columns, int rows) {
    resizedCols = columns;
    resizedRows = rows;
  }

  @override
  Future<int> waitForExit() => _exitCompleter.future;

  @override
  void kill() {
    wasKilled = true;
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(-1);
    }
  }

  @override
  void dispose() {
    wasDisposed = true;
    _outputController.close();
    kill();
  }

  void simulateOutput(String data) {
    _outputController.add(data.codeUnits);
  }

  void simulateExit(int exitCode) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(exitCode);
    }
    _outputController.close();
  }
}

void main() {
  late EmbeddedTerminalController controller;
  late List<FakePtySession> spawnedPtys;

  setUp(() {
    spawnedPtys = [];

    PtyFactory.mockFactory =
        ({
          String? command,
          String? workingDirectory,
          Map<String, String>? environment,
          int? columns,
          int? rows,
        }) {
          final pty = FakePtySession();
          spawnedPtys.add(pty);
          return pty;
        };

    controller = EmbeddedTerminalController();
    // Default tests to non-interactive mode so background shell doesn't auto-spawn when testing core functionality
    controller.isInteractive = false;
  });

  tearDown(() {
    PtyFactory.mockFactory = null;
    controller.dispose();
  });

  group('EmbeddedTerminalController Tests', () {
    test('Initial state is idle', () {
      expect(controller.isRunning, isFalse);
      expect(controller.currentCommand, isNull);
    });

    test(
      'runCommand sets isRunning, currentCommand and fires onCmdRunStart',
      () async {
        CmdRunStartEvent? startEvent;
        controller.onCmdRunStart = (event) {
          startEvent = event;
        };

        final runFuture = controller.runCommand(
          'npm run dev',
          workingDirectory: 'C:/project',
        );

        expect(controller.isRunning, isTrue);
        expect(controller.currentCommand, 'npm run dev');
        expect(startEvent, isNotNull);
        expect(startEvent!.command, 'npm run dev');
        expect(startEvent!.workingDirectory, 'C:/project');

        final activePty = spawnedPtys.last;
        activePty.simulateExit(0);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));
      },
    );

    test(
      'command completion triggers onCmdRunComplete with success exit code',
      () async {
        CmdRunCompleteEvent? completeEvent;
        controller.onCmdRunComplete = (event) {
          completeEvent = event;
        };

        final runFuture = controller.runCommand('git status');
        final activePty = spawnedPtys.last;
        activePty.simulateExit(0);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(controller.isRunning, isFalse);
        expect(completeEvent, isNotNull);
        expect(completeEvent!.exitCode, 0);
        expect(completeEvent!.isSuccess, isTrue);
      },
    );

    test(
      'command failure triggers onCmdRunComplete with failure exit code',
      () async {
        CmdRunCompleteEvent? completeEvent;
        controller.onCmdRunComplete = (event) {
          completeEvent = event;
        };

        final runFuture = controller.runCommand('invalid command');
        final activePty = spawnedPtys.last;
        activePty.simulateExit(127);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(controller.isRunning, isFalse);
        expect(completeEvent, isNotNull);
        expect(completeEvent!.exitCode, 127);
        expect(completeEvent!.isSuccess, isFalse);
      },
    );

    test('multiple concurrent commands throw StateError', () async {
      final runFuture = controller.runCommand('command 1');
      final activePty = spawnedPtys.last;

      expect(() => controller.runCommand('command 2'), throwsStateError);

      activePty.simulateExit(0);
      await runFuture;
      await Future.delayed(const Duration(milliseconds: 10));
    });

    test(
      'stopCommand terminates the process and triggers completion',
      () async {
        CmdRunCompleteEvent? completeEvent;
        controller.onCmdRunComplete = (event) {
          completeEvent = event;
        };

        final runFuture = controller.runCommand('npm install');
        final activePty = spawnedPtys.last;
        expect(controller.isRunning, isTrue);

        await controller.stopCommand();

        expect(controller.isRunning, isFalse);
        expect(activePty.wasKilled, isTrue);
        expect(completeEvent, isNotNull);
        expect(completeEvent!.exitCode, -1);

        activePty.simulateExit(-1);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));
      },
    );

    test('restartCommand stops existing command and starts a new one', () async {
      final runFuture = controller.runCommand('npm run dev');
      final firstPty = spawnedPtys.last;
      expect(controller.currentCommand, 'npm run dev');

      // Start restart
      final restartFuture = controller.restartCommand();
      expect(firstPty.wasKilled, isTrue);

      firstPty.simulateExit(-1);
      await runFuture;

      // Wait for restartCommand's 100ms delay to elapse and runCommand to spawn the second PTY.
      await Future.delayed(const Duration(milliseconds: 150));

      // Now the second PTY should have spawned
      expect(spawnedPtys.length, 2);
      final secondPty = spawnedPtys.last;

      secondPty.simulateExit(0);
      await restartFuture;
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.isRunning, isFalse);
    });

    test('write method forwards data to PTY session', () async {
      final runFuture = controller.runCommand('bash');
      final activePty = spawnedPtys.last;
      await controller.write('git status\n');

      expect(activePty.writtenInputs.contains('git status\n'), isTrue);

      activePty.simulateExit(0);
      await runFuture;
      await Future.delayed(const Duration(milliseconds: 10));
    });

    test('resize method propagates columns and rows to PTY', () async {
      final runFuture = controller.runCommand('bash');
      final activePty = spawnedPtys.last;
      await controller.resize(100, 30);

      expect(activePty.resizedCols, 100);
      expect(activePty.resizedRows, 30);

      activePty.simulateExit(0);
      await runFuture;
      await Future.delayed(const Duration(milliseconds: 10));
    });
  });

  group('Interactive Background Shell Tests', () {
    test('Enabling isInteractive spawns background shell PTY', () {
      expect(spawnedPtys.isEmpty, isTrue);

      controller.isInteractive = true;

      expect(spawnedPtys.length, 1);
      expect(
        controller.isRunning,
        isFalse,
      ); // background shell is not considered a programmatic run
    });

    test('Changing workingDirectory restarts background shell PTY', () {
      controller.isInteractive = true;
      expect(spawnedPtys.length, 1);
      final firstShell = spawnedPtys.last;

      controller.workingDirectory = 'D:/other-path';

      expect(spawnedPtys.length, 2);
      expect(firstShell.wasDisposed, isTrue);
    });

    test(
      'runCommand stops background shell and starts programmatic command PTY',
      () async {
        controller.isInteractive = true;
        expect(spawnedPtys.length, 1);
        final shellPty = spawnedPtys.last;

        final runFuture = controller.runCommand('node --version');

        expect(shellPty.wasDisposed, isTrue);
        expect(
          spawnedPtys.length,
          2,
        ); // 1 background shell + 1 programmatic command
        expect(controller.isRunning, isTrue);

        final cmdPty = spawnedPtys.last;
        cmdPty.simulateExit(0);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));

        // After exit, interactive mode spawns another background shell
        expect(spawnedPtys.length, 3);
        expect(controller.isRunning, isFalse);
      },
    );

    test('Disabling isInteractive stops background shell PTY', () {
      controller.isInteractive = true;
      expect(spawnedPtys.length, 1);
      final shellPty = spawnedPtys.last;

      controller.isInteractive = false;

      expect(shellPty.wasDisposed, isTrue);
    });
  });

  group('Conditional Ctrl+C Selection Handling Tests', () {
    test('hasSelection returns false when selection is null or empty', () {
      expect(controller.hasSelection, isFalse);
    });

    test('Ctrl+C without selection forwards 0x03 to PTY session', () async {
      controller.isInteractive = true;
      final runFuture = controller.runCommand('npm run dev');
      final activePty = spawnedPtys.last;

      // Simulate Ctrl+C input via terminal onOutput
      controller.terminal.onOutput?.call('\x03');

      expect(activePty.writtenInputs.contains('\x03'), isTrue);

      activePty.simulateExit(0);
      await runFuture;
      await Future.delayed(const Duration(milliseconds: 10));
    });

    test(
      'Ctrl+C with selection does NOT forward 0x03 to PTY session',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        controller.isInteractive = true;
        final runFuture = controller.runCommand('npm run dev');
        final activePty = spawnedPtys.last;

        // Write some text into terminal buffer
        controller.terminal.write('Hello World\n');

        // Set a selection on terminalController
        controller.terminalController.setSelection(
          controller.terminal.buffer.createAnchor(0, 0),
          controller.terminal.buffer.createAnchor(5, 0),
        );

        expect(controller.hasSelection, isTrue);

        // Simulate Ctrl+C input via terminal onOutput
        controller.terminal.onOutput?.call('\x03');

        // Verify \x03 was NOT sent to PTY session
        expect(activePty.writtenInputs.contains('\x03'), isFalse);

        activePty.simulateExit(0);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));
      },
    );

    test(
      'In non-interactive mode onOutput copies selection when Ctrl+C is pressed',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        controller.isInteractive = false;
        final runFuture = controller.runCommand('npm run dev');
        final activePty = spawnedPtys.last;

        controller.terminal.write('Sample Output Text\n');
        controller.terminalController.setSelection(
          controller.terminal.buffer.createAnchor(0, 0),
          controller.terminal.buffer.createAnchor(6, 0),
        );

        expect(controller.hasSelection, isTrue);

        // Simulate Ctrl+C input via terminal onOutput when non-interactive
        controller.terminal.onOutput?.call('\x03');

        // Verify \x03 was NOT sent to PTY session
        expect(activePty.writtenInputs.contains('\x03'), isFalse);

        activePty.simulateExit(0);
        await runFuture;
        await Future.delayed(const Duration(milliseconds: 10));
      },
    );

    testWidgets(
      'Ctrl+C on EmbeddedTerminal widget copies selection when isInteractive is false',
      (tester) async {
        controller.isInteractive = false;
        controller.terminal.write('Sample Terminal Text\n');
        controller.terminalController.setSelection(
          controller.terminal.buffer.createAnchor(0, 0),
          controller.terminal.buffer.createAnchor(6, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: EmbeddedTerminal(
                  controller: controller,
                  isInteractive: false,
                ),
              ),
            ),
          ),
        );

        expect(controller.hasSelection, isTrue);

        // Simulate Ctrl+C key press
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        await tester.pumpAndSettle();
      },
    );
  });
}
