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

    raw := ini.settings["sessions"]
    settings.currency_counter.sessions := IsObject(check := Json.Load(raw)) ? check : {}
    settings.currency_counter.active := !Blank(check := ini.settings["active"]) ? check : ""

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
    Else vars.pics.currency_counter := {"icon": ""}

        If settings.currency_counter.active
        {
            If !CurrencyCounter_SessionExists(settings.currency_counter.active)
                settings.currency_counter.active := ""
        }
    If !settings.currency_counter.active
        CurrencyCounter_NewSession("Session " A_Now, "")
    Else
        CurrencyCounter_LoadSession(settings.currency_counter.active)

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
    If !ini.HasKey("session_" id)
        Return 0

    raw_section := ini["session_" id "_currencies"]
    vars.currency_counter.currencies := {}
    vars.currency_counter.session_name := ini["session_" id]["name"]
    vars.currency_counter.session_img := ini["session_" id]["img"]

    If IsObject(raw_section)
        For currency_name, raw_val in raw_section
        {
            entry := Json.Load(raw_val)
            If IsObject(entry)
                vars.currency_counter.currencies[currency_name] := entry
        }
    Return 1
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

    If !id
    {
        settings.currency_counter.active := ""
        IniWrite, % "", % "ini" vars.poe_version "\currency-counter.ini", settings, active
        vars.currency_counter.picked := 0, vars.currency_counter.name := ""
        vars.currency_counter.currencies := {}, vars.currency_counter.session_name := "", vars.currency_counter.session_img := ""
        CurrencyCounter_DrawBar()
        Return 1
    }
    If !CurrencyCounter_LoadSession(id)
        Return 0
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
        CurrencyCounter_NewSession("Session " A_Now, "")
}

CurrencyCounter_SessionExists(id)
{
    global vars
    IniRead, name, % "ini" vars.poe_version "\currency-counter.ini", session_%id%, name, % "NONEXISTENT"
    Return (name != "NONEXISTENT")
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

    If !IsObject(Json)
        Json := new JSON()

    id := settings.currency_counter.active
    If !id || !CurrencyCounter_SessionExists(id) || !currency_name
        Return

    entry := vars.currency_counter.currencies[currency_name]
    If !IsObject(entry)
        Return

    IniWrite, % """" Json.Dump(entry) """", % "ini" vars.poe_version "\currency-counter.ini", % "session_" id "_currencies", % currency_name
}

; ──────────────────────────────────────────────────────────────
;  Price helpers
; ──────────────────────────────────────────────────────────────
CurrencyCounter_PriceAgeHours(ts)
{
    local
    ; ts is A_Now style: YYYYMMDDHHmmss  (14-digit number)
    If !ts || !IsNumber(ts)
        Return 9999
    t := ts
    EnvSub, t, % t, Hours ; AHK date math: subtract ts from itself = 0... use A_Now
    ; Correct approach:
    now := A_Now
    EnvSub, now, % ts, Hours
    Return Abs(now)
}

CurrencyCounter_PriceColor(ts)
{
    local
    h := CurrencyCounter_PriceAgeHours(ts)
    If (h >= 12)
        Return "CC3333"
    If (h >= 6)
    {
        t := (h - 6) / 6 ; 0..1
        r := Round(180 + 75 * t), g := Round(170 * (1 - t))
        Return Format("{:02X}{:02X}00", r, g)
    }
    Return "4A9E4A"
}

; ──────────────────────────────────────────────────────────────
;  Currency conversion
; ──────────────────────────────────────────────────────────────
CurrencyCounter_ToChaos(price, price_currency)
{
    local
    global settings
    If (price = "" || price = 0)
        Return 0
    ; Use economy rates from vars if available, else fallback to placeholders
    ; You can replace these with real rates via settings.exchange.chaos_div etc.
    rate := (price_currency = "divine") ? (IsNumber(settings.exchange.chaos_div) ? settings.exchange.chaos_div : 250)
        : (price_currency = "exalt") ? (IsNumber(settings.exchange.exalt_div) ? settings.exchange.exalt_div : 180)
        : 1
    Return price * rate
}

CurrencyCounter_FromChaos(chaos, target_currency)
{
    local
    global settings
    rate := (target_currency = "divine") ? (IsNumber(settings.exchange.chaos_div) ? settings.exchange.chaos_div : 250)
        : (target_currency = "exalt") ? (IsNumber(settings.exchange.exalt_div) ? settings.exchange.exalt_div : 180)
        : 1
    Return (rate > 0) ? chaos / rate : 0
}

