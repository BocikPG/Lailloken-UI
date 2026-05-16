; ============================================================
;  Currency Counter Module  –  Exile_UI framework integration
;  Based on Lailloken's framework (stash-ninja / map-tracker structure)
;
;  INI STRUCTURE  (ini\<version>\currency-counter.ini)
;  ─────────────────────────────────────────────────────────
;  [settings]
;  ssf mode   = 0/1
;  font-size  = N
;  active     = <session_id>
;  sessions   = {"20250515142300": "Chaos Spam", ...}
;  bar-x      = N    ; saved bar position (monitor-relative)
;  bar-y      = N
;
;  [session_<id>]
;  name = "Chaos Spam"
;  img  = "img\sessions\chaos_spam.png"
;
;  [session_<id>_currencies]
;  Chaos Orb = {"count":47,"price":1,"price_currency":"chaos","price_updated":"20250515142300"}
;
;  HOW TO INTEGRATE
;  ─────────────────────────────────────────────────────────
;  1. #Include this file in Exile_UI.ahk alongside other modules.
;
;  2. In Exile_UI.ahk Init_general() add:
;       settings.features.currency_counter := !Blank(check := ini.features["enable currency-counter"]) ? check : 0
;
;  3. In Exile_UI.ahk startup sequence (around line 79) add:
;       Init_currency_counter(), LLK_Log("initialized currency-counter settings")
;
;  4. In settings_menu.ahk:
;     a) Add "currency-counter" to both vars.settings.sections arrays.
;     b) Add "currency-counter": "currency_counter" to feature_check.
;     c) Add to Settings_menu2() Switch block:
;          Case "currency-counter":
;              Settings_currency_counter()
;     d) Append Settings_currency_counter() and Settings_currency_counter2()
;        to the bottom of settings_menu.ahk (see bottom of this file).
;
;  5. In hotkeys.ahk Hotkeys_ESC(), BEFORE the stash.main line:
;       Else If vars.currency_counter.picked
;           CurrencyCounter_Esc()
;
;  6. In hotkeys.ahk, add after the stash #If blocks:
;
;   ; currency counter – pick currency via right-click
;   #If settings.features.currency_counter && (vars.general.wMouse = vars.hwnd.poe_client) && !vars.currency_counter.picked
;   ~RButton::CurrencyCounter_RClick()
;
;   ; currency counter – count or re-pick while holding a currency
;   #If settings.features.currency_counter && (vars.general.wMouse = vars.hwnd.poe_client) && vars.currency_counter.picked
;   ~RButton::CurrencyCounter_RClick()
;   ~LButton::CurrencyCounter_LClick()
;
;   ; currency counter bar – click handler (drag handle)
;   #If vars.hwnd.currency_counter.main && (vars.general.wMouse = vars.hwnd.currency_counter.main)
;   LButton::CurrencyCounter_Click(1)
;   RButton::CurrencyCounter_Click(2)
; ============================================================

; ──────────────────────────────────────────────────────────────
;  Init
; ──────────────────────────────────────────────────────────────
Init_currency_counter()
{
    local
    global vars, settings

    If !FileExist("ini" vars.poe_version "\currency-counter.ini")
        IniWrite, % "", % "ini" vars.poe_version "\currency-counter.ini", settings

    If IsObject(settings.currency_counter)
        Return

    ini := IniBatchRead("ini" vars.poe_version "\currency-counter.ini")

    settings.currency_counter := {}
    settings.currency_counter.ssf := !Blank(check := ini.settings["ssf mode"]) ? check : 0
    settings.currency_counter.fSize := !Blank(check := ini.settings["font-size"]) ? check : settings.general.fSize

    ; Saved bar position (monitor-relative, empty = use default)
    settings.currency_counter.bar_x := !Blank(check := ini.settings["bar-x"]) ? check : ""
    settings.currency_counter.bar_y := !Blank(check := ini.settings["bar-y"]) ? check : ""

    ; Session index  { id: name, ... }
    raw := ini.settings["sessions"]
    settings.currency_counter.sessions := IsObject(check := Json.Load(raw)) ? check : {}
    settings.currency_counter.active := !Blank(check := ini.settings["active"]) ? check : ""

    LLK_FontDimensions(settings.currency_counter.fSize, height, width)
    settings.currency_counter.fHeight := height
    settings.currency_counter.fWidth  := width

    ; Runtime state
    vars.currency_counter := {"picked": 0, "name": "", "currencies": {}, "session_name": "", "session_img": "", "drop_on_shift_release": 0, "shift_timer": 0}
    vars.hwnd.currency_counter := {"main": "", "drag": ""}

    if settings.currency_counter.active
    {
        if !CurrencyCounter_SessionExists(settings.currency_counter.active)
            settings.currency_counter.active := ""   ; invalid session, will create new
    }
    if !settings.currency_counter.active
    {
        ; Create a new default session
        CurrencyCounter_NewSession("Session " . A_Now, "")
    }
    else
    {
        ; Load the existing active session
        CurrencyCounter_LoadSession(settings.currency_counter.active)
    }

    CurrencyCounter_DrawBar()
}

