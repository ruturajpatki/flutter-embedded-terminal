# EmbeddedTerminal Integration Guide

This guide describes how to integrate and use the `embedded_terminal` package in your Flutter Desktop applications (Windows, macOS, Linux).

---

## 1. Overview & Features

`EmbeddedTerminal` is a reusable Flutter package that renders an integrated, interactive command-line terminal emulator entirely inside your Flutter widget tree, similar in concept to the terminal panel in VS Code.

### Key Features
*   **Genuine PTY (Pseudo-Terminal) Architecture**: Uses a real PTY layer (`Windows ConPTY` on Windows, native `POSIX PTY` on macOS and Linux) instead of simple redirected processes.
*   **Interactive Background Shell**: Spawns an interactive shell (e.g. PowerShell, Bash, or Zsh) automatically when idle so users see standard folder prompt lines (e.g., `PS C:\Project> `) and can type commands directly.
*   **Programmatic Command Execution**: Triggers single commands programmatically (e.g., `npm run dev`) while tracking precise start, complete, and error lifecycle phases.
*   **Clean Isolation**: Encapsulates all PTY management, platform-specific process control, stdin/stdout mapping, and terminal emulator configuration behind a simple, type-safe API.
*   **Responsive Resizing**: Automatically propagates layout dimension changes down to the PTY process.
*   **Monospace Styling**: Includes built-in dark developer themes with complete contrast preservation and ANSI color mapping.

---

## 2. Setup and Dependencies

Add `embedded_terminal` as a local path dependency in your Flutter application's `pubspec.yaml` (or reference it if published):

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Reusable embedded terminal package
  embedded_terminal:
    path: ../package
```

### Platform Requirements
*   **Windows**: Windows 10+ (ConPTY support).
*   **macOS**: macOS Desktop support (requires the User Selected File Read/Write entitlements if sandboxed).
*   **Linux**: Linux Desktop support.

---

## 3. Public API Specification

The public API is exposed entirely through `package:embedded_terminal/embedded_terminal.dart`.

### 3.1 `EmbeddedTerminal` Widget
A `StatefulWidget` wrapping the terminal emulator renderer.

| Property | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `controller` | `EmbeddedTerminalController` | **Required.** The controller coordinating PTY states and inputs. | N/A |
| `workingDirectory` | `String?` | The directory path where shell commands or programmatic processes start. | `null` |
| `initialCommand` | `String?` | Optional programmatic command to run immediately when the widget mounts. | `null` |
| `isInteractive` | `bool` | Enables keyboard input capture. If `false`, input is blocked (read-only mode). | `true` |
| `theme` | `TerminalTheme?` | Custom terminal styling colors (ANSI colors, cursor, backgrounds). | Monospace dark theme |
| `textStyle` | `TerminalStyle?` | Custom text style configurations (font family, font size). | `monospace` (size 13.0) |
| `onCmdRunStart` | `void Function(CmdRunStartEvent)?` | Callback triggered when a programmatic command starts running. | `null` |
| `onCmdRunComplete` | `void Function(CmdRunCompleteEvent)?` | Callback triggered when a programmatic command completes. | `null` |
| `onCmdRunError` | `void Function(CmdRunErrorEvent)?` | Callback triggered when a programmatic command execution fails. | `null` |
| `enableCopy` | `bool` | Renders a minimalist floating copy button in the top-right corner. Automatically copies only the selected text if a selection is active. | `false` |
| `enableExport` | `bool` | Renders a minimalist floating save icon button in the top-right corner to save text to a file. Automatically exports only the selected text if a selection is active. | `false` |

---

### 3.2 `EmbeddedTerminalController`
The controller managing the active processes and xterm terminal states.

#### Properties
*   `bool get isRunning`: Returns `true` if a programmatic command is currently active.
*   `String? get currentCommand`: Returns the currently running programmatic command, or `null` if idle.
*   `String? get workingDirectory` / `set workingDirectory(String?)`: Gets or sets the active directory. Changing this resets the interactive shell prompt location.
*   `bool get isInteractive` / `set isInteractive(bool)`: Gets or sets the interactive state. Turning this off cleans up the interactive background shell.
*   `bool get hasSelection`: Returns `true` if an active, non-empty text selection is present in the terminal view.
*   `TerminalController terminalController`: The controller managing terminal view interactions (such as text selection ranges and cursor state).

#### Methods
*   `Future<void> runCommand(String command, {String? workingDirectory, Map<String, String>? environment})`: Runs a specific shell command programmatically. Stops the background shell if active.
*   `Future<void> stopCommand()`: Stops the active programmatic command process.
*   `Future<void> restartCommand()`: Stops and restarts the last executed programmatic command.
*   `Future<void> clear()`: Clears the terminal screen.
*   `Future<void> write(String input)`: Writes raw input data directly to the PTY process (independent of widget interactivity).
*   `Future<void> resize(int columns, int rows)`: Manually triggers a resize of the underlying PTY.
*   `String getTerminalText()`: Extracts the current plain text buffer. If a text selection is active, returns only the selected text.
*   `Future<void> copyToClipboard()`: Copies the terminal text (or selection) to the system clipboard.
*   `Future<bool> exportTerminalText()`: Opens a native save file dialog to export the terminal text (or selection) to a `.txt` file. Returns `true` if successful.

---

### 3.3 Lifecycle Events

#### `CmdRunStartEvent`
*   `String command`: The command that was executed.
*   `String? workingDirectory`: The working directory path.
*   `DateTime startTime`: The timestamp when the process started.

#### `CmdRunCompleteEvent`
*   `String command`: The command that was executed.
*   `String? workingDirectory`: The working directory path.
*   `DateTime startTime`: The timestamp when the process started.
*   `DateTime completionTime`: The timestamp when the process ended.
*   `Duration duration`: The duration of execution.
*   `int exitCode`: The exit code returned by the process (e.g. `0` for success, `-1` if stopped).
*   `bool get isSuccess`: Returns `true` if the exit code was `0`.

#### `CmdRunErrorEvent`
*   `String command`: The command.
*   `String? workingDirectory`: The working directory path.
*   `DateTime startTime`: The start timestamp.
*   `String errorMessage`: Descriptive message of the execution failure.
*   `Object? underlyingError`: The underlying exception.
*   `int? exitCode`: The exit code (if available).
*   `Duration? duration`: Duration of run before failure (if available).

---

## 4. Code Examples

### 4.1 Minimal Example
Embeds a basic interactive terminal starting in a chosen directory.

```dart
import 'package:flutter/material.dart';
import 'package:embedded_terminal/embedded_terminal.dart';

