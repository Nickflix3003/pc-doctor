---
name: pc-doctor
description: Diagnose a Windows PC whose keyboard stops working inside a game until the player alt-tabs. Use when the user says "my keyboard stops working in game", "keyboard dies in League / Deadlock", "keys stop working until I alt-tab", or types "/pc-doctor". Reads Windows logs first, then (only if the user agrees) runs a small local input monitor, then names the likely cause and the fix.
---

# pc-doctor

Find out why a keyboard dies in a game (League of Legends, Deadlock, any other) until the player alt-tabs.
Windows only. Three steps, in order. Everything stays on this PC: reports go to `%USERPROFILE%\pc-doctor\`
and nothing is uploaded, installed or changed. Never install third-party software on your own: if a fix
needs a vendor tool (for example a keyboard firmware updater), name it and let the user decide.

The skill folder is the folder this file is in. Run scripts like this (this does not change any Windows setting):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill folder>\scripts\Read-Logs.ps1" -Since 7
```

Speak plain English. The user is a gamer, not a developer. No jargon without a one-line explanation.

## Before you start (ask in one message)
1. Which game(s), and does it happen in every game or only one?
2. When did it last happen (rough date and time)? Does Esc or alt-tab fix it, and how fast?
3. Which keyboard (brand/model), wired or wireless, and which extras run: Razer Synapse, Logitech G Hub, Corsair iCUE, Wooting Wootility, reWASD, Steam Input?
4. Does the mouse still work while the keyboard is dead?

## Step 1: read what is already there (no permission needed, it is read-only)
1. Run `Read-Logs.ps1`. If the user gave times, add `-Around "2026-10-25 21:40","2026-10-26 20:05"`.
   It prints a report and a path like `...\pc-doctor\read-logs-<stamp>.txt`.
2. Read the report. Open `causes.md` and judge the five causes against it:
   1. Game-side focus bug
   2. Overlays and input hooks
   3. Peripheral software vs Riot Vanguard
   4. Sticky Keys / Filter Keys / a second keyboard layout
   5. USB or HID device drop
3. Tell the user, per cause: **ruled in** (evidence found), **ruled out** (looked, clean), or **unknown**
   (logs cannot show it; causes 1 and 2 are often unknown from logs alone). Quote the line of the report that
   backs each call. Give the fix from `causes.md` for every ruled-in cause, one at a time, simplest first.
4. Warnings in the System/Application log are common on healthy PCs. Do not blame a cause on a log line
   unless it matches the symptom (keyboard, USB, HID, Vanguard, the peripheral app, or the time given).

If one ruled-in cause has a cheap fix (turn off Sticky Keys, close one overlay), suggest trying it first and
playing a few sessions before going to step 2. Offer to explain how to make the change; do not change settings yourself.

## Step 2: offer the monitor (ASK FIRST)
Go here when the logs do not settle it, or the user wants proof. Say, in plain words:

> I can run a small monitor while you play. It writes one file on this PC: which program is in front, how many
> keys you pressed each second (just a count, never which keys), and when a keyboard is unplugged or replugged.
> It does not hook the keyboard, touch the game or send anything anywhere. Want me to start it?

Run it only if the user says yes. Do not start it before they answer.

1. Ask which marker key they have: Pause/Break (default), Scroll Lock, Insert or F12. Many laptops have no
   Pause key. A mouse-clickable marker window exists (`-MarkerWindow`), but it needs the game in borderless
   or windowed mode to be visible; offer it only if they ask. They can also just tell you the time afterward.
2. Start it hidden so it keeps running while they play. Run this in PowerShell (change `240` to how many minutes they will play; the quotes around the path matter if it has spaces):

```
Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "<skill folder>\scripts\Watch-Input.ps1" -Minutes 240 -MarkerKey Pause' | Select-Object Id
```
   Add `-NoTitles` inside the quoted argument string if they do not want window titles recorded. Remember the process id.
3. Tell them: play normally. The moment the keyboard dies, press the marker key once (the monitor reads it
   even when the game ignores it), then do their usual fix (alt-tab), then keep playing. Come back and say "it happened".
4. They can stop it any time: `Stop-Process -Id <id>`. It stops by itself after the minutes you set.
5. Anti-cheat note, say it if they ask: the monitor only polls (GetForegroundWindow, GetAsyncKeyState) and lists
   keyboards. No hooks, no injection, no reading game memory, and no handle is opened to the game. Nobody can
   promise what a given anti-cheat will decide, so if they are nervous about ranked play, they can run it in
   normal games first.

## Step 3: read the monitor file after it happens
1. Find the newest `watch-<stamp>.csv` in `%USERPROFILE%\pc-doctor\`. Columns: `time,type,detail,value`.
   Types: `start`, `fg` (foreground program change; detail = program, value = window title), `keys` (one row per
   second; detail = foreground program, value = number of keys pressed), `device` (arrived/removed), `marker`, `stop`.
2. Find each `marker` row (or the time the user gives). Look at the 60 seconds before and after it:
   what program was in front, what the `keys` counts were, any `device` rows, any `fg` change just before.
3. Apply the decision table in `causes.md` and name the cause:
   - keys above 0 in the game while it ignored them: Windows saw the keys. Causes 1, 2 or 4. Use the step 1
     report to pick between them (overlay running? Sticky Keys on? second layout?).
   - keys at 0 for the dead stretch plus a `device` row: cause 5.
   - keys at 0, no device row, and Vanguard or peripheral-app errors in the Application log at that time: cause 3.
   - A `keys` row gap of more than a few seconds can be the monitor itself busy re-reading the keyboard list: do not count that as evidence.
   Say how sure you are. One occurrence is a lead; two that agree is solid.
4. Give the fix for that cause, then suggest ONE change at a time and a retest (run the monitor again if needed).
5. Look at the `keys` counts only; do not try to guess what was typed. The file has no key identities.

## If it is still not settled
Say so plainly and list what was ruled out. Offer the next test (for example: play one session with Steam and
Discord overlays off, or one with the peripheral app closed). Offer to write a short summary the user can post
on the game's support forum: game, keyboard model, which causes were ruled out, what the monitor showed.

## Without Claude Code
The README explains running both scripts by hand. The same report and CSV are produced; this skill just reads them for you.
