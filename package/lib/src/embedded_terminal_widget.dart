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
import 'package:xterm/xterm.dart';
import 'embedded_terminal_controller.dart';
import 'terminal_events.dart';

/// The EmbeddedTerminal widget rendering the terminal interface.
///
/// It wraps xterm's [TerminalView], listens to dimension changes to resize the PTY,
/// and manages input interactivity.
class EmbeddedTerminal extends StatefulWidget {
  /// The controller that owns the running process and terminal state.
  final EmbeddedTerminalController controller;

  /// Optional initial working directory for command execution.
  final String? workingDirectory;

  /// Optional initial command to run automatically on widget initialization.
  final String? initialCommand;

  /// Whether the user can directly type into the terminal UI.
  ///
  /// Defaults to `true`.
  final bool isInteractive;

  /// Optional custom theme to style terminal background, foreground, and ANSI colors.
  final TerminalTheme? theme;

  /// Optional custom style for terminal fonts and sizes.
  final TerminalStyle? textStyle;

  /// Lifecycle callback triggered when a command starts executing.
  final void Function(CmdRunStartEvent)? onCmdRunStart;

  /// Lifecycle callback triggered when a command completes execution.
  final void Function(CmdRunCompleteEvent)? onCmdRunComplete;

  /// Lifecycle callback triggered when a command fails to start or run.
  final void Function(CmdRunErrorEvent)? onCmdRunError;

  /// Whether to show a copy icon button in the top-right corner.
  final bool enableCopy;

  /// Whether to show an export icon button in the top-right corner.
  final bool enableExport;

  const EmbeddedTerminal({
    super.key,
    required this.controller,
    this.workingDirectory,
    this.initialCommand,
    this.isInteractive = true,
    this.theme,
    this.textStyle,
    this.onCmdRunStart,
    this.onCmdRunComplete,
    this.onCmdRunError,
    this.enableCopy = false,
    this.enableExport = false,
  });

  @override
  State<EmbeddedTerminal> createState() => _EmbeddedTerminalState();
}

class _EmbeddedTerminalState extends State<EmbeddedTerminal> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _syncCallbacks();
    _syncControllerProperties();

    // Trigger initial command execution if provided
    if (widget.initialCommand != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.controller.isRunning) {
          widget.controller
              .runCommand(
                widget.initialCommand!,
                workingDirectory: widget.workingDirectory,
              )
              .catchError((_) {
                // Error is handled through onCmdRunError callback
              });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCallbacks();
    _syncControllerProperties();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _syncCallbacks() {
    widget.controller.onCmdRunStart = widget.onCmdRunStart;
    widget.controller.onCmdRunComplete = widget.onCmdRunComplete;
    widget.controller.onCmdRunError = widget.onCmdRunError;
  }

  void _syncControllerProperties() {
    widget.controller.isInteractive = widget.isInteractive;
    if (widget.workingDirectory != null) {
      widget.controller.workingDirectory = widget.workingDirectory;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provide a polished dark theme matching professional developer tools by default.
    final effectiveTheme =
        widget.theme ??
        const TerminalTheme(
          cursor: Color(0xFF56B6C2), // cyan
          selection: Color(0x40FFFFFF), // translucent white
          foreground: Color(0xFFABB2BF), // light gray
          background: Color(0xFF21252B), // dark background
          black: Color(0xFF1E2127),
          red: Color(0xFFE06C75),
          green: Color(0xFF98C379),
          yellow: Color(0xFFD19A66),
          blue: Color(0xFF61AFEF),
          magenta: Color(0xFFC678DD),
          cyan: Color(0xFF56B6C2),
          white: Color(0xFFABB2BF),
          brightBlack: Color(0xFF5C6370),
          brightRed: Color(0xFFE06C75),
          brightGreen: Color(0xFF98C379),
          brightYellow: Color(0xFFD19A66),
          brightBlue: Color(0xFF61AFEF),
          brightMagenta: Color(0xFFC678DD),
          brightCyan: Color(0xFF56B6C2),
          brightWhite: Color(0xFFFFFFFF),
          searchHitBackground: Color(0xFFE2B007),
          searchHitBackgroundCurrent: Color(0xFFFFC600),
          searchHitForeground: Color(0xFF000000),
        );

    final effectiveTextStyle =
        widget.textStyle ??
        const TerminalStyle(fontFamily: 'monospace', fontSize: 13.0);

    final showToolbar = widget.enableCopy || widget.enableExport;

    return Stack(
      children: [
        Positioned.fill(
          child: TerminalView(
            widget.controller.terminal,
            controller: widget.controller.terminalController,
            theme: effectiveTheme,
            textStyle: effectiveTextStyle,
            readOnly: !widget.isInteractive,
            autofocus: true,
            hardwareKeyboardOnly: true,
          ),
        ),
        if (showToolbar)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: effectiveTheme.background.withAlpha(179),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: effectiveTheme.foreground.withAlpha(38),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.enableCopy)
                    Tooltip(
                      message: 'Copy all text',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () async {
                          await widget.controller.copyToClipboard();
                          if (mounted) {
                            setState(() {
                              _copied = true;
                            });
                            _copyTimer?.cancel();
                            _copyTimer = Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() {
                                  _copied = false;
                                });
                              }
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(
                            _copied ? Icons.check : Icons.copy_outlined,
                            size: 16,
                            color: _copied
                                ? const Color(0xFF98C379) // Green matching green theme color
                                : effectiveTheme.foreground,
                          ),
                        ),
                      ),
                    ),
                  if (widget.enableCopy && widget.enableExport)
                    const SizedBox(width: 4),
                  if (widget.enableExport)
                    Tooltip(
                      message: 'Export text to file',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () async {
                          final saved = await widget.controller.exportTerminalText();
                          if (!context.mounted) return;
                          if (saved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Terminal output exported successfully.'),
                                backgroundColor: Color(0xFF98C379),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.save_outlined,
                            size: 16,
                            color: effectiveTheme.foreground,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
