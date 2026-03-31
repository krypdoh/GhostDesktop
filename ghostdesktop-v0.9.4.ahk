; Script:      ghostdesktop.ahk
; License:     AGPL-v3.0 License
; Author:      Paul R. Charovkine (krypdoh)
; Github:      github.com/krypdoh/GhostDesktop
; Date         2026.03.31
; Version      0.9.4
; Description: Fades Windows desktop icons in and out based on window focus or mouse position.

#Requires AutoHotkey >=2.0
#Warn

;@Ahk2Exe-SetMainIcon  ghostdesktop.ico

; ── Persistent settings (%APPDATA%\ghostdesktop\ghostdesktop.ini) ─────────────
global gIniDir  := EnvGet("APPDATA") "\ghostdesktop"
global gIniFile := gIniDir "\ghostdesktop.ini"
global gHover   := Integer(IniRead(gIniFile, "Settings", "Hover", 0))
global gSpeed   := Integer(IniRead(gIniFile, "Settings", "Speed", 15))
global gDelay   := Number(IniRead(gIniFile, "Settings", "Delay", 20))
global gForceReinit := false

; ── Icon paths ────────────────────────────────────────────────────────────────
; When compiled, extract the white icon to %TEMP% so we can swap at runtime.
; The default icon is already the EXE's main icon (group 1).
global gIconWhitePath := ""
if A_IsCompiled {
    gIconWhitePath := A_Temp "\ghostdesktop-white.ico"
    FileInstall("ghostdesktop-white.ico", gIconWhitePath, true)
}

SetGhostIcon(paused := false) {
    if A_IsCompiled {
        if paused
            TraySetIcon(gIconWhitePath, 1, true)
        else
            TraySetIcon(A_ScriptFullPath,, true)
    } else {
        icoPath := A_ScriptDir "\" (paused ? "ghostdesktop-white.ico" : "ghostdesktop.ico")
        TraySetIcon(icoPath, 1, true)
    }
}

DirCreate(gIniDir)

; ── Tray menu ─────────────────────────────────────────────────────────────────
A_TrayMenu.Delete()
A_TrayMenu.Add("Settings",           ShowSettingsGui)
A_TrayMenu.Add()
A_TrayMenu.Add("Pause GhostDesktop", TogglePause)
A_TrayMenu.Add("Suspend Hotkeys",    (*) => Suspend(-1))
A_TrayMenu.Add("Reload GhostDesktop", (*) => Reload())
A_TrayMenu.Add("About",              ShowAboutGui)
A_TrayMenu.Add("Donate!",            (*) => Run("https://www.paypal.com/paypalme/paypaulc"))
A_TrayMenu.Add("Exit",               (*) => ExitApp())
A_TrayMenu.Default := "Settings"

SetGhostIcon()

TogglePause(*) {
    if A_IsPaused {
        SetGhostIcon(false)
        A_TrayMenu.Uncheck("Pause GhostDesktop")
        Pause(0)
    } else {
        Pause(1)
        SetGhostIcon(true)
        A_TrayMenu.Check("Pause GhostDesktop")
    }
}

SetTimer(HideMyIcon, 10)