; ──────────────────────────────────────────────────────────────
;  Session management
; ──────────────────────────────────────────────────────────────
CurrencyCounter_LoadSession(id)
{
    local
    global vars, settings

    ini := IniBatchRead("ini" vars.poe_version "\currency-counter.ini")
    if !ini.HasKey("session_" id)
        return 0

    raw_section := ini["session_" id "_currencies"]
    vars.currency_counter.currencies := {}
    vars.currency_counter.session_name := ini["session_" id]["name"]
    vars.currency_counter.session_img  := ini["session_" id]["img"]

    if IsObject(raw_section)
        for currency_name, raw_val in raw_section
        {
            entry := Json.Load(raw_val)
            if IsObject(entry)
                vars.currency_counter.currencies[currency_name] := entry
        }
    return 1
}

CurrencyCounter_NewSession(name, img := "")
{
    local
    global vars, settings

    id := A_Now
    settings.currency_counter.sessions[id] := name
    CurrencyCounter_SaveIndex()
    IniWrite, % name, % "ini" vars.poe_version "\currency-counter.ini", % "session_" id, name
    IniWrite, % img, % "ini" vars.poe_version "\currency-counter.ini", % "session_" id, img
    CurrencyCounter_SetActive(id)
}

CurrencyCounter_SetActive(id)
{
    local
    global vars, settings

    ; Clear active session (id empty)
    if !id
    {
        settings.currency_counter.active := ""
        IniWrite, % "", % "ini" vars.poe_version "\currency-counter.ini", settings, active
        vars.currency_counter.picked := 0
        vars.currency_counter.name := ""
        vars.currency_counter.currencies := {}
        vars.currency_counter.session_name := ""
        vars.currency_counter.session_img := ""
        CurrencyCounter_DrawBar()
        return 1
    }

    ; Try to load the session
    if !CurrencyCounter_LoadSession(id)
        return 0   ; session does not exist – do not change active session

    ; Success: update active session
    settings.currency_counter.active := id
    IniWrite, % id, % "ini" vars.poe_version "\currency-counter.ini", settings, active
    vars.currency_counter.picked := 0
    vars.currency_counter.name := ""
    CurrencyCounter_DrawBar()
    return 1
}

CurrencyCounter_SessionExists(id)
{
    global vars
    IniRead, name, % "ini" vars.poe_version "\currency-counter.ini", session_%id%, name, % "NONEXISTENT"
    return (name != "NONEXISTENT")
}

CurrencyCounter_SaveIndex()
{
    local
    global vars, settings
    IniWrite, % """" Json.Dump(settings.currency_counter.sessions) """", % "ini" vars.poe_version "\currency-counter.ini", settings, sessions
}

CurrencyCounter_SaveCurrency(currency_name)
{
    local
    global vars, settings, Json

    ; Ensure JSON library is available
    if !IsObject(Json)
        Json := new JSON()

    id := settings.currency_counter.active
    if !id
        return
    if !CurrencyCounter_SessionExists(id)
        return
    if !currency_name
        return

    entry := vars.currency_counter.currencies[currency_name]
    if !IsObject(entry)
        return

    ; Try JSON serialization
    json_str := Json.Dump(entry)
    
    ; Fallback: manual JSON building if library fails
    if !json_str
    {
        ; Ensure numeric values are stored without quotes
        LLK_ToolTip("Currency Counter: JSON ERROR", 1.5,,, "red")
        return
    }

    IniWrite, % """" json_str """", % "ini" vars.poe_version "\currency-counter.ini", % "session_" id "_currencies", % currency_name
}

