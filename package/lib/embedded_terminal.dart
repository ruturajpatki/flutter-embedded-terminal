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

export 'src/embedded_terminal_widget.dart';
export 'src/embedded_terminal_controller.dart';
export 'src/terminal_events.dart';

// Export styling details from xterm so callers can theme without adding xterm to their pubspec.
export 'package:xterm/xterm.dart' show TerminalTheme, TerminalStyle, TerminalController;