HideMyIcon() {

    global gHover, gSpeed, gDelay, gForceReinit
    local Hover := gHover, Speed := gSpeed, Delay := gDelay

    static init := 0, hDesk := 0, hIcon := 0, Transparent := 255

    if gForceReinit {
        gForceReinit := false
        init := 0
    }

    if !init {
        ; Resolve the exact desktop icon list view (SHELLDLL_DefView -> SysListView32).
        hIcon := GetDesktopIconListViewHwnd()
        if !hIcon
            return

        ; Keep the active desktop host handle for click-mode detection.
        hDesk := DllCall("GetAncestor", "ptr", hIcon, "uint", 2, "ptr") ; GA_ROOT = 2
        if !hDesk {
            hDesk := WinExist("ahk_class Progman")
            if !hDesk
                hDesk := WinExist("ahk_class WorkerW")
        }

        ; Set listview background transparent so icons/labels fade cleanly.
        ConfigureDesktopListView(hIcon)

        ; Enable WS_EX_LAYERED directly on the SysListView32 (icon list-view).
        ; Because its background is CLR_NONE, only the icons and labels are drawn,
        ; so fading this window leaves the wallpaper fully visible at all times.
        WinSetTransparent(255, "ahk_id " hIcon)

        ; raising proc priority makes the fade animation smoother (could be placebo)
        ProcessSetPriority("AboveNormal")
        ; exiting the script will restore the icons' transparency to 255
        OnExit(RestoreIcons)
        init := 1
    }

    ; Explorer can recreate the desktop list view; reacquire if needed.
    if !DllCall("IsWindow", "ptr", hIcon) {
        init := 0
        return
    }

    Step := 0, cls := "", ctrl := "", wnd := ""
    ; active windows and transparency
    Desk := WinActive("ahk_id " hDesk)
    Tray := WinActive("ahk_class Shell_TrayWnd")
    ; start menu button gives an error
    try {
        id := 0
        MouseGetPos(,, &id, &ctrl)
        cls := WinGetClass("ahk_id" id)
        wnd := WinGetTitle("ahk_id" id)
    }
    ; class under mouse
    MousePos := ((cls ~= "Shell_TrayWnd" && ctrl ~= "TrayShowDesktopButton")
              || (cls ~= "Progman|WorkerW" && wnd == "") ? "ShowDesk"
               : (cls ~= "Progman|WorkerW") ? "Desktop"
               : (cls ~= "Shell_TrayWnd") ? "Taskbar"
               : (cls ~= "DFTaskbar") ? "DisplayFusion" : "")

    ; decrease or increase transparency
    if !Hover
        Step := (Desk||Tray) ? 1 : -1
    else
        Step := (MousePos) ? 1 : -1
    ; forcing fade in effect at TrayShowDesktopButton
    if (MousePos ~= "ShowDesk|Tray")
        Step := 1

    NextStep := Transparent + Step * Speed
    before := Transparent
    ; clamp 1–255 (minimum 1 required for proper taskbar / showdesk interaction)
    Transparent := Max(1, Min(255, NextStep))
    ; Apply alpha directly to the SysListView32 — its background is CLR_NONE so only
    ; icons/labels fade; the wallpaper painted by Progman/WorkerW stays fully opaque.
    if (Transparent != before)
        try WinSetTransparent(Transparent, "ahk_id " hIcon)
    ; Only sleep during active animation; skip when already at target for lower idle CPU.
    if Delay && (Transparent != before)
        Sleep(Delay)
    return

    RestoreIcons(*) {
        try WinSetTransparent(255, "ahk_id " hIcon)
    }

}

GetDesktopIconListViewHwnd() {
    progman := WinExist("ahk_class Progman")
    if !progman
        return 0

    hDefView := DllCall("FindWindowEx", "ptr", progman, "ptr", 0, "str", "SHELLDLL_DefView", "ptr", 0, "ptr")
    if !hDefView {
        worker := 0
        while worker := DllCall("FindWindowEx", "ptr", 0, "ptr", worker, "str", "WorkerW", "ptr", 0, "ptr") {
            hDefView := DllCall("FindWindowEx", "ptr", worker, "ptr", 0, "str", "SHELLDLL_DefView", "ptr", 0, "ptr")
            if hDefView
                break
        }
    }

    if !hDefView
        return 0

    return DllCall("FindWindowEx", "ptr", hDefView, "ptr", 0, "str", "SysListView32", "ptr", 0, "ptr")
}

ConfigureDesktopListView(hIcon) {
    static LVM_FIRST := 0x1000
    static LVM_SETBKCOLOR := LVM_FIRST + 1
    static LVM_SETTEXTBKCOLOR := LVM_FIRST + 38
    static CLR_NONE := 0xFFFFFFFF

    ; Keep list-view background transparent so only icons/labels fade, not wallpaper.
    SendMessage(LVM_SETBKCOLOR, 0, CLR_NONE, , "ahk_id " hIcon)
    SendMessage(LVM_SETTEXTBKCOLOR, 0, CLR_NONE, , "ahk_id " hIcon)
}

