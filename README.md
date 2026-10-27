# pc-doctor

Shared by a friend. If your keyboard stops working inside a game (League, Deadlock, anything) and only comes
back after you alt-tab out and in again, this helps find out why. It checks the five usual causes:
game bug, overlays (Steam, Discord, Game Bar...), mouse/keyboard software fighting Riot Vanguard,
Sticky Keys or a second keyboard layout, and a USB hiccup.

It works in three steps: read the Windows logs that already exist, then (only if you say yes) run a small
monitor while you play, then tell you the likely cause and the fix. Reports are saved on your PC, in
`%USERPROFILE%\pc-doctor\`. The scripts upload, install and change nothing. If you use Claude Code, Claude
reads the report and the monitor file to explain them, so that text (program names, window titles unless
`-NoTitles`, device names) goes to Claude like anything else you show it. The monitor counts how many keys you
press per second but never which keys, so it is not a keylogger. Windows 10/11 only.

## With Claude Code
Paste this one line into Claude Code, then type `/pc-doctor`:

> Install the pc-doctor skill from https://github.com/OWNER/pc-doctor into my Claude Code skills folder (clone it to ~/.claude/skills/pc-doctor, or download the zip if git is missing), then run /pc-doctor.

If /pc-doctor is not found, close and reopen Claude Code.

## Without Claude Code
1. Download this repo (green Code button > Download ZIP) and unzip it.
2. Open PowerShell in the folder (right-click inside the folder > Open in Terminal on Windows 11, or Shift+right-click > Open PowerShell window here on Windows 10) and run (read-only, changes nothing):
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Read-Logs.ps1 -Since 7`
   Read the "QUICK READ" part at the bottom. Add `-Around "2026-10-25 21:40"` with a time it happened to focus on that moment.
3. Still unsure? Start the monitor, play, press the Pause/Break key (or Scroll Lock with `-MarkerKey ScrollLock`) when the keyboard dies, press Ctrl+C when done:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Watch-Input.ps1 -MarkerKey Pause`
4. Open `causes.md` and match what you saw to the table at the top. It also lists the fix for each cause.

The reports are plain text and CSV files in `%USERPROFILE%\pc-doctor\`. Delete them whenever you like.

MIT licensed, see LICENSE.
