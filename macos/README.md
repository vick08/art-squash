# vo-art-squash

A small macOS command-line tool that silences decorative box-drawing and block
characters (U+2500–259F: `─│╭╮╰╯├═║█▀▄░▒▓` …) for the VoiceOver screen reader.

TUI apps built on rendering engines such as Ink and Bubble Tea (Claude Code,
Antigravity, Pi-agent, …) draw frames and borders with these characters, and
VoiceOver reads every one of them aloud. This tool adds a VoiceOver
pronunciation entry for each character, applied to all applications, that
replaces it with a NUL character so nothing is spoken.

## Compatibility

- Tested on macOS 26 (Tahoe) with Swift 6.4.
- Building requires macOS 13 or later and Xcode 15+ (or the matching Command
  Line Tools).
- The tool expects VoiceOver's preferences in
  `~/Library/Group Containers/group.com.apple.VoiceOver/`. Older macOS
  releases may store them elsewhere (for example
  `~/Library/Preferences/com.apple.VoiceOver4/`). If they aren't found, the
  tool exits without writing anything. Use `--prefs-dir <path>` to point it at
  a different location.

Reports of success on other macOS versions are welcome.

## Build

```
swift build -c release
```

The executable is written to `.build/release/vo-art-squash`.

## Usage

```
vo-art-squash install --restart-voiceover   # add the entries
vo-art-squash list                          # show what is installed
vo-art-squash remove --restart-voiceover    # remove only this tool's entries
```

VoiceOver may overwrite its preferences while running, so changes are only
written when VoiceOver is off. `--restart-voiceover` quits VoiceOver, writes
the changes and relaunches it. `--force` writes anyway; `--dry-run` writes
nothing.

Before each write, the current preferences are backed up to
`~/Library/Application Support/vo-art-squash/backups/`.

## How it works

Entries are written to VoiceOver's preferences in
`~/Library/Group Containers/group.com.apple.VoiceOver/Library/Preferences/com.apple.VoiceOver4/`
(`default.plist`, plus timestamps in `journal.plist`), in the same format
VoiceOver Utility uses. The files are kept in binary plist format, which is
required to store U+0000.