CurrencyCounter_ComputeTotal()
{
    local
    global vars, settings

    total_chaos := 0
    For name, entry in vars.currency_counter.currencies
        If IsObject(entry) && entry.count > 0 && entry.price != ""
            total_chaos += CurrencyCounter_ToChaos(entry.price, entry.price_currency) * entry.count

    val := CurrencyCounter_FromChaos(total_chaos, settings.currency_counter.display_cur)
    abbr := CurrencyCounter_CurAbbr(settings.currency_counter.display_cur)
    Return Round(val, 1) " " abbr
}

CurrencyCounter_CurAbbr(id)
{
    Return (id = "divine") ? "d" : (id = "exalt") ? "e" : "c"
}

; ──────────────────────────────────────────────────────────────
;  Table GUI  –  main popup panel
; ──────────────────────────────────────────────────────────────
CurrencyCounter_TableToggle()
{
    local
    global vars, settings

    If vars.hwnd.currency_counter_table.main && WinExist("ahk_id " vars.hwnd.currency_counter_table.main)
        CurrencyCounter_TableClose()
    Else
        CurrencyCounter_TableGUI()
}

CurrencyCounter_TableClose()
{
    local
    global vars

    LLK_Overlay(vars.hwnd.currency_counter_table.main, "destroy")
    vars.hwnd.currency_counter_table := {"main": ""}
}