CurrencyCounter_SetPrice(currency_name, price, price_currency)
{
    local
    global vars, settings

    If !IsObject(vars.currency_counter.currencies[currency_name])
        vars.currency_counter.currencies[currency_name] := {"count": 0, "price": 0, "price_currency": 0, "price_updated": 0}

    vars.currency_counter.currencies[currency_name].price := price
    vars.currency_counter.currencies[currency_name].price_currency := price_currency
    vars.currency_counter.currencies[currency_name].price_updated := A_Now
    CurrencyCounter_SaveCurrency(currency_name)
}

; ──────────────────────────────────────────────────────────────
;  Hotkey handlers
; ──────────────────────────────────────────────────────────────
CurrencyCounter_HandleClick()
{
    local
    global vars, settings

    if (A_ThisHotkey = "*RButton")
    {
        if vars.currency_counter.picked
        {
            vars.currency_counter.picked := 0
            vars.currency_counter.name := ""
            CurrencyCounter_DrawBar()
            return
        }

        Sleep, 50
        Clipboard := ""
        SendInput, ^c
        ClipWait, 0.3
        if ErrorLevel
            return

        clip := Clipboard
        name := ""
        if RegExMatch(clip, "i)Rarity: Currency\r?\n(.+?)(\r?\n|$)", m)
            name := Trim(m1)

        if (name = "")
            return

        vars.currency_counter.picked := 1
        vars.currency_counter.name   := name
        CurrencyCounter_DrawBar()
    }
    else if (A_ThisHotkey = "*~LButton")
    {
        name := vars.currency_counter.name
        if !name
            return   ; No currency picked – ignore

        ; Ensure the currency entry exists
        if !IsObject(vars.currency_counter.currencies[name])
        {
            vars.currency_counter.currencies[name] := {"count": 0, "price": "", "price_currency": "", "price_updated": ""}
        }

        ; Increment count
        vars.currency_counter.currencies[name].count += 1
        CurrencyCounter_SaveCurrency(name)

        if GetKeyState("Shift", "P")
        {
            vars.currency_counter.drop_on_shift_release := 1
            if !vars.currency_counter.shift_timer
            {
                vars.currency_counter.shift_timer := 1
                SetTimer, CurrencyCounter_CheckShiftRelease, 50
            }
        }
        else
        {
            vars.currency_counter.picked := 0
            vars.currency_counter.name := ""
        }

        CurrencyCounter_DrawBar()
    }
}

CurrencyCounter_Esc()
{
    local
    global vars, settings

    vars.currency_counter.picked := 0
    vars.currency_counter.name := ""
    CurrencyCounter_DrawBar()
}

CurrencyCounter_CheckShiftRelease()
{
    global vars
    if !vars.currency_counter.drop_on_shift_release
    {
        ; No pending drop, stop timer
        if vars.currency_counter.shift_timer
        {
            vars.currency_counter.shift_timer := 0
            SetTimer, CurrencyCounter_CheckShiftRelease, Off
        }
        return
    }
    ; If Shift is physically up (not pressed)
    if !GetKeyState("Shift", "P")
    {
        ; Drop the currency
        vars.currency_counter.picked := 0
        vars.currency_counter.name := ""
        vars.currency_counter.drop_on_shift_release := 0
        CurrencyCounter_DrawBar()
        ; Stop timer
        vars.currency_counter.shift_timer := 0
        SetTimer, CurrencyCounter_CheckShiftRelease, Off
    }
}


