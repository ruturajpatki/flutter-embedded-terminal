import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:embedded_terminal/embedded_terminal.dart';

void main() {
  runApp(const EmbeddedTerminalDemoApp());
}

class EmbeddedTerminalDemoApp extends StatelessWidget {
  const EmbeddedTerminalDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embedded Terminal Proof of Concept',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF56B6C2), // Cyan accent
        scaffoldBackgroundColor: const Color(0xFF1E222B), // Very dark gray-blue
        cardColor: const Color(0xFF282C34), // Dark gray
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF56B6C2),
          secondary: Color(0xFF98C379), // Green accent
          surface: Color(0xFF282C34),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const TerminalDemoScreen(),
    );
  }
}

class TerminalDemoScreen extends StatefulWidget {
  const TerminalDemoScreen({super.key});

  @override
  State<TerminalDemoScreen> createState() => _TerminalDemoScreenState();
}

class _TerminalDemoScreenState extends State<TerminalDemoScreen> {
  final EmbeddedTerminalController _controller = EmbeddedTerminalController();
  final TextEditingController _commandInputController = TextEditingController(
    text: 'npm run dev -- --host=127.0.0.1 --port=8050',
  );

  String? _workingDirectory;
  bool _isInteractive = true;
  bool _enableCopy = true;
  bool _enableExport = true;
  String _currentStatus = 'Idle'; // Idle, Running, Completed, Failed, Stopped
  final List<String> _eventLogs = [];
  final ScrollController _logScrollController = ScrollController();