CurrencyCounter_TableGUI()
{
    local
    global vars, settings
    static toggle := 0

    toggle := !toggle
    GUI_name := "cc_table" toggle
    fSize := settings.currency_counter.fSize
    fH := settings.currency_counter.fHeight
    fW := settings.currency_counter.fWidth
    ssf := settings.currency_counter.ssf

    ; ── Gather session data ──────────────────────────────────
    sessions := settings.currency_counter.sessions
    active_id := settings.currency_counter.active

    ; Filter currencies with count > 0
    currency_entries := []
    For name, entry in vars.currency_counter.currencies
        If IsObject(entry) && entry.count > 0
            currency_entries.Push({"name": name, "entry": entry})

    ; ── Column widths ────────────────────────────────────────
    col_name := fW * 18
    col_count := fW * 6
    col_price := fW * 8
    col_pc := fW * 6
    col_ts := fW * 9
    col_total := fW * 9
    ; In SSF mode remove price/pc/ts/total columns
    If ssf
        total_w := col_name + col_count + fW * 2 ; just name + count + margins
    Else
        total_w := col_name + col_count + col_price + col_pc + col_ts + col_total + fW * 2

    tab_h := fH * 1.8 ; session tab row height
    info_h := fH * 2.2 ; info bar height
    header_h := fH * 1.6 ; table header height
    row_h := fH * 1.8 ; table row height
    close_w := fH * 1.8 ; X button width

    ; Clamp to 75% monitor height
    max_rows := Max(1, Floor((vars.monitor.h * 0.75 - tab_h - info_h - header_h - fH * 2) / row_h))
    disp_rows := Min(currency_entries.Count(), max_rows)
    panel_h := tab_h + info_h + header_h + disp_rows * row_h + fH

    ; ── Build GUI ────────────────────────────────────────────
    Gui, %GUI_name%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDhwnd_table"
    Gui, %GUI_name%: Color, Black
    Gui, %GUI_name%: Margin, 0, 0
    Gui, %GUI_name%: Font, % "s" fSize " cWhite", % vars.system.font

    hwnd_old := vars.hwnd.currency_counter_table.main
    vars.hwnd.currency_counter_table := {"main": hwnd_table}

    ; ── Session tab bar ──────────────────────────────────────
    tab_x := 0
    For id, sname in sessions
    {
        is_active := (id = active_id)
        color := is_active ? "cLime" : "c606060"
        Gui, %GUI_name%: Font, % "s" fSize " " color, % vars.system.font
        Gui, %GUI_name%: Add, Text, % "x" tab_x " y0 h" tab_h " Border BackgroundTrans 0x200 HWNDhwnd_tab Center", % " " sname " "
        ControlGetPos,,, wTab,, % "ahk_id " hwnd_tab
        If is_active
        {
            Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled BackgroundBlack Border HWNDhwnd_tab_bg Range0-1", 1
            Gui, %GUI_name%: Add, Progress, % "xp yp wp h2 BackgroundLime", 0 ; active underline
        }
        Else
            Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background202020 Border", 0
        vars.hwnd.currency_counter_table["tab_" id] := hwnd_tab
        tab_x += wTab
    }

    ; "+" new session button
    Gui, %GUI_name%: Font, % "s" fSize " c606060", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x" tab_x " y0 h" tab_h " w" fH * 2 " Border BackgroundTrans 0x200 Center HWNDhwnd_add", % " + "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background202020 Border", 0
    vars.hwnd.currency_counter_table.add_session := hwnd_add

    ; X close button – far top-right
    Gui, %GUI_name%: Font, % "s" fSize " cRed", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x" total_w - close_w " y0 h" tab_h " w" close_w " Border BackgroundTrans 0x200 Center HWNDhwnd_close", % " X "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background202020 Border", 0
    vars.hwnd.currency_counter_table.close := hwnd_close

    ; ── Info bar ─────────────────────────────────────────────
    info_y := tab_h

    ; Session image placeholder
    Gui, %GUI_name%: Font, % "s" fSize " c404040", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x0 y" info_y " w" info_h " h" info_h " Border BackgroundTrans 0x200 Center HWNDhwnd_img", % "IMG"
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background1A1A1A Border", 0
    vars.hwnd.currency_counter_table.session_img := hwnd_img

    ; Session name edit
    name_w := total_w - info_h - fH * 4 - close_w ; leave room for del + total-cur + close
    Gui, %GUI_name%: Font, % "s" fSize " cWhite", % vars.system.font
    cur_name := vars.currency_counter.session_name
    Gui, %GUI_name%: Add, Edit, % "x" info_h " y" info_y + (info_h - fH) / 2 " w" name_w " h" fH " Background101010 HWNDhwnd_name_edit", % cur_name
    vars.hwnd.currency_counter_table.name_edit := hwnd_name_edit

    ; Delete button with long-press progress
    del_x := info_h + name_w
    Gui, %GUI_name%: Font, % "s" fSize " cCC3333", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x" del_x " y" info_y " w" fH * 2 " h" info_h " Border BackgroundTrans 0x200 Center HWNDhwnd_del", % " 🗑 "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background1A1A1A Border HWNDhwnd_del_prog Range0-500", 0
    vars.hwnd.currency_counter_table.del_btn := hwnd_del
    vars.hwnd.currency_counter_table.del_prog := hwnd_del_prog

    ; Total spent (label + value)
    total_x := del_x + fH * 2
    total_str := CurrencyCounter_ComputeTotal()
    Gui, %GUI_name%: Font, % "s" fSize - 2 " c606060", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x" total_x " y" info_y + fH * 0.2 " w" fH * 6 " h" fH * 0.9 " BackgroundTrans Center", % "Total spent"
    Gui, %GUI_name%: Font, % "s" fSize " cC89B3C", % vars.system.font
    Gui, %GUI_name%: Add, Text, % "x" total_x " y" info_y + fH * 1.2 " w" fH * 6 " h" fH " BackgroundTrans Center HWNDhwnd_total", % total_str
    vars.hwnd.currency_counter_table.total_label := hwnd_total

    ; Display currency button (right of total)
    dcu_x := total_x + fH * 6
    Gui, %GUI_name%: Font, % "s" fSize " cC89B3C", % vars.system.font
    dcu_abbr := CurrencyCounter_CurAbbr(settings.currency_counter.display_cur)
    Gui, %GUI_name%: Add, Text, % "x" dcu_x " y" info_y " w" fH * 2 " h" info_h " Border BackgroundTrans 0x200 Center HWNDhwnd_dcu", % " " dcu_abbr " "
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background1A1A1A Border", 0
    vars.hwnd.currency_counter_table.display_cur_btn := hwnd_dcu

    ; ── Table header ─────────────────────────────────────────
    header_y := info_y + info_h
    Gui, %GUI_name%: Font, % "s" fSize - 2 " c505050", % vars.system.font
    cx := 0
    CurrencyCounter_AddHeaderCell(GUI_name, "Currency", col_name, cx, header_y, header_h)
    cx += col_name
    CurrencyCounter_AddHeaderCell(GUI_name, "Count", col_count, cx, header_y, header_h, "Right")
    cx += col_count
    If !ssf
    {
        CurrencyCounter_AddHeaderCell(GUI_name, "Price (ea)", col_price, cx, header_y, header_h, "Right")
        cx += col_price
        CurrencyCounter_AddHeaderCell(GUI_name, "In", col_pc, cx, header_y, header_h, "Right")
        cx += col_pc
        CurrencyCounter_AddHeaderCell(GUI_name, "Updated", col_ts, cx, header_y, header_h, "Right")
        cx += col_ts
        CurrencyCounter_AddHeaderCell(GUI_name, "Total", col_total, cx, header_y, header_h, "Right")
    }

    ; ── Table rows ───────────────────────────────────────────
    Gui, %GUI_name%: Font, % "s" fSize " cWhite", % vars.system.font
    row_y := header_y + header_h
    displayed := 0
    For ri, item in currency_entries
    {
        If (displayed >= max_rows)
            Break
        displayed++
        name := item.name
        entry := item.entry
        bg := (Mod(displayed, 2) = 0) ? "1A1A1A" : "131313"

        ; row background
        Gui, %GUI_name%: Add, Progress, % "x0 y" row_y " w" total_w " h" row_h " Disabled Background" bg " Range0-1", 0

        ; Currency name cell
        cx := 0
        Gui, %GUI_name%: Font, % "s" fSize " cDDDDDD", % vars.system.font
        Gui, %GUI_name%: Add, Text, % "x" cx + fW/2 " y" row_y " w" col_name - fW " h" row_h " BackgroundTrans 0x200", % name

        ; Count cell
        cx += col_name
        Gui, %GUI_name%: Add, Text, % "x" cx " y" row_y " w" col_count " h" row_h " BackgroundTrans 0x200 Right", % entry.count " "

        If !ssf
        {
            ; Price cell – clickable to edit
            cx += col_count
            price_col := CurrencyCounter_PriceColor(entry.price_updated)
            Gui, %GUI_name%: Font, % "s" fSize " c" price_col, % vars.system.font
            price_str := (entry.price != "") ? entry.price : "—"
            Gui, %GUI_name%: Add, Text, % "x" cx " y" row_y " w" col_price " h" row_h " BackgroundTrans 0x200 Right HWNDhwnd_price", % price_str " "
            vars.hwnd.currency_counter_table["price_" name] := hwnd_price

            ; Price currency icon cell
            cx += col_price
            Gui, %GUI_name%: Font, % "s" fSize - 2 " c808080", % vars.system.font
            pc_abbr := CurrencyCounter_CurAbbr(entry.price_currency)
            Gui, %GUI_name%: Add, Text, % "x" cx " y" row_y " w" col_pc " h" row_h " BackgroundTrans 0x200 Right", % pc_abbr " "

            ; Age / updated cell
            cx += col_pc
            Gui, %GUI_name%: Font, % "s" fSize - 2 " c" price_col, % vars.system.font
            age_str := CurrencyCounter_FormatAge(entry.price_updated)
            Gui, %GUI_name%: Add, Text, % "x" cx " y" row_y " w" col_ts " h" row_h " BackgroundTrans 0x200 Right", % age_str " "

            ; Row total cell
            cx += col_ts
            If (entry.price != "" && entry.count > 0)
            {
                row_chaos := CurrencyCounter_ToChaos(entry.price, entry.price_currency) * entry.count
                row_val := CurrencyCounter_FromChaos(row_chaos, settings.currency_counter.display_cur)
                row_str := Round(row_val, 1) " " CurrencyCounter_CurAbbr(settings.currency_counter.display_cur)
            }
            Else row_str := "—"
                Gui, %GUI_name%: Font, % "s" fSize " c808080", % vars.system.font
            Gui, %GUI_name%: Add, Text, % "x" cx " y" row_y " w" col_total " h" row_h " BackgroundTrans 0x200 Right", % row_str " "
        }

        ; Row separator
        Gui, %GUI_name%: Add, Progress, % "x0 y" row_y + row_h - 1 " w" total_w " h1 Disabled Background2A2A2A Range0-1", 1
        row_y += row_h
    }

    ; Empty-state message
    If !currency_entries.Count()
    {
        Gui, %GUI_name%: Font, % "s" fSize " c404040", % vars.system.font
        Gui, %GUI_name%: Add, Text, % "x0 y" row_y " w" total_w " h" fH * 2 " BackgroundTrans 0x200 Center", % "No currencies used in this session."
        row_y += fH * 2
    }

    ; ── Position & show ──────────────────────────────────────
    Gui, %GUI_name%: Show, % "NA x10000 y10000"
    WinGetPos,,, real_w, real_h, % "ahk_id " hwnd_table
    xPos := vars.monitor.x + vars.client.xc - real_w / 2
    yPos := vars.monitor.y + Floor(vars.monitor.h * 0.12)
    Gui_CheckBounds(xPos, yPos, real_w, real_h)
    Gui, %GUI_name%: Show, % "NA x" xPos " y" yPos
    LLK_Overlay(hwnd_table, "show",, GUI_name)
    If hwnd_old
        LLK_Overlay(hwnd_old, "destroy")
}

