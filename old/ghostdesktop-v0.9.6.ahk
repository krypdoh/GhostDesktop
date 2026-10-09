; Script:      ghostdesktop.ahk
; License:     AGPL-v3.0 License
; Author:      Paul R. Charovkine (krypdoh)
; Github:      github.com/krypdoh/GhostDesktop
; Date         2026.10.05
; Version      0.9.6
; Description: Fades Windows desktop icons in and out based on window focus or mouse position.

#Requires AutoHotkey >=2.0
#Warn

; Desktop list view is briefly hidden on lock/unlock and appbar docking; still target it.
DetectHiddenWindows(true)

;@Ahk2Exe-SetMainIcon  ghostdesktop.ico
;@Ahk2Exe-AddResource  ghostdesktop-white.ico, 160

; ── Persistent settings (%APPDATA%\ghostdesktop\ghostdesktop.ini) ─────────────
global gIniDir  := EnvGet("APPDATA") "\ghostdesktop"
global gIniFile := gIniDir "\ghostdesktop.ini"
global gHover   := Integer(IniRead(gIniFile, "Settings", "Hover", 0))
global gSpeed   := Integer(IniRead(gIniFile, "Settings", "Speed", 15))
global gDelay   := Number(IniRead(gIniFile, "Settings", "Delay", 20))
global gForceReinit := false
global gDbgOn   := false
global gDbgInfo := ""