  final List<String> _sampleCommands = [
    'npm run dev -- --host=127.0.0.1 --port=8050',
    'node --version',
    'npm --version',
    'npm install',
    'git status',
    'php artisan serve',
    'composer install',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    _commandInputController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _onControllerStateChanged() {
    // Sync running status from controller
    if (!_controller.isRunning && _currentStatus == 'Running') {
      setState(() {
        _currentStatus = _isInteractive ? 'Ready' : 'Completed';
      });
    }
  }

  void _logEvent(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 8);
    setState(() {
      _eventLogs.add('[$timestamp] $message');
    });
    // Auto scroll logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _browseDirectory() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) {
      setState(() {
        _workingDirectory = result;
        _controller.workingDirectory = result;
        if (!_controller.isRunning) {
          _currentStatus = _isInteractive ? 'Ready' : 'Idle';
        }
      });
      _logEvent('Changed working directory to: $result');
    }
  }

  void _runCommand() async {
    final command = _commandInputController.text.trim();

    if (_workingDirectory == null || _workingDirectory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a base folder working directory first.'),
          backgroundColor: Color(0xFFE06C75),
        ),
      );
      return;
    }

    if (command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a command to run.'),
          backgroundColor: Color(0xFFE06C75),
        ),
      );
      return;
    }

    try {
      setState(() {
        _currentStatus = 'Running';
      });
      await _controller.runCommand(
        command,
        workingDirectory: _workingDirectory,
      );
    } catch (e) {
      _logEvent('Execution trigger failed: $e');
    }
  }

  void _stopCommand() async {
    _logEvent('Stopping process...');
    await _controller.stopCommand();
    setState(() {
      _currentStatus = 'Stopped';
    });
  }

  void _restartCommand() async {
    _logEvent('Restarting process...');
    setState(() {
      _currentStatus = 'Running';
    });
    try {
      await _controller.restartCommand();
    } catch (e) {
      _logEvent('Restart trigger failed: $e');
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'Running':
        return const Color(0xFF98C379); // Green
      case 'Ready':
        return const Color(0xFF56B6C2); // Cyan
      case 'Completed':
        return const Color(0xFF61AFEF); // Blue
      case 'Failed':
        return const Color(0xFFE06C75); // Red
      case 'Stopped':
        return const Color(0xFFD19A66); // Orange
      case 'Idle':
      default:
        return const Color(0xFFABB2BF); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal, color: Color(0xFF56B6C2)),
            const SizedBox(width: 10),
            const Text(
              'EmbeddedTerminal POC',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withAlpha(38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentStatus.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF21252B),
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left configuration panel
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF21252B),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONFIGURATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C6370),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Base Folder selection
                    const Text(
                      'Base Folder (Working Directory)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFABB2BF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF282C34),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF3E4451),
                              ),
                            ),
                            child: Text(
                              _workingDirectory ?? 'No folder selected...',
                              style: TextStyle(
                                color: _workingDirectory != null
                                    ? const Color(0xFFABB2BF)
                                    : const Color(0xFF5C6370),
                                fontSize: 13,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _controller.isRunning
                              ? null
                              : _browseDirectory,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Browse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3E4451),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Command to Run selection
                    const Text(
                      'Command to Run',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFABB2BF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commandInputController,
                            enabled: !_controller.isRunning,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Color(0xFF282C34),
                              border: OutlineInputBorder(),
                              hintText: 'Enter shell command...',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.arrow_drop_down_circle_outlined,
                            color: Color(0xFF56B6C2),
                          ),
                          tooltip: 'Select sample command',
                          enabled: !_controller.isRunning,
                          onSelected: (command) {
                            _commandInputController.text = command;
                            _logEvent('Selected sample: $command');
                          },
                          itemBuilder: (context) {
                            return _sampleCommands.map((cmd) {
                              return PopupMenuItem<String>(
                                value: cmd,
                                child: Text(
                                  cmd,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Interactivity switch
                    Row(
                      children: [
                        const Text(
                          'Interactive Input',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFABB2BF),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _isInteractive,
                          activeThumbColor: const Color(0xFF56B6C2),
                          onChanged: (val) {
                            setState(() {
                              _isInteractive = val;
                            });
                            _logEvent(
                              'Interactivity switched to: ${val ? "ENABLED" : "DISABLED"}',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Enable Copy switch
                    Row(
                      children: [
                        const Text(
                          'Enable Copy Button',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFABB2BF),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _enableCopy,
                          activeThumbColor: const Color(0xFF56B6C2),
                          onChanged: (val) {
                            setState(() {
                              _enableCopy = val;
                            });
                            _logEvent(
                              'Copy button switched to: ${val ? "ENABLED" : "DISABLED"}',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Enable Export switch
                    Row(
                      children: [
                        const Text(
                          'Enable Export Button',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFABB2BF),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _enableExport,
                          activeThumbColor: const Color(0xFF56B6C2),
                          onChanged: (val) {
                            setState(() {
                              _enableExport = val;
                            });
                            _logEvent(
                              'Export button switched to: ${val ? "ENABLED" : "DISABLED"}',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Controls Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _controller.isRunning
                                ? null
                                : _runCommand,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Run Command'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF98C379),
                              foregroundColor: const Color(0xFF21252B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _controller.isRunning
                                ? _stopCommand
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE06C75),
                              side: BorderSide(
                                color: _controller.isRunning
                                    ? const Color(0xFFE06C75)
                                    : const Color(0xFF3E4451),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _controller.isRunning
                                ? _restartCommand
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Restart'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD19A66),
                              side: BorderSide(
                                color: _controller.isRunning
                                    ? const Color(0xFFD19A66)
                                    : const Color(0xFF3E4451),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _controller.copyToClipboard();
                              _logEvent('Triggered copy to clipboard programmatically');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied terminal output to clipboard (Controller API)'),
                                    backgroundColor: Color(0xFF98C379),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.content_copy),
                            label: const Text('Copy (API)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFABB2BF),
                              side: const BorderSide(color: Color(0xFF3E4451)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final saved = await _controller.exportTerminalText();
                              if (saved) {
                                _logEvent('Exported terminal output programmatically');
                              } else {
                                _logEvent('Export terminal output cancelled or failed');
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Export (API)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFABB2BF),
                              side: const BorderSide(color: Color(0xFF3E4451)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Package Event Logs Display
                    const Text(
                      'PACKAGE LIFECYCLE LOGS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C6370),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF3E4451)),
                      ),
                      child: _eventLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No events registered yet.',
                                style: TextStyle(
                                  color: Color(0xFF5C6370),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _logScrollController,
                              itemCount: _eventLogs.length,
                              itemBuilder: (context, idx) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    _eventLogs[idx],
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Color(0xFFABB2BF),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right terminal view
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF1E222B),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.output, size: 16, color: Color(0xFF5C6370)),
                      SizedBox(width: 8),
                      Text(
                        'TERMINAL OUTPUT RESULT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5C6370),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF282C34),
                          width: 2,
                        ),
                      ),
                      child: EmbeddedTerminal(
                        controller: _controller,
                        isInteractive: _isInteractive,
                        workingDirectory: _workingDirectory,
                        enableCopy: _enableCopy,
                        enableExport: _enableExport,
                        onCmdRunStart: (event) {
                          _logEvent(
                            'Start callback: "${event.command}" in "${event.workingDirectory}"',
                          );
                        },
                        onCmdRunComplete: (event) {
                          _logEvent(
                            'Complete callback: Exit ${event.exitCode} (${event.duration.inMilliseconds}ms)',
                          );
                          setState(() {
                            if (_isInteractive) {
                              _currentStatus = 'Ready';
                            } else {
                              if (event.exitCode == 0) {
                                _currentStatus = 'Completed';
                              } else if (event.exitCode == -1) {
                                _currentStatus = 'Stopped';
                              } else {
                                _currentStatus = 'Failed';
                              }
                            }
                          });
                        },
                        onCmdRunError: (event) {
                          _logEvent('Error callback: ${event.errorMessage}');
                          setState(() {
                            _currentStatus = _isInteractive
                                ? 'Ready'
                                : 'Failed';
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
