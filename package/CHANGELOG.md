# Changelog

All notable changes to the `embedded_terminal` package will be documented in this file.

---

## [1.2.0] - 2026-08-31

### Added
- **Conditional `Ctrl+C` / `Cmd+C` Selection Copying**:
  - Automatically copies highlighted text to the system clipboard when text selection is active instead of forwarding `\x03` (SIGINT) to the terminal process. Prevents accidental termination of running services (e.g. `npm run dev`) during copy operations.
  - Forwards `Ctrl+C` (`\x03`) to the terminal process to interrupt/terminate running commands only when no text selection is active.
- **Read-Only / Non-Interactive Selection Support**:
  - Enables `Ctrl+C` text copying when `isInteractive` is set to `false`, provided text is selected.
  - Completely blocks/swallows `Ctrl+C` and keyboard input when `isInteractive` is `false` and no text is selected, ensuring zero bytes reach the PTY process.
- **Pointer Down Focus Acquisition**:
  - Wrapped terminal layout hierarchy in a `Listener` listening to `onPointerDown` to request keyboard focus immediately upon mouse down or drag start, preventing focus loss when interacting with external sidebar controls.
- **Controller Properties & API**:
  - Added `bool get hasSelection` getter to `EmbeddedTerminalController` for querying active text selection state.
- **Unit & Widget Testing**:
  - Comprehensive test suite in `embedded_terminal_test.dart` validating conditional `Ctrl+C` forwarding, selection detection, and non-interactive mode input suppression (18/18 tests passing).

---

## [1.1.0] - 2026-08-27

### Added
- Copy to clipboard & export to `.txt` file functionality via floating toolbar and controller methods.
- Context-aware selection copy & export.

---

## [1.0.0] - 2026-08-20

### Added
- Initial release of `embedded_terminal` package with real ConPTY / POSIX PTY integration, interactive background shell, and programmatic command execution.
