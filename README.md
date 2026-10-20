# Art Squash

Silence the decorative box-drawing and block characters
(U+2500–259F: `─│╭╮╰╯├═║█▀▄░▒▓` …) that screen readers read aloud in
terminal apps.

TUI apps built on rendering engines such as Ink and Bubble Tea (Claude Code,
Antigravity, Pi-agent, …) draw frames, borders and progress bars with these
characters. A screen reader reads every one of them. Art Squash removes them
from speech, so you hear only the text inside the frames.

## Platforms

| Screen reader | Folder | Status |
|---|---|---|
| VoiceOver (macOS) | [`voiceover/`](voiceover/) | Working. Command-line tool that adds VoiceOver pronunciation entries. |
| NVDA (Windows) | [`nvda/`](nvda/) | **Still being tested.** Add-on with per-application settings. |

Each folder has its own README with installation and usage instructions, and
its own version number and releases.

## Releases

Releases are tagged per platform: `macos-v…` for the VoiceOver tool and
`nvda-v…` for the NVDA add-on.

## Keeping the platforms consistent

Both tools silence the same range, U+2500–259F (Box Drawing and Block
Elements). If the range changes, update it in both places:
`squashedScalars` in `voiceover/Sources/vo-art-squash/main.swift` and `ART_PATTERN`
in `nvda/addon/globalPlugins/artSquash/__init__.py`.

## License

Each platform has its own license:

- The VoiceOver tool in [`voiceover/`](voiceover/) is released under the MIT License.
  See [`voiceover/LICENSE`](voiceover/LICENSE).
- The NVDA add-on in [`nvda/`](nvda/) is released under the GNU General Public
  License, version 2 or later, the same license as NVDA itself. See
  [`nvda/LICENSE`](nvda/LICENSE).
