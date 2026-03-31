# GhostDesktop 👻

Lightweight AutoHotkey v2 utility that fades Windows desktop icons in and out based on window focus or mouse position.

## Features ✨

- 🕶️ **Auto-fade** — desktop icons fade out when windows are focused and fade back in when the desktop is visible
- 🖱️ **Hover mode** — optionally trigger fade based on mouse position (desktop, taskbar, show-desktop button)
- ⚙️ **Settings GUI** — configure hover mode, fade speed, and delay from the tray menu
- 🔄 **Persistent settings** — saved to `%APPDATA%\ghostdesktop\ghostdesktop.ini`
- 🧾 **Tray menu** — Settings, Pause, Suspend Hotkeys, Reload, About, Donate, and Exit

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (if running the `.ahk` script)

## Installation

### Script
1. Install AutoHotkey v2.
2. Double-click `ghostdesktop.ahk` to run.

### Compiled EXE
1. Download `ghostdesktop.exe` from [Releases](https://github.com/krypdoh/GhostDesktop/releases).
2. Double-click `ghostdesktop.exe` — no AutoHotkey installation required.

## Usage ▶️

Run `ghostdesktop.ahk` or `ghostdesktop.exe`. The script minimizes to the system tray.

Right-click the tray icon for options:

| Menu Item | Description |
|---|---|
| **Settings** | Open the settings GUI (default double-click action) |
| **Pause GhostDesktop** | Pause/resume the fade effect |
| **Suspend Hotkeys** | Suspend all hotkeys |
| **Reload GhostDesktop** | Restart the script or EXE |
| **About** | Version info and links |
| **Exit** | Quit GhostDesktop |

## Settings ⚙️

Settings are configured via the tray menu → **Settings** GUI:

- **Hover trigger** — enable mouse-position-based fading (off by default)
- **Fade speed** — how quickly icons fade in/out (1–50, default 15)
- **Fade delay** — milliseconds between fade steps (1–100, default 20)

Settings persist across restarts in `%APPDATA%\ghostdesktop\ghostdesktop.ini`.

## Troubleshooting 🛠️

- If desktop icons don't reappear after exiting, right-click the desktop → View → Show desktop icons.
- Run as Administrator if the script doesn't respond to desktop events.

## Contributing 🤝

Improvements welcome. Please open an issue or submit a pull request.

## License 📄

[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html#license-text)
