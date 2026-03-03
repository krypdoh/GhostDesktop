# GhostDesktop 🚀

Lightweight AutoHotkey utility for managing desktop behavior and quick hotkeys.

## Overview

This repository contains `ghostdesktop-v0.9.ahk`, an AutoHotkey script you can run on Windows to enable the project's features.

## Features ✨

- 🕶️ Ghost Mode — quickly hide/show desktop elements (icons, wallpaper, etc.)
- ⌨️ Hotkeys — customizable global hotkeys for common actions
- ⚙️ Configurable — settings accessible at the top of the script
- 🔁 Startup support — optional "start with Windows" behavior
- 🧾 Tray menu — run, pause, or exit from the system tray (if implemented)

## Requirements

- AutoHotkey (install from https://www.autohotkey.com/)

## Installation

1. Install AutoHotkey on Windows.
2. Place `ghostdesktop-v0.9.ahk` in a convenient folder (this repository root).

## Usage ▶️

- Double-click `ghostdesktop-v0.9.ahk` to run it with AutoHotkey.
- Or run from PowerShell/CMD:

```powershell
"C:\Program Files\AutoHotkey\AutoHotkey.exe" ghostdesktop-v0.9.ahk
```

If the script requires administrative privileges, run AutoHotkey as Administrator.

## How to use Settings ⚙️

1. Open `ghostdesktop-v0.9.ahk` in a text editor.
2. Look for a top section labeled `; Settings` or `; Configuration` — most user-configurable variables live there.
3. Change values and hotkeys, then save and reload the script (right-click the tray icon → Reload Script) or restart the script.

Example settings block (your variable names may differ):

```ahk
; --------------------
; Settings
; --------------------
StartWithWindows := true
ToggleHotkey := "#g" ; Win+G
ShowTrayIcon := true
```

- Hotkey format: use AutoHotkey hotkey strings, e.g. `^!t` = Ctrl+Alt+T, `#g` = Win+G.
- Boolean toggles: use `true` / `false` (or `1` / `0`) depending on how the script checks them.

## Troubleshooting 🛠️

- If hotkeys don't work, ensure no other app is capturing the same key combination.
- Run AutoHotkey as Administrator if the script needs elevated access.

## Contributing 🤝

Improvements welcome. Please open an issue or submit a pull request with a clear description of behavior changes.

## License 📄

Add a license of your choice or contact the repository owner for licensing details.

---
Generated README scaffold by assistant. Update feature details to match the script's actual behavior.
