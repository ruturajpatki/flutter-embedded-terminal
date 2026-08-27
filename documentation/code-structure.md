# EmbeddedTerminal Code Structure Guide

This document outlines the file layout, organization, and components of the `embedded_terminal` package to help developers understand its architecture.

---

## 1. Directory Layout

The core package code is isolated under `package/lib/`:

```text
package/
├── lib/
│   ├── embedded_terminal.dart             # Public API entry point
│   └── src/
│       ├── embedded_terminal_widget.dart      # Flutter terminal view widget
│       ├── embedded_terminal_controller.dart  # Session & execution controller
│       ├── terminal_events.dart               # Typed lifecycle events
│       └── pty/
│           ├── pty_session.dart               # Abstract PTY interface
│           └── pty_factory.dart               # Native PTY constructor & wrapper
└── test/
    └── embedded_terminal_test.dart            # Unit & integration mock tests
```

---

## 2. File Directory & Purpose

### 2.1 Public API Entry Point

#### `embedded_terminal.dart`
The root export file. It exposes the widget, controller, event classes, and selected classes from the dependency `xterm` (e.g. `TerminalTheme`, `TerminalStyle`) to callers. This allows host applications to interact with and style the terminal without directly referencing internal directories.

---

### 2.2 Source Files (`src/`)

#### `embedded_terminal_widget.dart`
*   **Role**: Handles the Flutter UI presentation.
*   **Purpose**: Wraps xterm's `TerminalView` widget. It maps configurations (`isInteractive`, `workingDirectory`, `theme`, `textStyle`, `enableCopy`, `enableExport`) and hooks lifecycle callback events (`onCmdRunStart`, `onCmdRunComplete`, `onCmdRunError`) onto the controller.
*   **Floating Toolbar**: Wraps the view in a `Stack` and overlays a minimalist floating toolbar in the top-right corner to allow copying text (with temporary checkmark feedback) or exporting text to a file.
*   **Focus & Hardware Keys**: Sets `autofocus: true` and `hardwareKeyboardOnly: true` on desktop targets to avoid mobile virtual keyboard crashes and ensure stable input streams.

#### `embedded_terminal_controller.dart`
*   **Role**: Manages active sessions, state machine transitions, and utility commands.
*   **Purpose**: Extends `ChangeNotifier` to coordinate starting, stopping, restarting, and resizing processes. When `isInteractive` is true and no programmatic task is running, it spawns a background interactive shell session. When a command is triggered via `runCommand`, it stops the background shell, executes the programmatic command, fires lifecycle events, and resumes the background shell prompt once complete.
*   **Copy/Export Logic**: Integrates a `TerminalController` to monitor UI highlights and active text selections. Exposes `getTerminalText()`, `copyToClipboard()` (system clipboard integrations), and `exportTerminalText()` (spawns native file saving dialogs via `file_picker` to write `.txt` files) which automatically operate only on the selected text range if one is active.

#### `terminal_events.dart`
*   **Role**: Strong typing models.
*   **Purpose**: Declares structured event classes (`CmdRunStartEvent`, `CmdRunCompleteEvent`, `CmdRunErrorEvent`) containing timing stats, directory paths, and exit codes.

---

### 2.3 Pseudo-Terminal Layer (`src/pty/`)

#### `pty_session.dart`
*   **Role**: Platform abstraction interface.
*   **Purpose**: Outlines a generic interface (`PtySession`) with abstract methods for `write`, `resize`, `output` stream access, and `waitForExit` promises. This isolates the flutter code from platform-specific binding libraries.

#### `pty_factory.dart`
*   **Role**: Factory instantiator & native wrapper.
*   **Purpose**: 
    1. Wraps `flutter_pty`'s concrete `Pty` process class under the `PtySession` interface (`FlutterPtySession`).
    2. Determines which shell interpreter to spawn based on the target OS: `powershell.exe` (with fallback to `cmd.exe`) on Windows, or the default user shell (`$SHELL`), `/bin/zsh`, or `/bin/bash` on macOS and Linux.
    3. Handles running single commands through shell command arguments (`-Command` or `-c`) and propagating their exit codes.
