; ============================================================
;  Currency Counter Module  –  Exile_UI framework integration
;  Based on Lailloken's framework (stash-ninja / map-tracker structure)
;
;  INI STRUCTURE  (ini\<version>\currency-counter.ini)
;  ─────────────────────────────────────────────────────────
;  [settings]
;  ssf mode          = 0/1
;  font-size         = N
;  active            = <session_id>
;  sessions          = {"20250515142300": "Chaos Spam", ...}
;  display-currency  = chaos|divine|exalt
;  bar-x             = N    ; saved bar position (monitor-relative)
;  bar-y             = N
;
;  [session_<id>]
;  name = "Chaos Spam"
;  img  = "img\sessions\chaos_spam.png"
;
;  [session_<id>_currencies]
;  Chaos Orb = {"count":47,"price":1.5,"price_currency":"chaos","price_updated":20250515142300}
;
;  NOTE: price is stored as a number (e.g. 1.5), price_updated as A_Now (YYYYMMDDHHmmss numeric).
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
;
;  7. In hotkeys.ahk, add after the currency-counter bar #If block:
;
;   ; currency counter – open/close table view on bar click
;   #If settings.features.currency_counter && vars.hwnd.currency_counter.main && (vars.general.wMouse = vars.hwnd.currency_counter.main)
;   LButton::CurrencyCounter_BarClick()
;
;   ; currency counter – table view click handler
;   #If settings.features.currency_counter && vars.hwnd.currency_counter_table.main && (vars.general.wMouse = vars.hwnd.currency_counter_table.main)
;   LButton::CurrencyCounter_TableClick(vars.general.cMouse, 1)
;   RButton::CurrencyCounter_TableClick(vars.general.cMouse, 2)
;
;  8. In hotkeys.ahk Hotkeys_ESC(), BEFORE the stash.main line:
;       Else If vars.hwnd.currency_counter_table.main && WinExist("ahk_id " vars.hwnd.currency_counter_table.main)
;           CurrencyCounter_TableClose()
;
;  9. In omni-key.ahk (radial menu builder), inside the section that adds
;     feature buttons, add:
;       If settings.features.currency_counter
;           Omni_AddRadialButton("currency_counter", "CurrencyCounter_TableToggle()", vars.pics.currency_counter.icon)
; ============================================================

; ──────────────────────────────────────────────────────────────
;  Init
; ──────────────────────────────────────────────────────────────
Init_currency_counter()
{
    local
    global vars, settings, Json

    If !IsObject(Json)
        Json := new JSON()

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

    raw := ini.settings["sessions"]
    settings.currency_counter.sessions := IsObject(check := Json.Load(raw)) ? check : {}
    settings.currency_counter.active := !Blank(check := ini.settings["active"]) ? check : 0

    LLK_FontDimensions(settings.currency_counter.fSize, height, width)
    settings.currency_counter.fHeight := height
    settings.currency_counter.fWidth := width

    ; Runtime state
    vars.currency_counter := {"picked": 0, "name": "", "last_used": "", "currencies": {}, "session_name": "", "session_img": "", "drop_on_shift_release": 0, "shift_timer": 0}
    vars.hwnd.currency_counter := {"main": "", "drag": ""}
    vars.hwnd.currency_counter_table := {"main": ""}

    ; Cache icon image (placeholder path – replace with real asset)
    If FileExist("img\GUI\currency\blessed.png")
        vars.pics.currency_counter := {"icon": LLK_ImageCache("img\GUI\currency\blessed.png")}
    Else 
        vars.pics.currency_counter := {"icon": ""}
    If !Blank(settings.currency_counter.active)
    {
        CurrencyCounter_SetActive(settings.currency_counter.active)
    }
    Else
        CurrencyCounter_NewSession()

    CurrencyCounter_DrawBar()
}

; ──────────────────────────────────────────────────────────────
;  Session management
; ──────────────────────────────────────────────────────────────
CurrencyCounter_LoadSession(id)
{
    local
    global vars, settings, Json

    If !IsObject(Json)
        Json := new JSON()

    ini := IniBatchRead("ini" vars.poe_version "\currency-counter.ini")

    raw_section := ini["session_" id "_currencies"]
    vars.currency_counter.currencies := {}

    If IsObject(raw_section)
        For currency_name, raw_val in raw_section
        {
            entry := Json.Load(raw_val)
            If IsObject(entry)
                vars.currency_counter.currencies[currency_name] := entry

        }
    Return 1
}

CurrencyCounter_NewSession()
{
    local
    global vars, settings

    id := A_Now
    name := "New Session"
    settings.currency_counter.sessions[id] := { name : name , img : ""}
    CurrencyCounter_SaveIndex()
    CurrencyCounter_SetActive(id)
}