; ──────────────────────────────────────────────────────────────
;  Click handler  –  wired via #If in hotkeys.ahk
;  Mirrors Maptracker_Click() pattern exactly.
; ──────────────────────────────────────────────────────────────
CurrencyCounter_Click(hotkey)
{
    local
    global vars, settings
    static width, height

    check := LLK_HasVal(vars.hwnd.currency_counter, vars.general.cMouse)
    If !check
        Return

    If (check = "drag")
    {
        If (hotkey = 2) ; right-click drag handle = reset to default position
        {
            settings.currency_counter.bar_x := ""
            settings.currency_counter.bar_y := ""
            IniDelete, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-x
            IniDelete, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-y
            CurrencyCounter_DrawBar()
            Return
        }

        start := A_TickCount
        While GetKeyState("LButton", "P")
        {
            If (A_TickCount >= start + 250)
            {
                If !width
                {
                    WinGetPos,,, width, height, % "ahk_id " vars.hwnd.currency_counter.main
                    vars.general.drag := 1, gui_name := Gui_Name(vars.hwnd.currency_counter.main)
                }
                LLK_Drag(width, height, xPos, yPos, 1, gui_name, 1)
                Sleep, 1
            }
        }

        vars.general.drag := 0, width := "", height := ""

        If !Blank(xPos) || !Blank(yPos)
        {
            ; xPos/yPos are already monitor-relative and clamped by LLK_Drag (top_left=1)
            settings.currency_counter.bar_x := xPos
            settings.currency_counter.bar_y := yPos
            IniWrite, % xPos, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-x
            IniWrite, % yPos, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-y
            CurrencyCounter_DrawBar()
        }
        Return
    }
}

; ──────────────────────────────────────────────────────────────
;  Bar overlay  –  fixed 200x40 box, bottom of screen
;  Solid black background + border (map-tracker style).
;  Drag handle (white Progress) top-left, always visible.
; ──────────────────────────────────────────────────────────────
CurrencyCounter_DrawBar()
{
    local
    global vars, settings
    static toggle := 0, wait

    If wait
        Return
    wait := 1

    If !settings.features.currency_counter
    {
        LLK_Overlay(vars.hwnd.currency_counter.main, "destroy")
        vars.hwnd.currency_counter := {"main": "", "drag": ""}
        wait := 0
        Return
    }

    toggle := !toggle
    GUI_name := "cc_bar" toggle
    fSize := settings.currency_counter.fSize
    fH := settings.currency_counter.fHeight
    fW := settings.currency_counter.fWidth
    barW := 200
    barH := 40
    dragSz := Floor(fW * 0.6) ; matches map tracker proportions

    held_name := vars.currency_counter.picked ? vars.currency_counter.name : ""

    ; ── Build GUI (map-tracker style: solid black, +Border) ───
    Gui, %GUI_name%: New, % "-Caption -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDhwnd_bar"
    Gui, %GUI_name%: Color, Black
    Gui, %GUI_name%: Margin, 0, 0
    Gui, %GUI_name%: Font, % "s" fSize " cWhite", % vars.system.font

    hwnd_old := IsObject(vars.hwnd.currency_counter) ? vars.hwnd.currency_counter.main : ""
    vars.hwnd.currency_counter := {"main": hwnd_bar}

    ; Drag handle – white Progress, top-left (same as map tracker)
    Gui, %GUI_name%: Add, Progress, % "x0 y0 w" dragSz " h" dragSz " BackgroundWhite HWNDhwnd_drag", 0
    vars.hwnd.currency_counter.drag := hwnd_drag

    ; Currency name label on top of full bar area
    Gui, %GUI_name%: Add, Text, % "x0 y0 w" barW " h" barH " Section 0x200 BackgroundTrans Center HWNDhwnd_label" (vars.currency_counter.picked ? "" : " c606060"), % " " held_name " "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled BackgroundBlack", 0

    ; ── Show offscreen first to get real dimensions ────────────
    Gui, %GUI_name%: Show, % "NA x10000 y10000"
    WinGetPos,,, w, h, % "ahk_id " hwnd_bar

    ; ── Compute position ──────────────────────────────────────
    ; Default: 2/3 from left edge of client, 15px above client bottom
    ; Stored as monitor-relative (same convention as map tracker)
    defaultX := vars.client.x - vars.monitor.x + Floor(vars.client.w * (2/3)) - Floor(w / 2)
    defaultY := vars.client.y - vars.monitor.y + vars.client.h - h - 15

    xPos := !Blank(settings.currency_counter.bar_x) ? settings.currency_counter.bar_x : defaultX
    yPos := !Blank(settings.currency_counter.bar_y) ? settings.currency_counter.bar_y : defaultY

    Gui, %GUI_name%: Show, % "NA x" vars.monitor.x + xPos " y" vars.monitor.y + yPos
    LLK_Overlay(hwnd_bar, "show",, GUI_name)
    If hwnd_old
        LLK_Overlay(hwnd_old, "destroy")
    wait := 0
}
