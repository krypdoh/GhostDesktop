; Script     ghostdesktop.ahk
; License:   MIT License
; Author:    Paul Charovkine (krypdoh), Bence Markiel (bceenaeiklmr) 
; Github:    
; Date       2026.03.20
; Version    0.9.2

#Requires AutoHotkey >=2.0
#Warn

; ── Persistent settings (%APPDATA%\ghostdesktop\ghostdesktop.ini) ─────────────
global gIniDir  := EnvGet("APPDATA") "\ghostdesktop"
global gIniFile := gIniDir "\ghostdesktop.ini"
global gHover   := Integer(IniRead(gIniFile, "Settings", "Hover", 0))
global gSpeed   := Integer(IniRead(gIniFile, "Settings", "Speed", 15))
global gDelay   := Number(IniRead(gIniFile, "Settings", "Delay", 20))
; Force compatibility fade path on systems where desktop listview alpha causes black flashes.
global gSafeMode := 1
global gForceReinit := false

DirCreate(gIniDir)
IniWrite(1, gIniFile, "Settings", "SafeMode")

; ── Tray menu ─────────────────────────────────────────────────────────────────
A_TrayMenu.Add()
A_TrayMenu.Add("Settings",  ShowSettingsGui)
A_TrayMenu.Add("Fix Wallpaper", FixWallpaper)
A_TrayMenu.Add("About",     ShowAboutGui)
A_TrayMenu.Default := "Settings"

SetTimer(HideMyIcon, 10)

/*
    ; Hover: effect triggered by clicking (0) or hovering (1)
    ; Speed: 1 (frames 256), 3 (86), 5 (52), 15 (18), 17 (16), 51 (6), 85 (4), 255 (2)
    ;        works with any number between 0, 255
    ; Delay: sleep time between changing the transparency, use "" or 0 for best performance
    ; Recommended presets:
    ;   SetTimer(HideMyIcon.Bind(1, 15, 20), 10)
    ;   SetTimer(HideMyIcon.Bind(1, 51,  0), 10)
    ;   SetTimer(HideMyIcon.Bind(0, 85,  0), 10)
    ;   SetTimer(HideMyIcon.Bind(0, 255, 0), 10)
*/
HideMyIcon(Hover := 0, Speed := 17, Delay := 16.67) {

    global gHover, gSpeed, gDelay, gSafeMode, gForceReinit
    Hover := gHover, Speed := gSpeed, Delay := gDelay

    static init := 0, hDesk := 0, hIcon := 0, hDefView := 0, Transparent := 255

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

        ; Get SHELLDLL_DefView (parent of SysListView32) — fading this layer avoids
        ; SysListView32 background compositing artefacts that can silhouette the wallpaper.
        hDefView := DllCall("GetParent", "ptr", hIcon, "ptr")
        if !hDefView
            hDefView := hIcon  ; fallback: fade the list-view itself

        ; Set listview background transparent so icons/labels fade cleanly.
        ConfigureDesktopListView(hIcon)

        ; Enable WS_EX_LAYERED once and never remove it — toggling it off triggers a
        ; brief DWM re-composite that can flash the wallpaper black on some systems.
        WinSetTransparent(255, "ahk_id " hIcon)

        ; raising proc priority makes the fade animation smoother (could be placebo)
        ProcessSetPriority("AboveNormal")
        ; exiting the script will restore the icons' transparency to 255
        OnExit(RestoreIcons)
        init := 1
    }

    ; Explorer can recreate the desktop list view; reacquire if needed.
    if !WinExist("ahk_id " hIcon) {
        init := 0
        return
    }

    Step := 0, id := ctrl := cls := wnd := ""
    ; active windows and transparency
    Desk := WinActive("ahk_id " hDesk)
    Tray := WinActive("ahk_class Shell_TrayWnd")
    ; start menu button gives an error
    try {
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

    NextStep := Transparent + Step * Speed,
    before := Transparent
    ; a minimum value of 1 is required for proper use of the taskbar and showdesk button
    if (NextStep == 1) || (NextStep == 0) || (0 > NextStep)
        Transparent := 1
    else if (NextStep > 255)
        Transparent := 255
    else
        Transparent := NextStep
    ; Apply alpha to the icon list-view. Never call WinSetTransparent("Off") — keeping
    ; WS_EX_LAYERED permanent prevents the DWM compositing flash on the wallpaper.
    if (Transparent != before)
        try WinSetTransparent(Transparent, "ahk_id " hIcon)
    if Delay
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

; ── Fix Wallpaper ────────────────────────────────────────────────────────────
FixWallpaper(*) {
    global gForceReinit

    ; Re-apply CLR_NONE to the listview immediately, then flag a full re-init so
    ; HideMyIcon re-acquires handles and re-enables WS_EX_LAYERED on the next tick.
    hIcon := GetDesktopIconListViewHwnd()
    if hIcon {
        ConfigureDesktopListView(hIcon)
        try WinSetTransparent(255, "ahk_id " hIcon)
    }
    gForceReinit := true

    ToolTip("Wallpaper fix applied.")
    SetTimer(() => ToolTip(), -2000)
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
        IniWrite(1, gIniFile, "Settings", "SafeMode")

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
    ag.Add("Text", "w300",
          "GhostDesktop  v0.9.2n`n"
        . "Fades desktop icons based on window focus`nor mouse position.`n`n"
        . "Authors:  Paul Charovkine (krypdoh)`n"
        . "               Bence Markiel (bceenaeiklmr)`n"
        . "License:  MIT`n"
        . "Date:     2026-03-20`n`n"
        . "Settings stored in:`n" gIniFile)
    ag.Add("Button", "w80 Default", "OK").OnEvent("Click", (*) => ag.Destroy())
    ag.OnEvent("Close", (*) => ag.Destroy())
    ag.Show("AutoSize")
}
