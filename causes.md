# The five usual causes of "my keyboard dies in a game until I alt-tab"

Everything here is a lead, not proof. "Verified" means checked on a real Windows 11 PC while building this
tool; "check on your PC" means it came from a web source or memory and may differ on your version of Windows.

## Decision table (used after `Watch-Input.ps1`)

First check that `keys` is above 0 while the game was in front and working. If it is 0 for the whole game session, the monitor cannot see this game (for example, the game runs as administrator), so zero rows prove nothing: rerun the monitor from an admin PowerShell.

| What the monitor CSV shows around the marker (game window in front, you say the keyboard was dead) | Points to |
|---|---|
| `keys` rows are **above 0** while the game is the foreground program: Windows saw your keys, the game ignored them | 1, 2 or 4 |
| `keys` rows drop to **0 for the whole dead stretch** and a `device` row (removed/arrived, or a `change-event` from Windows) sits next to it | 5 |
| `keys` rows drop to 0 with **no** device row, and the Application log has Vanguard / peripheral-app errors at that time | 3 |
| `keys` at 0, no device row, no Vanguard/app errors | 2 or 3; retest with overlays and the peripheral app closed |
| `fg` flips away from the game right before it died (a pop-up, overlay or notification stole focus) | 2 |
| `fg` flips to `sethc` (the Sticky Keys / Filter Keys pop-up took focus) | 4 |
| `keys` at 0 while the game is in front (you were pressing keys), back above 0 right after alt-tab | 2 or 3 (an overlay or peripheral app swallowing keys) |
Not settled? Run the monitor again with one suspect switched off (one change per test).

## 1. Game-side input-focus bug
- Confirm: monitor sees key-downs while the game is foreground but the game does nothing; Esc or alt-tab brings keys back; happens after dying or opening a menu/shop. Deadlock players report exactly this [1]. Wooting and Roccat keyboards are named there, but others hit it too.
- Fix: play borderless windowed instead of fullscreen; turn off fullscreen optimizations for the game's .exe (right-click the .exe > Properties > Compatibility) [5]; use Esc as the workaround; report it on the game's forum. There is no developer fix known.
- Check on your PC: the Compatibility tab wording differs between Windows builds.

## 2. Overlays and input hooks
- Confirm: `Read-Logs.ps1` lists running overlay programs (Steam, Discord, NVIDIA, AMD, Xbox Game Bar, Overwolf, Afterburner/RTSS). Then switch ONE off for one test. [4]
- Fix: Steam > Settings > In Game > untick the overlay; Discord > User Settings > Game Overlay off; Windows Settings > Gaming > Xbox Game Bar off; NVIDIA App / AMD Software > turn the in-game overlay off. Steam Input: per-game Properties > Controller > Disable Steam Input.
- Verified registry (value may be absent = Windows default): `HKCU\Software\Microsoft\GameBar` (`UseNexusForGamebarEnabled`, `ShowStartupPanel`), `HKCU\System\GameConfigStore` (`GameDVR_Enabled`, `GameDVR_FSEBehaviorMode`). Check on your PC: `AutoGameModeEnabled` under `HKCU\Software\Microsoft\GameBar` and `AppCaptureEnabled` under `HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR` (both absent on the test PC).
- Check on your PC: process names for NVIDIA, AMD, Corsair, Wooting and Overwolf are best guesses and were not seen running on the test PC.

## 3. Peripheral software vs Riot Vanguard (League of Legends, Valorant)
- Confirm: Application/System log errors or warnings that mention `vgc`, `vgk`, Vanguard, Riot or the peripheral app (Razer Synapse, Logitech G Hub, Corsair iCUE, Wooting Wootility, reWASD). A System event "timeout waiting for the vgc service to connect" (Service Control Manager, id 7009) is a Vanguard-side lead.
- Verified: Vanguard services are `vgk` (driver, Running is normal) and `vgc` (Stopped until a Riot game starts is normal). Vanguard log folder is `C:\Program Files\Riot Vanguard\Logs` (files `vgc_*.log`, `vgk_*.log`); it exists only if Vanguard is installed.
- Razer says Vanguard can block its drivers [2]; a reWASD user lost WASD in League after one match [3]. No source found for G Hub or iCUE.
- Fix: update Vanguard and the peripheral app; close the peripheral app for one test; if keys only die with the app open, reinstall it clean. Vendor tools (firmware updaters) are named, never installed, by pc-doctor.

## 4. Sticky Keys, Filter Keys, a second keyboard layout
- Confirm: `Read-Logs.ps1` decodes the Flags values. Verified keys: `HKCU\Control Panel\Accessibility\StickyKeys`, `...\Keyboard Response` (Filter Keys), `...\ToggleKeys`, value `Flags`; bit 1 = feature on, bit 4 = its shortcut (5x Shift, 8 s Shift) is enabled. Layouts: `Get-WinUserLanguageList` (verified); switch hotkey `HKCU\Keyboard Layout\Toggle` value `Hotkey` (check on your PC: absent on the test PC).
- Evidence is anecdotal: Deadlock thread blames layout switching [1]; a player fixed missing keys by turning Sticky Keys off [6][7].
- Fix: Settings > Accessibility > Keyboard: Sticky Keys, Filter Keys off and their shortcuts off; Settings > Time & language > Typing > Advanced keyboard settings: remove the extra layout and its Alt+Shift hotkey.

## 5. USB / HID device drop
- Confirm: `keys` goes to 0 and a `device` row appears; a USB connect/disconnect sound, or Num Lock light flicker, at that moment. Verified: event id **219** ("The driver ... failed to load", Warning) is in the **System** log, provider `Microsoft-Windows-Kernel-PnP`; id **411** ("Device ... had a problem starting", Error) is in the **Microsoft-Windows-Kernel-PnP/Configuration** log. A 219 for `WUDFRd` can also appear at boot on a healthy PC: it only counts if its time matches a drop or the driver is a keyboard/HID one (`kbdhid`, `HidUsb`). USB hub/controller providers also checked: `Microsoft-Windows-USB-USBHUB3`, `-USBXHCI`, `Microsoft-Windows-Input-HIDCLASS`. [8][9]
- Fix: Power Options > Change plan settings > Advanced > USB settings > USB selective suspend = Disabled; Device Manager > the USB hub / keyboard > Power Management > untick "Allow the computer to turn off this device"; try a rear motherboard port, no hub; update keyboard firmware (vendor tool: you decide). Check on your PC: menu names vary by Windows version.

## Sources
[1] https://forums.playdeadlock.com/threads/keyboard-frequently-stops-functioning-in-game-only-especially-after-dying.84965/latest
[2] https://mysupport.razer.com/app/answers/detail/a_id/1835/kw/gaming
[3] https://forum.rewasd.com/forum/rewasd/technical-questions-aa/247069-league-of-legends-wasd-stops-working?p=247082
[4] https://www.atera.com/blog/how-to-fix-alt-tab-not-working-in-windows-11/
[5] https://learn.microsoft.com/en-us/answers/a/7907435
[6] https://steamcommunity.com/app/1771300/discussions/0/601895505111347235
[7] https://www.elevenforum.com/t/windows-keyboard-key-not-working-in-game-eventually-breaks-all-together.9000/latest
[8] https://learn.microsoft.com/en-us/answers/a/3685622
[9] https://windowsreport.com/it/evento-id-411-kernel-pnp/