class SimpleTerminalWidget extends StatefulWidget {
  const SimpleTerminalWidget({super.key});

  @override
  State<SimpleTerminalWidget> createState() => _SimpleTerminalWidgetState();
}

class _SimpleTerminalWidgetState extends State<SimpleTerminalWidget> {
  final EmbeddedTerminalController _controller = EmbeddedTerminalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 800,
          height: 400,
          child: EmbeddedTerminal(
            controller: _controller,
            workingDirectory: 'C:\\Projects\\my-project',
            isInteractive: true,
          ),
        ),
      ),
    );
  }
}
```

---

### 4.2 Comprehensive Example
Displays a detailed widget implementing all properties, dynamic configuration updates, programmatic controls, and lifecycle events tracking:

```dart
import 'package:flutter/material.dart';
import 'package:embedded_terminal/embedded_terminal.dart';

class AdvancedTerminalDashboard extends StatefulWidget {
  const AdvancedTerminalDashboard({super.key});

  @override
  State<AdvancedTerminalDashboard> createState() => _AdvancedTerminalDashboardState();
}

class _AdvancedTerminalDashboardState extends State<AdvancedTerminalDashboard> {
  final EmbeddedTerminalController _controller = EmbeddedTerminalController();
  
  String _workingDir = 'C:\\Projects\\app';
  bool _isInteractive = true;
  String _status = 'Ready';
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerBuild() async {
    try {
      // Start programmatic execution
      await _controller.runCommand(
        'npm run build',
        workingDirectory: _workingDir,
        environment: {'NODE_ENV': 'production'},
      );
    } catch (e) {
      print('Failed to start command: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terminal Status: $_status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _controller.isRunning ? null : _triggerBuild,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _controller.isRunning ? _controller.stopCommand : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.isRunning ? _controller.restartCommand : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Configuration Panel
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('Directory: $_workingDir'),
                const Spacer(),
                const Text('Interactive:'),
                Switch(
                  value: _isInteractive,
                  onChanged: (val) {
                    setState(() {
                      _isInteractive = val;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Embedded Terminal View
          Expanded(
            child: EmbeddedTerminal(
              controller: _controller,
              workingDirectory: _workingDir,
              isInteractive: _isInteractive,
              
              // Custom Styling
              theme: const TerminalTheme(
                cursor: Color(0xFF56B6C2),
                selection: Color(0x40FFFFFF),
                foreground: Color(0xFFABB2BF),
                background: Color(0xFF1E222B),
                black: Color(0xFF1E2127),
                white: Color(0xFFABB2BF),
                red: Color(0xFFE06C75),
                green: Color(0xFF98C379),
                yellow: Color(0xFFD19A66),
                blue: Color(0xFF61AFEF),
                magenta: Color(0xFFC678DD),
                cyan: Color(0xFF56B6C2),
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
              ),
              textStyle: const TerminalStyle(
                fontFamily: 'monospace',
                fontSize: 14.0,
              ),
              
              // Lifecycle Event Handlers
              onCmdRunStart: (event) {
                setState(() {
                  _status = 'Running';
                });
                print('Started programmatic command: ${event.command}');
              },
              onCmdRunComplete: (event) {
                setState(() {
                  _status = _isInteractive ? 'Ready' : (event.isSuccess ? 'Success' : 'Failed');
                });
                print('Finished: Exit Code ${event.exitCode} in ${event.duration.inMilliseconds}ms');
              },
              onCmdRunError: (event) {
                setState(() {
                  _status = _isInteractive ? 'Ready' : 'Error';
                });
                print('Infrastructure error occurred: ${event.errorMessage}');
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Direct Code Integration (Alternative)

If you prefer to copy the terminal source code directly into your main application instead of consuming it as an external package package dependency, follow these steps:

### 5.1 Add Core Dependencies
First, add the required package dependencies directly to your main application's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  xterm: ^4.0.0
  flutter_pty: ^0.4.2
```
Run `flutter pub get` to download the packages.

### 5.2 Copy Source Directory Structure
Copy the contents of `package/lib/` to a subfolder inside your main application's `lib/` directory. We recommend placing them under `lib/embedded_terminal/` matching this exact layout:

```text
lib/
└── embedded_terminal/
    ├── embedded_terminal.dart              # Main entry point (exports src/)
    └── src/
        ├── embedded_terminal_widget.dart
        ├── embedded_terminal_controller.dart
        ├── terminal_events.dart
        └── pty/
            ├── pty_session.dart
            └── pty_factory.dart
```

### 5.3 Update Import Paths
In the copied files, change any absolute package imports pointing to the old package:

*   **Change**: `import 'package:embedded_terminal/...'`
*   **To**: `import 'package:your_app_name/embedded_terminal/...'` (using your app's actual package namespace) or rewrite them as relative imports (e.g. `import 'src/terminal_events.dart';`).