; ── Settings GUI ──────────────────────────────────────────────────────────────
ShowSettingsGui(*) {
    global gHover, gSpeed, gDelay, gIniFile, gIniDir

    sg := Gui("+AlwaysOnTop", "GhostDesktop — Settings")
    sg.SetFont("s9", "Segoe UI")
    sg.MarginX := 16, sg.MarginY := 14

    sg.Add("Text", "w280 Section", "Hover trigger:")
    ddHover := sg.Add("DropDownList", "vHover xs w280 Choose" (gHover + 1),
        ["0 — Click   (fade on window activate / deactivate)",
         "1 — Hover  (fade on mouse-over)"])

    sg.Add("Text", "xs w280 y+12",
        "Speed  (1–255    lower = smoother / more frames):")
    editSpeed := sg.Add("Edit",   "vSpeed xs w70 Limit3 Number y+4", gSpeed)
    sg.Add("UpDown", "Range1-255", gSpeed)

    sg.Add("Text", "xs w280 y+12",
        "Delay  ms between steps  (0 or blank = best performance):")
    sg.Add("Edit", "vDelay xs w70 Limit6 y+4", gDelay > 0 ? gDelay : "")

    sg.Add("Button", "xs y+16 w80 Default", "Save").OnEvent("Click", SaveSettings)
    sg.Add("Button", "x+8 w80",   "Apply").OnEvent("Click", ApplySettings)
    sg.Add("Button", "x+8 w80",   "Cancel").OnEvent("Click", (*) => sg.Destroy())
    sg.Add("Button", "x+8 w120",  "Reset Defaults").OnEvent("Click", ResetDefaults)

    sg.OnEvent("Close", (*) => sg.Destroy())
    sg.Show("AutoSize")

    SaveSettings(*) {
        ApplySettings()
        sg.Destroy()
    }

    ApplySettings(*) {
        saved    := sg.Submit(false)
        newHover := ddHover.Value - 1        ; DropDownList is 1-based: 1→0, 2→1
        newSpeed := Max(1, Min(255, Integer(editSpeed.Value)))
        delayStr := Trim(saved.Delay)
        newDelay := (delayStr == "" || delayStr == "0") ? 0 : Number(delayStr)

        gHover := newHover
        gSpeed := newSpeed
        gDelay := newDelay

        DirCreate(gIniDir)
        IniWrite(gHover, gIniFile, "Settings", "Hover")
        IniWrite(gSpeed, gIniFile, "Settings", "Speed")
        IniWrite(gDelay, gIniFile, "Settings", "Delay")

        ToolTip("Settings applied.")
        SetTimer(() => ToolTip(), -2000)
    }

    ResetDefaults(*) {
        ddHover.Choose(1)          ; Hover = 0 (click)
        editSpeed.Value := 15
        sg["Delay"].Value := 20
    }
}

; ── About dialog ──────────────────────────────────────────────────────────────
ShowAboutGui(*) {
    global gIniFile

    ag := Gui("+AlwaysOnTop", "About GhostDesktop")
    ag.SetFont("s9", "Segoe UI")
    ag.MarginX := 20, ag.MarginY := 16
    ag.Add("Text", "w400",
          "GhostDesktop  v0.9.4`n`n"
        . "Fades desktop icons based on window focus or mouse position.")
    ag.Add("Link", "w400", 
          'Author:   Paul R. Charovkine (krypdoh)`n'
        . 'License:  <a href="https://www.gnu.org/licenses/agpl-3.0.html#license-text">AGPL-3.0</a> `n'
        . 'Date:      2026-03-31`n'
        . 'Website:  <a href="https://krypdoh.github.io/GhostDesktop/">krypdoh.github.io/GhostDesktop/</a> `n`n'
        . 'If you find GhostDesktop useful please consider <a href="https://www.paypal.com/paypalme/paypaulc">donating</a>.`n`n'
        . "Settings stored in:`n" gIniFile)
    ag.Add("Button", "w80 Default", "OK").OnEvent("Click", (*) => ag.Destroy())
    ag.OnEvent("Close", (*) => ag.Destroy())
    ag.Show("AutoSize")
}