; ── Helper: add one header cell ──────────────────────────────
CurrencyCounter_AddHeaderCell(GUI_name, label, w, x, y, h, align := "Left")
{
    global vars, settings
    Gui, %GUI_name%: Add, Text, % "x" x " y" y " w" w " h" h " BackgroundTrans 0x200 " align " Border", % (align = "Left" ? " " : "") label (align = "Right" ? " " : "")
    Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Disabled Background1E1E1E Border Range0-1", 0
}

; ── Helper: format age of price timestamp ────────────────────
CurrencyCounter_FormatAge(ts)
{
    local
    If !ts || !IsNumber(ts)
        Return "—"
    h := CurrencyCounter_PriceAgeHours(ts)
    If (h > 24)
        Return Floor(h / 24) "d ago"
    If (h >= 1)
        Return Floor(h) "h " Floor((h - Floor(h)) * 60) "m"
    Return Floor(h * 60) "m ago"
}

; ──────────────────────────────────────────────────────────────
;  Table click handler
; ──────────────────────────────────────────────────────────────
CurrencyCounter_TableClick(cHWND, hotkey)
{
    local
    global vars, settings

    LLK_ToolTip("Table click " . hotkey,1.5)

    check := LLK_HasVal(vars.hwnd.currency_counter_table, cHWND)
    If Blank(check)
        Return

    ; X close button
    If (check = "close")
    {
        KeyWait, LButton
        CurrencyCounter_TableClose()
        Return
    }

    ; Session tab click – switch session
    If (SubStr(check, 1, 4) = "tab_")
    {
        id := SubStr(check, 5)
        If (id != settings.currency_counter.active)
        {
            CurrencyCounter_SetActive(id)
            CurrencyCounter_TableGUI()
        }
        Return
    }

    ; Add new session
    If (check = "add_session")
    {
        KeyWait, LButton
        CurrencyCounter_NewSession("Session " A_Now, "")
        CurrencyCounter_TableGUI()
        Return
    }

    ; Session image – placeholder
    If (check = "session_img")
    {
        KeyWait, LButton
        ; TODO: open image picker
        Return
    }

    ; Session name edit – focus the edit control
    If (check = "name_edit")
        Return ; AHK Edit controls handle focus natively

    ; Delete button – long press 3 seconds
    If (check = "del_btn")
    {
        If (hotkey = 1)
        {
            start := A_TickCount
            While GetKeyState("LButton", "P")
            {
                elapsed := A_TickCount - start
                pct := Min(500, Round(elapsed / 3000 * 500))
                GuiControl, % "+c" (pct >= 500 ? "Red" : "FF8C00"), % vars.hwnd.currency_counter_table.del_prog
                GuiControl,, % vars.hwnd.currency_counter_table.del_prog, % pct
                If (elapsed >= 3000)
                {
                    KeyWait, LButton
                    If settings.currency_counter.sessions.Count() <= 1
                    {
                        LLK_ToolTip("Cannot delete the only session.", 2,,,, "Red")
                        GuiControl,, % vars.hwnd.currency_counter_table.del_prog, 0
                        Return
                    }
                    CurrencyCounter_DeleteSession(settings.currency_counter.active)
                    CurrencyCounter_TableGUI()
                    Return
                }
                Sleep, 30
            }
            GuiControl,, % vars.hwnd.currency_counter_table.del_prog, 0
        }
        Return
    }

    ; Display currency button – cycle through chaos → divine → exalt → chaos
    If (check = "display_cur_btn")
    {
        KeyWait, LButton
        order := ["chaos", "divine", "exalt"]
        cur := settings.currency_counter.display_cur
        idx := 1
        For i, c in order
            If (c = cur)
            {
                idx := i
                Break
            }
        next := order[Mod(idx, order.Count()) + 1]
        settings.currency_counter.display_cur := next
        IniWrite, % next, % "ini" vars.poe_version "\currency-counter.ini", settings, display-currency
        CurrencyCounter_TableGUI()
        Return
    }

    ; Price cell click – inline edit
    If (SubStr(check, 1, 6) = "price_")
    {
        currency_name := SubStr(check, 7)
        If hotkey = 1
            CurrencyCounter_EditPrice(cHWND, currency_name)
        Return
    }
}