SetGhostIcon(paused := false) {
    if A_IsCompiled {
        if paused
            TraySetIcon(A_ScriptFullPath, -160, true)
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
A_TrayMenu.Add("Debug Info",         ShowDebugGui)
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

    global gHover, gSpeed, gDelay, gForceReinit, gDbgOn, gDbgInfo
    local Hover := gHover, Speed := gSpeed, Delay := gDelay

    static init := 0, hDesk := 0, hIcon := 0, hTarget := 0, raised := false
    static origKey := 0, origAlpha := 255, origFlags := 2
    static Transparent := 255, lastModeCheck := 0, exitHooked := false

    if gForceReinit {
        gForceReinit := false
        ReleaseTarget()
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

        ClearLegacyKeyColor(hIcon)

        hTarget := GetFadeTarget(hIcon, &raised)
        if raised {
            ; Explorer owns WS_EX_LAYERED on the raised DefView; only change its alpha and restore it later.
            k := 0, a := 0, f := 0
            if !DllCall("GetLayeredWindowAttributes", "ptr", hTarget, "uint*", &k, "uchar*", &a, "uint*", &f)
                k := 0, a := 255, f := 2
            origKey := k, origAlpha := (f & 2) ? a : 255, origFlags := f
            ; A layered list view inside a transparent DefView renders black over the wallpaper.
            try {
                if WinGetExStyle("ahk_id " hIcon) & 0x80000
                    WinSetTransparent("Off", "ahk_id " hIcon)
            }
        }

        if !SetTargetAlpha(Transparent) {
            hTarget := 0
            return
        }

        if !exitHooked {
            ; raising proc priority makes the fade animation smoother (could be placebo)
            ProcessSetPriority("AboveNormal")
            OnExit(RestoreIcons)
            exitHooked := true
        }
        init := 1
    }

    ; Explorer can recreate the desktop windows; reacquire if needed.
    if !DllCall("IsWindow", "ptr", hIcon) || !DllCall("IsWindow", "ptr", hTarget) {
        init := 0
        return
    }

    ; Explorer switches between raised and classic rendering (HDR, slideshow, wallpaper apps).
    if (A_TickCount - lastModeCheck > 500) {
        lastModeCheck := A_TickCount
        nowRaised := false
        if (GetFadeTarget(hIcon, &nowRaised) != hTarget) {
            ReleaseTarget()
            init := 0
            return
        }
    }

    Step := 0, cls := "", ctrl := "", wnd := ""
    ; active windows and transparency
    Desk := IsDesktopActive(hDesk)
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

    if gDbgOn
        gDbgInfo := BuildDebugInfo(hDesk, hIcon, hTarget, raised, Desk, Tray, MousePos, Step, Transparent)
    if (Transparent != before)
        SetTargetAlpha(Transparent)
    ; Only sleep during active animation; skip when already at target for lower idle CPU.
    if Delay && (Transparent != before)
        Sleep(Delay)
    return

    SetTargetAlpha(alpha) {
        if raised
            return DllCall("SetLayeredWindowAttributes", "ptr", hTarget, "uint", origKey, "uchar", alpha, "uint", origFlags | 2) ; LWA_ALPHA
        try WinSetTransparent(alpha, "ahk_id " hTarget)
        catch
            return false
        return true
    }

    ReleaseTarget() {
        if !hTarget || !DllCall("IsWindow", "ptr", hTarget)
            return
        if raised
            DllCall("SetLayeredWindowAttributes", "ptr", hTarget, "uint", origKey, "uchar", origAlpha, "uint", origFlags)
        else
            try WinSetTransparent("Off", "ahk_id " hTarget)
    }

    RestoreIcons(*) {
        ReleaseTarget()
    }

}

; Raised desktop (Win11 24H2+): DefView is a layered child drawing only icons over a WorkerW
; wallpaper sibling, so fade DefView. Otherwise fade the list view (wallpaper is painted beneath it).
GetFadeTarget(hIcon, &raised) {
    raised := false
    progman  := WinExist("ahk_class Progman")
    hDefView := DllCall("GetParent", "ptr", hIcon, "ptr")
    if !progman || !hDefView || DllCall("GetParent", "ptr", hDefView, "ptr") != progman
        return hIcon
    try {
        if !(WinGetExStyle("ahk_id " hDefView) & 0x80000) ; WS_EX_LAYERED
            return hIcon
    } catch
        return hIcon
    worker := DllCall("FindWindowEx", "ptr", progman, "ptr", 0, "str", "WorkerW", "ptr", 0, "ptr")
    if !worker || !DllCall("IsWindowVisible", "ptr", worker)
        return hIcon
    raised := true
    return hDefView
}

; Undo the key-color background left on the list view by v0.9.6 test builds.
ClearLegacyKeyColor(hIcon) {
    try {
        if (SendMessage(0x1000, 0, 0, , "ahk_id " hIcon, , , , 1000) & 0xFFFFFFFF) != 0x010001 ; LVM_GETBKCOLOR
            return
        SendMessage(0x1001, 0, 0xFFFFFFFF, , "ahk_id " hIcon, , , , 1000) ; LVM_SETBKCOLOR, CLR_NONE
        SendMessage(0x1026, 0, 0xFFFFFFFF, , "ahk_id " hIcon, , , , 1000) ; LVM_SETTEXTBKCOLOR, CLR_NONE
        DllCall("InvalidateRect", "ptr", hIcon, "ptr", 0, "int", true)
    }
}

IsDesktopActive(hDesk) {
    act := WinExist("A")
    ; No foreground window at all — e.g. clicking a click-through overlay from an app
    ; that reserves desktop space. Nothing owns focus, so treat it as the desktop.
    if !act
        return true
    if (hDesk && act = hDesk)
        return true

    ; Explorer hands focus to different desktop hosts (Progman vs. one of several
    ; WorkerW windows) depending on monitor and virtual-desktop state, so a single
    ; cached handle is not enough — match the active window's class instead.
    cls := ""
    try cls := WinGetClass("ahk_id " act)
    return (cls = "Progman" || cls = "WorkerW"
         || cls = "SHELLDLL_DefView" || cls = "SysListView32")
}

BuildDebugInfo(hDesk, hIcon, hTarget, raised, Desk, Tray, MousePos, Step, Transparent) {
    act := WinExist("A"), aCls := "", aTtl := "", aProc := ""
    try {
        aCls  := WinGetClass("ahk_id " act)
        aTtl  := WinGetTitle("ahk_id " act)
        aProc := WinGetProcessName("ahk_id " act)
    }

    mCls := "", mCtrl := "", mId := 0, mProc := "", mRoot := 0, mRootCls := ""
    try {
        MouseGetPos(&mx, &my, &mId, &mCtrl)
        mCls  := WinGetClass("ahk_id " mId)
        mProc := WinGetProcessName("ahk_id " mId)
        mRoot := DllCall("GetAncestor", "ptr", mId, "uint", 2, "ptr")
        mRootCls := WinGetClass("ahk_id " mRoot)
    }

    return "Active hwnd:`t" act "`n"
         . "Active class:`t" aCls "`n"
         . "Active title:`t" aTtl "`n"
         . "Active proc:`t" aProc "`n"
         . "`n"
         . "hDesk (cached):`t" hDesk "`n"
         . "hIcon (listview):`t" hIcon "`n"
         . "Mode:`t`t" (raised ? "raised (fade DefView)" : "classic (fade listview)") "`n"
         . "Fade target:`t" hTarget "`n"
         . DesktopTreeInfo(hIcon)
         . "`n"
         . "Mouse hwnd:`t" mId "`n"
         . "Mouse class:`t" mCls "`n"
         . "Mouse proc:`t" mProc "`n"
         . "Mouse ctrl:`t" mCtrl "`n"
         . "Mouse root:`t" mRoot " (" mRootCls ")`n"
         . "`n"
         . "Desk:`t" (Desk ? "1" : "0") "   Tray:`t" (Tray ? "1" : "0") "`n"
         . "MousePos:`t" MousePos "`n"
         . "Step:`t" Step "   Alpha:`t" Transparent
}

DesktopTreeInfo(hIcon) {
    progman := WinExist("ahk_class Progman")
    hDefView := DllCall("GetParent", "ptr", hIcon, "ptr")
    worker := progman ? DllCall("FindWindowEx", "ptr", progman, "ptr", 0, "str", "WorkerW", "ptr", 0, "ptr") : 0
    pEx := "", dEx := "", lEx := ""
    try pEx := Format("0x{:08X}", WinGetExStyle("ahk_id " progman))
    try dEx := Format("0x{:08X}", WinGetExStyle("ahk_id " hDefView))
    try lEx := Format("0x{:08X}", WinGetExStyle("ahk_id " hIcon))
    return "Progman:`t" progman "  ex " pEx "`n"
         . "DefView:`t" hDefView "  ex " dEx "`n"
         . "ListView ex:`t" lEx "`n"
         . "WorkerW (Progman child):`t" worker (worker ? (DllCall("IsWindowVisible", "ptr", worker) ? " visible" : " hidden") : "") "`n"
}

ShowDebugGui(*) {
    global gDbgOn, gDbgInfo
    static dg := 0, txt := 0

    if dg {
        try dg.Show()
        return
    }

    dg := Gui("+AlwaysOnTop +Resize", "GhostDesktop — Debug")
    dg.SetFont("s9", "Consolas")
    txt := dg.Add("Text", "w460 r28", "collecting…")
    dg.OnEvent("Close", Close)
    dg.Show("AutoSize")

    gDbgOn := true
    SetTimer(Refresh, 100)

    Refresh() {
        if !dg
            return
        try txt.Value := gDbgInfo
    }

    Close(*) {
        global gDbgOn
        gDbgOn := false
        SetTimer(Refresh, 0)
        try dg.Destroy()
        dg := 0
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
          "GhostDesktop  v0.9.6`n`n"
        . "Fades desktop icons based on window focus or mouse position.")
    ag.Add("Link", "w400", 
          'Author:   Paul R. Charovkine (krypdoh)`n'
        . 'License:  <a href="https://www.gnu.org/licenses/agpl-3.0.html#license-text">AGPL-3.0</a> `n'
        . 'Date:      2026-09-29`n'
        . 'Website:  <a href="https://krypdoh.github.io/GhostDesktop/">krypdoh.github.io/GhostDesktop/</a> `n`n'
        . 'If you find GhostDesktop useful please consider <a href="https://www.paypal.com/paypalme/paypaulc">donating</a>.`n`n'
        . "Settings stored in:`n" gIniFile)
    ag.Add("Button", "w80 Default", "OK").OnEvent("Click", (*) => ag.Destroy())
    ag.OnEvent("Close", (*) => ag.Destroy())
    ag.Show("AutoSize")
}