CurrencyCounter_SetActive(id)
{
    local
    global vars, settings

    If Blank(id)
    {
        LLK_Overlay("CRITICAL ERROR WITH CURRENCY COUNTER RESTART MODULE", 5,,"red")
        Return 0
    }

    CurrencyCounter_LoadSession(id)
    
    settings.currency_counter.active := id
    IniWrite, % id, % "ini" vars.poe_version "\currency-counter.ini", settings, active
    vars.currency_counter.picked := 0, vars.currency_counter.name := ""
    CurrencyCounter_DrawBar()
    Return 1
}

CurrencyCounter_DeleteSession(id)
{
    local
    global vars, settings

    ; Remove from index
    settings.currency_counter.sessions.Delete(id)
    CurrencyCounter_SaveIndex()

    ; Remove INI sections
    IniDelete, % "ini" vars.poe_version "\currency-counter.ini", % "session_" id
    IniDelete, % "ini" vars.poe_version "\currency-counter.ini", % "session_" id "_currencies"

    ; Switch to another session or create new one
    If settings.currency_counter.sessions.Count()
        For next_id in settings.currency_counter.sessions
        {
            CurrencyCounter_SetActive(next_id)
            Break
        }
    Else
        CurrencyCounter_NewSession()
}

CurrencyCounter_SaveIndex()
{
    local
    global vars, settings, Json

    If !IsObject(Json)
        Json := new JSON()

    IniWrite, % Json.Dump(settings.currency_counter.sessions), % "ini" vars.poe_version "\currency-counter.ini", settings, sessions
}

CurrencyCounter_SaveCurrency(currency_name)
{
    local
    global vars, settings, Json

    If !IsObject(Json)
        Json := new JSON()

    
    id := settings.currency_counter.active
    If Blank(id) || Blank(currency_name)
        Return

    entry := vars.currency_counter.currencies[currency_name]
    If !IsObject(entry)
        Return

    IniWrite, % Json.Dump(entry), % "ini" vars.poe_version "\currency-counter.ini", % "session_" id "_currencies", % currency_name
}

; ──────────────────────────────────────────────────────────────
;  Table GUI  –  main popup panel
; ──────────────────────────────────────────────────────────────
CurrencyCounter_TableToggle()
{
    local
    global vars, settings

    If vars.hwnd.cc_logs.main && WinExist("ahk_id " vars.hwnd.cc_logs.main)
        if(!Blank(hwnd_old := vars.hwnd.cc_logs.main))
            LLK_Overlay(hwnd_old, "destroy")
        Else
            CurrencyCounter_Logs()
}

; ──────────────────────────────────────────────────────────────
;  Bar click → open/close table
; ──────────────────────────────────────────────────────────────
CurrencyCounter_BarClick()
{
    local
    global vars, settings

    ; Check if click is on the drag handle (top-left area) – if so, don't open table
    check := LLK_HasVal(vars.hwnd.currency_counter, vars.general.cMouse)
    If (check = "drag")
        Return ; let CurrencyCounter_Click() handle dragging

    LLK_ToolTip("BARclicked",1.5)
    CurrencyCounter_TableToggle()
}

; ──────────────────────────────────────────────────────────────
;  RClick / LClick / Esc  (unchanged from original)
; ──────────────────────────────────────────────────────────────
CurrencyCounter_RClick()
{
    local
    global vars, settings

    If vars.currency_counter.picked
    {
        vars.currency_counter.picked := 0
        vars.currency_counter.name := ""
        CurrencyCounter_DrawBar()
        Return
    }

    ; Pick currency from item under cursor
    name := CurrencyCounter_ReadItemName()
    If Blank(name)
        Return
    vars.currency_counter.picked := 1
    vars.currency_counter.name := name
    If !IsObject(vars.currency_counter.currencies[name])
        vars.currency_counter.currencies[name] := {"count": 0, "price": 0.0, "price_currency": "chaos", "price_updated": 0}
    CurrencyCounter_DrawBar()
}

