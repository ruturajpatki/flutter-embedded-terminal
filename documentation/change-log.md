# Changelog

All notable changes to the `embedded_terminal` package are documented in this file.

---

## [1.1.0] - 2026-08-27

### Added
- **Copy to Clipboard Functionality**:
  - Exposes `copyToClipboard()` in `EmbeddedTerminalController` to copy the terminal text buffer to the system clipboard.
  - Adds `enableCopy` parameter to the `EmbeddedTerminal` widget, placing a minimalist copy button in the top-right corner of the terminal widget.
  - Added temporary visual feedback (checkmark icon turns green for 2 seconds) when copying text successfully.
- **Export to File Functionality**:
  - Exposes `exportTerminalText()` in `EmbeddedTerminalController` to show a native save file dialog and save the terminal buffer to a `.txt` file.
  - Adds `enableExport` parameter to the `EmbeddedTerminal` widget, placing a minimalist save icon button in the top-right corner.
- **Context-Aware Selection Copy/Export**:
  - Integrated `TerminalController` into `EmbeddedTerminalController` to track active terminal selections.
  - The copy and export features automatically detect if there is any active text selection, and if so, copy or export **only the selected text** instead of the entire buffer.
- **Demo Application Integration**:
  - Added configuration switches for "Enable Copy Button" and "Enable Export Button" to the Configuration Panel.
  - Added "Copy (API)" and "Export (API)" controls to test controller actions programmatically.

### Changed
- Refactored `EmbeddedTerminal` build method to use a `Stack` and absolute positioning for floating toolbar buttons.
- Updated styling elements to use `Color.withAlpha` rather than deprecated `Color.withOpacity` to prevent compilation/lint warnings and support older Flutter SDK versions.
- Guarded asynchronous `BuildContext` calls with `context.mounted` checks.