; ──────────────────────────────────────────────────────────────
;  Inline price editor  (small Edit field over the price cell)
; ──────────────────────────────────────────────────────────────
CurrencyCounter_EditPrice(price_hwnd, currency_name)
{
    local
    global vars, settings

    KeyWait, LButton
    entry := vars.currency_counter.currencies[currency_name]
    If !IsObject(entry)
        Return

    WinGetPos, xCtrl, yCtrl, wCtrl, hCtrl, % "ahk_id " price_hwnd

    ; Build tiny edit GUI
    Gui, cc_price_edit: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +E0x02000000 HWNDhwnd_edit"
    Gui, cc_price_edit: Color, 101010
    Gui, cc_price_edit: Margin, 2, 2
    Gui, cc_price_edit: Font, % "s" settings.currency_counter.fSize " cWhite", % vars.system.font
    Gui, cc_price_edit: Add, Edit, % "w" wCtrl - 4 " h" hCtrl - 4 " Background202020 HWNDhwnd_input", % (entry.price != "" ? entry.price : "")
    Gui, cc_price_edit: Add, Button, % "Default Hidden gCurrencyCounter_PriceEditOK HWNDhwnd_ok", ok
    vars.hwnd.currency_counter_table.price_edit := hwnd_edit
    vars.hwnd.currency_counter_table.price_edit_input := hwnd_input
    vars.hwnd.currency_counter_table.price_edit_name := currency_name
    Gui, cc_price_edit: Show, % "NA x" xCtrl " y" yCtrl
    ControlFocus,, % "ahk_id " hwnd_input
    ControlSend,, {End}, % "ahk_id " hwnd_input

    While WinActive("ahk_id " hwnd_edit)
        Sleep, 10

    ; Save on close (click away)
    CurrencyCounter_PriceEditSave()
    Gui, cc_price_edit: Destroy
}