CurrencyCounter_LClick()
{
    local
    global vars, settings

    If !vars.currency_counter.picked
        Return

    ; --- NEW: Verify cursor is over a valid item using clipboard ---
    Clipboard := ""
    SendInput, ^c ; copy item under cursor
    ClipWait, 0.2
    if ErrorLevel
        return ; clipboard empty – no item, do nothing

    ; Check if clipboard contains a valid item (at least "Rarity:" line)
    if !RegExMatch(Clipboard, "i)Rarity:")
        return ; not an item – do not increment

    ; --- End of verification ---

    if(Blank(vars.currency_counter.currencies[vars.currency_counter.name]))
    {
        vars.currency_counter.currencies[vars.currency_counter.name] := {"count": 0, "price": 0.0, "price_currency": "chaos", "price_updated": 0}
    }
    vars.currency_counter.currencies[vars.currency_counter.name].count += 1
    vars.currency_counter.last_used := vars.currency_counter.name

    CurrencyCounter_SaveCurrency(vars.currency_counter.name)

    ; Watch for shift-drop
    If GetKeyState("Shift", "P")
    {
        vars.currency_counter.drop_on_shift_release := 1
        If !vars.currency_counter.shift_timer
        {
            vars.currency_counter.shift_timer := 1
            SetTimer, CurrencyCounter_CheckShiftRelease, 50
        }
    }
    Else
    {
        vars.currency_counter.picked := 0
        vars.currency_counter.name := ""
    }

    CurrencyCounter_DrawBar()
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
    If !vars.currency_counter.drop_on_shift_release
    {
        If vars.currency_counter.shift_timer
        {
            vars.currency_counter.shift_timer := 0
            SetTimer, CurrencyCounter_CheckShiftRelease, Off
        }
        Return
    }
    If !GetKeyState("Shift", "P")
    {
        vars.currency_counter.picked := 0, vars.currency_counter.name := ""
        vars.currency_counter.drop_on_shift_release := 0
        CurrencyCounter_DrawBar()
        vars.currency_counter.shift_timer := 0
        SetTimer, CurrencyCounter_CheckShiftRelease, Off
    }
}

; ──────────────────────────────────────────────────────────────
;  Process log lines
; ──────────────────────────────────────────────────────────────
CurrencyCounter_ProcessLog(line)
{
    local
    global vars, settings

    If RegExMatch(line, "i)(.+?) in your inventory has been consumed", m)
    {
        currency_name := Trim(m1)
        If !IsObject(vars.currency_counter.currencies[currency_name])
            vars.currency_counter.currencies[currency_name] := {"count": 0, "price": 0.0, "price_currency": "chaos", "price_updated": 0}
        vars.currency_counter.currencies[currency_name].count += 1
        CurrencyCounter_SaveCurrency(currency_name)
        CurrencyCounter_DrawBar()
    }
    Else If InStr(line, "Failed to apply item")
    {
        currency_name := vars.currency_counter.last_used
        If IsObject(vars.currency_counter.currencies[currency_name])
        {
            If vars.currency_counter.currencies[currency_name].count > 0
                vars.currency_counter.currencies[currency_name].count -= 1
            CurrencyCounter_SaveCurrency(currency_name)
            CurrencyCounter_DrawBar()
        }
    }
}

; ──────────────────────────────────────────────────────────────
;  Drag / click handler for the bar overlay
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
        If (hotkey = 2)
        {
            settings.currency_counter.bar_x := "", settings.currency_counter.bar_y := ""
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
            settings.currency_counter.bar_x := xPos, settings.currency_counter.bar_y := yPos
            IniWrite, % xPos, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-x
            IniWrite, % yPos, % "ini" vars.poe_version "\currency-counter.ini", settings, bar-y
            CurrencyCounter_DrawBar()
        }
        Return
    }
}

; ──────────────────────────────────────────────────────────────
;  Bar overlay  (unchanged structure, keeps existing behaviour)
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
    dragSz := Floor(fW * 0.6)

    held_name := vars.currency_counter.picked ? vars.currency_counter.name : ""

    Gui, %GUI_name%: New, % "-Caption -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDhwnd_bar"
    Gui, %GUI_name%: Color, Black
    Gui, %GUI_name%: Margin, 0, 0
    Gui, %GUI_name%: Font, % "s" fSize " cWhite", % vars.system.font

    hwnd_old := IsObject(vars.hwnd.currency_counter) ? vars.hwnd.currency_counter.main : ""
    vars.hwnd.currency_counter := {"main": hwnd_bar}

    Gui, %GUI_name%: Add, Progress, % "x0 y0 w" dragSz " h" dragSz " BackgroundWhite HWNDhwnd_drag", 0
    vars.hwnd.currency_counter.drag := hwnd_drag

    Gui, %GUI_name%: Add, Text, % "x0 y0 w" barW " h" barH " Section 0x200 BackgroundTrans Center HWNDhwnd_label" (vars.currency_counter.picked ? "" : " c606060"), % " " held_name " "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled BackgroundBlack", 0

    Gui, %GUI_name%: Show, % "NA x10000 y10000"
    WinGetPos,,, w, h, % "ahk_id " hwnd_bar

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

; ──────────────────────────────────────────────────────────────
;  Placeholder: read item name from game (integrate with your
;  existing item-name detection / clipboard method)
; ──────────────────────────────────────────────────────────────
CurrencyCounter_ReadItemName()
{
    Clipboard := ""
    SendInput, ^c
    ClipWait, 0.2
    if ErrorLevel
        return
    clip := Clipboard
    name := ""
    if RegExMatch(clip, "i)Rarity: Currency\r?\n(.+?)(\r?\n|$)", m)
        name := Trim(m1)
    Return name
}
