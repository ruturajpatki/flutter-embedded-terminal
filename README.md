# EmbeddedTerminal

![Build](https://img.shields.io/badge/Build-Passing-green?style=for-the-badge) ![Framework](https://img.shields.io/badge/Framework-Flutter%20Dart-blue?style=for-the-badge) ![Platforms](https://img.shields.io/badge/Platforms-WIN%20%E2%80%A2%20MAC%20%E2%80%A2%20LINUX-yellowgreen?style=for-the-badge) ![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey?style=for-the-badge)

**A reusable cross-platform embedded terminal widget for Flutter Desktop.**

EmbeddedTerminal brings a real terminal experience directly into Flutter Desktop applications. It is designed for applications that need to execute developer commands and display their output inside the application's own UI, without opening an external Command Prompt, PowerShell, Terminal, or other terminal application.

Built with a terminal emulator and a real PTY architecture, EmbeddedTerminal is intended to provide a terminal experience similar to the integrated terminal found in modern developer tools such as VS Code.

**Demo**

*Embedded Terminal Flutter Component - Interactive Mode*
![Embedded Terminal Flutter Component - Interactive Mode](./documentation/images/interactive.gif)

*Embedded Terminal Flutter Component  - ReadOnly Mode*
![Embedded Terminal Flutter Component  - ReadOnly Mode](./documentation/images/readonly.gif)

---

## ✨ What is EmbeddedTerminal?

EmbeddedTerminal is a reusable Flutter package that provides:

* 🖥️ A native-feeling embedded terminal UI
* ⚡ Real PTY-backed command execution
* 🎨 ANSI/VT terminal output and colors
* ⌨️ Interactive terminal input
* 📐 Automatic terminal resizing
* ▶️ Programmatic command execution
* ⏹️ Stop and restart support
* 📡 Command lifecycle events
* 📁 Configurable working directories
* 🌍 Windows, macOS, and Linux support
* 📋 Configurable copy button to copy the entire terminal buffer or only the selected text to the clipboard
* 💾 Configurable save to file button to export the entire terminal buffer or only the selected text to a text file

The package hides the complexity of process management, PTY handling, terminal emulation, and platform-specific implementation behind a simple Flutter API.

## 🎯 Why EmbeddedTerminal?

Flutter Desktop applications often need to execute developer tools such as:

```text
npm
node
php
composer
git
flutter
dart
```

A basic `Process.start()` implementation can capture process output, but it does not provide the behavior of a real interactive terminal.

EmbeddedTerminal addresses this by providing a terminal abstraction that can host interactive command-line processes directly inside a Flutter UI.

Instead of:

```text
Flutter Application
        │
        ▼
   Process.start()
        │
        ▼
External Terminal Window
```

EmbeddedTerminal provides:

```text
Flutter Application
        │
        ▼
 EmbeddedTerminal
        │
        ▼
   Terminal Emulator
        │
        ▼
      PTY
        │
        ▼
Command / Shell / Process
```

## 🖥️ Supported Platforms

EmbeddedTerminal is designed for:

| Platform | PTY Architecture |
| -------- | ---------------- |
| Windows  | Windows ConPTY   |
| macOS    | POSIX PTY        |
| Linux    | POSIX PTY        |

The goal is to provide a consistent Flutter API while keeping platform-specific terminal implementation isolated internally.

## 🚀 Typical Use Cases

EmbeddedTerminal is intentionally generic and is not tied to a particular framework or development workflow.

Possible use cases include:

### Web application development

```bash
npm run dev
```

### Laravel development

```bash
php artisan serve
```

```bash
npm run dev -- --host=127.0.0.1 --port=8050
```

### Flutter development tools

```bash
flutter pub get
```

### Node.js tooling

```bash
npm install
```

```bash
node scripts/build.js
```

### Git operations

```bash
git status
```

```bash
git pull
```

The consuming application decides which commands to execute.

EmbeddedTerminal simply provides the terminal environment in which they run.

## 🧩 Simple Integration

The intended integration experience is deliberately small.

A consuming Flutter application can place an `EmbeddedTerminal` widget in its UI and control it through an `EmbeddedTerminalController`.

Conceptually:

```dart
final controller = EmbeddedTerminalController();

EmbeddedTerminal(
  controller: controller,
  workingDirectory: projectPath,
  isInteractive: true,
  onCmdRunStart: (event) {
    // Command started
  },
  onCmdRunComplete: (event) {
    // Command completed
  },
  onCmdRunError: (event) {
    // Command failed
  },
);
```

Commands are then started through the controller:

```dart
await controller.runCommand(
  'npm run dev -- --host=127.0.0.1 --port=8050',
);
```

The consuming application does not need to manage:

* PTY creation
* process streams
* terminal rendering
* ANSI output
* platform-specific process handling
* ConPTY
* POSIX PTYs
* terminal cleanup

Those responsibilities belong to EmbeddedTerminal.

## 🔀 Interactive and Read-Only Modes

The terminal widget provides an `isInteractive` property.

### Interactive

```dart
EmbeddedTerminal(
  controller: controller,
  isInteractive: true,
)
```

The user can interact with the running process through the terminal.

### Read-only

```dart
EmbeddedTerminal(
  controller: controller,
  isInteractive: false,
)
```

The terminal becomes a read-only output console.

The process can still be started programmatically and continues running normally. User keyboard input is simply not forwarded to the PTY.

This makes EmbeddedTerminal useful both as:

* an interactive developer terminal
* a build/output/log console

## 📡 Command Lifecycle

The package exposes command lifecycle events so the host application can react to execution state.

The core events are:

```text
onCmdRunStart
onCmdRunComplete
onCmdRunError
```

This allows a host application to implement UI such as:

```text
Idle
  ↓
Running...
  ↓
Completed
```

or:

```text
Idle
  ↓
Running...
  ↓
Failed
```

The events provide structured information rather than requiring the host application to parse terminal output.

## 🏗️ Architecture

The core architecture separates the visual terminal from command execution and platform-specific PTY handling.

```text
┌───────────────────────────────────────┐
│       Flutter Application             │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │       EmbeddedTerminal          │  │
│  │                                 │  │
│  │       Terminal Emulator         │  │
│  └───────────────┬─────────────────┘  │
│                  │                    │
│                  ▼                    │
│        EmbeddedTerminalController    │
│                  │                    │
│                  ▼                    │
│             Terminal Session         │
│                  │                    │
│                  ▼                    │
│              PTY Layer               │
└──────────────────┼────────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
     Windows     macOS      Linux
     ConPTY      POSIX PTY  POSIX PTY
```

This architecture allows the Flutter API to remain platform independent while the implementation handles the differences between desktop operating systems.

## 📦 Repository Structure

The repository contains two primary components:

```text
/
├── package/
│   └── EmbeddedTerminal Flutter package
│
└── demo/
    └── Flutter Desktop demonstration application
```

The `package` is the actual reusable product.

The `demo` application is a reference consumer of the package and demonstrates how an external Flutter application can integrate EmbeddedTerminal.

## 🧪 Demo Application

The demo application provides a simple UI containing:

* Base Folder selector
* Command input
* Sample command picker
* Run Command button
* Stop/Restart controls
* Embedded terminal output
* Command execution status

The initial demonstration uses an npm/Laravel development command:

```bash
npm run dev -- --host=127.0.0.1 --port=8050
```

However, the demo also supports generic commands such as:

```bash
node --version
npm --version
git status
```

Laravel is therefore a demonstration scenario—not a dependency of the EmbeddedTerminal package.

## 📚 Documentation

See the Wiki pages for details.
Documentation will evolve alongside the package.

## 🚧 Project Status

EmbeddedTerminal is currently being developed as a proof of concept with the goal of becoming a reusable Flutter Desktop package.

The initial focus is:

1. Reliable PTY-backed terminal execution
2. Windows support
3. macOS support
4. Linux support
5. Clean Flutter widget API
6. Command lifecycle events
7. Interactive and read-only terminal modes
8. A working reference application

API stability and broader production hardening will follow as the implementation matures.

## 🤝 Contributing

Contributions, ideas, bug reports, and improvements are welcome.

Before making substantial changes, please review the architecture and existing package conventions documented in this Wiki.

## 📄 License

See the repository license for the current licensing terms.

---

**EmbeddedTerminal — bring the terminal into your Flutter application.**