CurrencyCounter_PriceEditOK:
    CurrencyCounter_PriceEditSave()
    Gui, cc_price_edit: Destroy
Return

CurrencyCounter_PriceEditSave()
{
    local
    global vars, settings

    name := vars.hwnd.currency_counter_table.price_edit_name
    hwnd := vars.hwnd.currency_counter_table.price_edit_input
    If !name || !hwnd
        Return
    raw := LLK_ControlGet(hwnd)
    ; Accept comma or dot as decimal separator
    raw := StrReplace(raw, ",", ".")
    If IsNumber(raw) && (raw + 0) >= 0
    {
        vars.currency_counter.currencies[name].price := raw + 0
        vars.currency_counter.currencies[name].price_updated := A_Now
        CurrencyCounter_SaveCurrency(name)
    }
    vars.hwnd.currency_counter_table.price_edit_name := ""
    CurrencyCounter_DrawBar()
    CurrencyCounter_TableGUI()
}

; ──────────────────────────────────────────────────────────────
;  Bar click → open/close table
; ──────────────────────────────────────────────────────────────
CurrencyCounter_BarClick()
{
    local
    global vars, settings

    LLK_ToolTip("BARclicked",1.5)

    ; Check if click is on the drag handle (top-left area) – if so, don't open table
    check := LLK_HasVal(vars.hwnd.currency_counter, vars.general.cMouse)
    If (check = "drag")
        Return ; let CurrencyCounter_Click() handle dragging

    KeyWait, LButton
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

    vars.currency_counter.currencies[vars.currency_counter.name].count += 1
    vars.currency_counter.last_used := vars.currency_counter.name

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

    CurrencyCounter_SaveCurrency(vars.currency_counter.name)
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
