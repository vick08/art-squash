# Art Squash for NVDA

An NVDA add-on that silences decorative box-drawing and block characters
(U+2500–259F: `─│╭╮╰╯├═║█▀▄░▒▓` …) in the applications you choose.

TUI apps built on rendering engines such as Ink and Bubble Tea (Claude Code,
Antigravity, Pi-agent, …) draw frames, borders and progress bars with these
characters, and NVDA reads them aloud. Art Squash removes them from speech
before it reaches the synthesizer, so you hear only the text inside the frames.

Part of [Art Squash](../README.md). The VoiceOver version for macOS is in
[`../voiceover`](../voiceover/).

> **Status: still being tested.** This add-on has not yet been fully tested
> with NVDA on Windows. Expect rough edges, and please report problems as
> GitHub issues. Releases are marked as pre-releases until testing is done.

## Features

- Silences box-drawing and block characters in a list of applications, or in
  all applications.
- Turn silencing on or off at any time with a keystroke.
- Add or remove the current application from the list with a keystroke.
- Leaves character-by-character reading alone, so you can still arrow onto a
  character to find out what it is.
- Settings follow NVDA configuration profiles.

## Requirements

NVDA 2024.4 or later.

## Installation

Download the `.nvda-addon` file, press Enter on it, and confirm the installation
when NVDA asks. Restart NVDA when prompted.

## Usage

### Settings

Open NVDA's Settings dialog (NVDA+N, Preferences, Settings) and choose the
**Art Squash** category:

- **Silence decorative box-drawing characters**: turns the add-on on or off.
- **Apply to**: only the applications listed below, or all applications.
- **Applications**: the list of applications. Select one and press **Remove**
  to delete it, or type a name in **New application name** and press **Add**.

Applications are identified by NVDA's application name, which is the name of
the program file without `.exe` (for example `windowsterminal` or `code`).
The default list is:

| Name | Application |
|---|---|
| `windowsterminal` | Windows Terminal |
| `openconsole` | Windows Terminal's console host |
| `cmd` | Command Prompt |
| `powershell` | Windows PowerShell |
| `pwsh` | PowerShell 7 |
| `code` | Visual Studio Code |

### Commands

The commands have no keystrokes by default, to avoid clashing with other
add-ons. Assign them in NVDA's Input Gestures dialog (NVDA+N, Preferences,
Input Gestures), under the **Art Squash** category:

- **Turns silencing of decorative box-drawing characters on or off**:
  announces "ASCII art silenced" or "ASCII art spoken".
- **Adds the current application to the Art Squash list, or removes it**:
  the easiest way to add an application without knowing its name.

## Building

The add-on is pure Python, so building only means zipping the `addon` folder.
From this folder (`nvda/`):

```
python3 build.py
```

The package is written to `dist/artSquash-<version>.nvda-addon`.

## License

Copyright (C) 2026 Victor Tsaran. Released under the
[GNU General Public License](LICENSE), version 2 or later, the same license as
NVDA itself.
