; ──────────────────────────────────────────────────────────────
;  CurrencyCounter_Logs()
;  Wire in hotkeys.ahk:
;    #If vars.hwnd.cc_logs.main && (vars.general.wMouse = vars.hwnd.cc_logs.main)
;    LButton::CurrencyCounter_Logs2(vars.general.cMouse)
; ──────────────────────────────────────────────────────────────
CurrencyCounter_Logs(cHWND := "")
{
	local
	global vars, settings
	static toggle := 0

	fSize2 := settings.currency_counter.fSize2
	LLK_FontDimensions(fSize2, fHeight2, fWidth2)
	hFont := fHeight2 * 1.5
	max_lines := Floor(vars.monitor.h * 0.75 / hFont)
	ssf := settings.currency_counter.ssf

	; ══════════════════════════════════════════════════════════
	;  TABLE COLUMNS
	;
	;  The layout trick (directly from Maptracker_Logs):
	;
	;  Column 1:  hidden anchor  "Section xs  y+gap  w<width>"
	;             → ControlGetPos gives yEdit/hEdit for the whole table
	;             → all later search-row controls use "xs Section" or "ys"
	;             → header label uses "xs y+-1"
	;             → data rows use "xs" (return to this column's left edge)
	;
	;  Column N>1: hidden anchor  "ys Section  w<width>  h<hEdit>"
	;             → "ys" keeps same Y as col-1 anchor (one header row)
	;             → "Section" sets a new anchor for this column's xs
	;             → search spacer/edit uses "xs Section" (same left as anchor)
	;             → header label uses "xs y+-1"
	;             → data rows use "xs"
	; ══════════════════════════════════════════════════════════
	If ssf
		table := [ ["name", "left", ["Currency", "77777777777777777777777777777"]]
			, ["count", "right", ["Count", "777777"]] ]
	Else
		table := [ ["name", "left", ["Currency", "77777777777777777777777777777"]]
			, ["count", "right", ["Count", "777777"]]
			, ["price", "right", ["Price (ea)", "777777"]]
			, ["pc", "center", ["In", "77777"]]
			, ["ts", "right", ["Updated", "7777777777"]]
			, ["total", "right", ["Total", "777777777"]] ]

	totalColumnsWidth := 0
	For col_i, val in table
	{
		header := val.1
		LLK_PanelDimensions(val.3, fSize2, width, height,, 4)
		width := (width < hFont) ? hFont : width
		totalColumnsWidth += width
	}
	hEdit := hFont ; approximation, or compute exactly using LLK_PanelDimensions on a sample string
	totalWidth := totalColumnsWidth

	; ── Gather entries (currencies with count > 0) ──────────
	entries := []
	For name, entry in vars.currency_counter.currencies
		If IsObject(entry) && entry.count > 0
			entries.Push({"name": name, "entry": entry})

	toggle := !toggle, GUI_name := "cc_logs" toggle
	Gui, %GUI_name%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDcc_logs"
	Gui, %GUI_name%: Color, Black
	Gui, %GUI_name%: Margin, -1, -1
	Gui, %GUI_name%: Font, % "s" fSize2 " cWhite", % vars.system.font
	hwnd_old := vars.hwnd.cc_logs.main
	vars.hwnd.cc_logs := {"main": cc_logs, "toggle": toggle}

	; ══════════════════════════════════════════════════════════
	;  Drag box
	; ══════════════════════════════════════════════════════════
	Gui, %GUI_name%: Add, Text, % "w" (totalWidth - (fWidth2 * 3)) " h" hFont " Border Center 0x200 BackgroundTrans gCurrencyCounter_Logs2 HWNDhwnd_drag", % "Currency Counter Viewer"
	vars.hwnd.cc_logs.dragbar := hwnd_drag

	Gui, %GUI_name%: Add, Text, % "x" (totalWidth - (fWidth2 * 3) - 2) " y-1 w" (fWidth2 * 3) - 1 " h" hFont " Border Center 0x200 gCurrencyCounter_Logs2 HWNDhwnd_close", % "x"
	vars.hwnd.cc_logs.close := hwnd_close

	; ══════════════════════════════════════════════════════════
	;  SESSION TABS
	; ══════════════════════════════════════════════════════════
	Gui, %GUI_name%: Font, % "s" fSize2 - 2, % vars.system.font
	Gui, %GUI_name%: Add, Text, x0 y+10 Section Hidden  ; invisible anchor
	active_id := settings.currency_counter.active

	settings.currency_counter.spacing := 10 ;TODO: actually make it in setting with clamp
	settings.currency_counter.visibleCount := ssf ? 2 : 4 ;TODO: actually make it in setting with clamp

	visibleCount := settings.currency_counter.visibleCount
	spacing := settings.currency_counter.spacing
	if(Blank(vars.currency_counter.carousel_index))
		vars.currency_counter.carousel_index := 0

	newSessionButtonWidth := fWidth2
	itemWidth := (totalWidth - newSessionButtonWidth - (visibleCount + 1) * spacing) / visibleCount
	itemHeight := hFont * 2
	picWidth := itemWidth ; Adjust this ratio as needed
	gap := 5
	firstItemAdded := false
	LLK_ToolTip("session " visibleCount, 2)

	Loop % visibleCount {
		idx := A_Index
		xPos := (idx-1)*(itemWidth + spacing)

    	; Picture: left side                   ; top aligned within the element
    	picH := itemHeight - 2             ; a little smaller to avoid edge clipping

    	; Text: right side, vertically centered
    	txtX := xPos + picWidth + gap
		txtW := itemWidth - picWidth - gap

		yOpt := !firstItemAdded ? "ys" : "yp"
		LLK_ToolTip("Loop " idx, 2)

		For key, val in settings.currency_counter.sessions
		{
			if(idx < vars.currency_counter.carousel_index || idx >= vars.currency_counter.carousel_index + visibleCount)
				continue
			LLK_ToolTip("Tworzy", 2)
			if(!Blank(val.img)) ;check if image exist
			{
				Gui, Add, Picture, % "x" xPos " " yOpt " w" picWidth " h" itemHeight, val.img
				firstItemAdded := true
				yOpt := "yp"
			}
			Else
			{
				txtX -= picWidth
				txtW += picWidth
			}

			Gui, Add, Text , % "x" txtX " " yOpt " w" txtW " h" itemHeight " Center", val.name
			firstItemAdded := true
		}
	}
	Gui, %GUI_name%: Add, Text, % "yp x" totalWidth - newSessionButtonWidth " w" newSessionButtonWidth " h" itemHeight "Border gCurrencyCounter_Logs2 HWNDhwnd c606060 ", % " + "
	vars.hwnd.cc_logs.add_session := hwnd

	; ══════════════════════════════════════════════════════════
	;  INFO BAR  – image | name edit | delete
	; ══════════════════════════════════════════════════════════
	Gui, %GUI_name%: Font, % "s" fSize2, % vars.system.font

	; Hidden anchor to measure hEdit for the info bar row
	Gui, %GUI_name%: Add, Text, % "xs Section BackgroundTrans Hidden Border HWNDhwnd x-1 y+" fHeight2/4 " w" fHeight2, % " "
	ControlGetPos,, yEdit,, hEdit,, % "ahk_id " hwnd
	Gui, %GUI_name%: Add, Button, % "xp yp wp hp Hidden Default gCurrencyCounter_Logs2 HWNDhwnd_defbtn", ok
	vars.hwnd.cc_logs.filter_button := hwnd_defbtn

	Gui, %GUI_name%: Add, Text, % "xs Section y+0 Border gCurrencyCounter_Logs2 HWNDhwnd 0x200 Center c404040 w" hEdit " h" hEdit, % "IMG"
	vars.hwnd.cc_logs.session_img := hwnd
	Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled Background1A1A1A HWNDhwnd", 0

	Gui, %GUI_name%: Add, Edit, % "ys yp gCurrencyCounter_Logs2 HWNDhwnd_name_edit w" fWidth2 * 14 " h" hEdit, % vars.currency_counter.session_name
	vars.hwnd.cc_logs.name_edit := hwnd_name_edit

	Gui, %GUI_name%: Add, Text, % "ys yp Border gCurrencyCounter_Logs2 HWNDhwnd 0x200 Center cCC3333 x+" fWidth2//4 " w" hEdit " h" hEdit, % "X"
	vars.hwnd.cc_logs.del_btn := hwnd
	Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled BackgroundBlack cRed HWNDhwnd range0-500", 0
	vars.hwnd.cc_logs.del_prog := hwnd

	row_count := Min(entries.Count(), max_lines)

	For col_i, val in table
	{
		header := val.1
		LLK_PanelDimensions(val.3, fSize2, width, height,, 4)
		width := (width < hFont) ? hFont : width

		Gui, %GUI_name%: Font, % "s" fSize2

		; ── Column 1: hidden anchor to measure hEdit, then search row ──
		; ── Columns 2+: search/spacer IS the Section anchor (ys Section) ──
		If (col_i = 1)
		{
			; Hidden anchor: sets xs left wall, gives us hEdit via ControlGetPos
			Gui, %GUI_name%: Add, Text, % "Section xs BackgroundTrans Hidden Border HWNDhwnd x-1 y+" fHeight2/4 " w" width, % " "
			ControlGetPos,, yEdit,, hEdit,, % "ahk_id " hwnd

			; Search row for col 1: "Search" label + X reset
			; Uses "xs Section" so xs is re-anchored here for sub-controls,
			; then header "xs y+-1" will correctly return to this x.
			Gui, %GUI_name%: Add, Text, % "xs Section BackgroundTrans Right w" width - hEdit - fWidth2//2 " h" hEdit, % "Search"
			Gui, %GUI_name%: Add, Text, % "ys Border BackgroundTrans Center gCurrencyCounter_Logs2 HWNDhwnd cRed 0x200 x+" fWidth2//4 " w" hEdit " h" hEdit, % "X"
			vars.hwnd.cc_logs.filter_reset := hwnd
		}
		Else If (header = "price")
		{
			; Edit IS the Section anchor for this column
			Gui, %GUI_name%: Add, Edit, % "ys Section cBlack gCurrencyCounter_Logs2 HWNDhwnd_search w" width " h" hEdit (!Blank(pCheck := vars.cc_logs.keywords["price"]) ? " cGreen" : ""), % pCheck
			vars.hwnd.cc_logs.search_price := hwnd_search
		}
		Else
		{
			; Spacer IS the Section anchor for this column
			Gui, %GUI_name%: Add, Text, % "ys Section BackgroundTrans Border w" width " h" hEdit, % " "
		}

		; ── Header label: xs returns to this column's anchor, y+-1 overlaps border ──
		Gui, %GUI_name%: Font, % "s" fSize2 + 4
		Gui, %GUI_name%: Add, Text, % "xs y+-1 BackgroundTrans Border Center HWNDhwnd w" width, % val.3.1
		vars.hwnd.cc_logs["col_" header] := hwnd

		; ── Data rows ────────────────────────────────────────
		Gui, %GUI_name%: Font, % "s" fSize2
		Loop, % row_count
		{
			ri := A_Index
			item := entries[ri]
			name := item.name
			entry := item.entry
			bg := Mod(ri, 2) ? "131313" : "1A1A1A"

			If (header = "name")
				cell_text := " " name, color := "", gLabel := " gCurrencyCounter_Logs2"
			Else If (header = "count")
				cell_text := entry.count " ", color := "", gLabel := ""
			Else If (header = "price")
				cell_text := (entry.price != "") ? entry.price " " : "— ", color := " c" CurrencyCounter_PriceColor(entry.price_updated), gLabel := " gCurrencyCounter_Logs2"
			Else If (header = "pc")
				cell_text := " " CurrencyCounter_CurAbbr(entry.price_currency) " ", color := " c808080", gLabel := ""
			Else If (header = "ts")
				cell_text := CurrencyCounter_FormatAge(entry.price_updated) " ", color := " c" CurrencyCounter_PriceColor(entry.price_updated), gLabel := ""
			Else If (header = "total")
			{
				If (entry.price != "" && entry.count > 0)
				{
					chaos := CurrencyCounter_ToChaos(entry.price, entry.price_currency) * entry.count
					cell_text := Round(CurrencyCounter_FromChaos(chaos, settings.currency_counter.display_cur), 1) " " CurrencyCounter_CurAbbr(settings.currency_counter.display_cur) " "
				}
				Else cell_text := "— "
					color := " c808080", gLabel := ""
			}

			Gui, %GUI_name%: Add, Text, % "xs Border 0x200 BackgroundTrans HWNDhwnd0 " val.2 " w" width . gLabel . color " h" hFont, % cell_text
			vars.hwnd.cc_logs[header "_" name] := hwnd0
			Gui, %GUI_name%: Add, Progress, % "xp yp w" width " hp Border Disabled Background" bg " HWNDhwnd", 0
		}

		; Empty-state row (first column only)
		If (col_i = 1) && !entries.Count()
		{
			Gui, %GUI_name%: Font, % "s" fSize2 " c404040", % vars.system.font
			Gui, %GUI_name%: Add, Text, % "xs y+0 BackgroundTrans w" width " h" hFont " 0x200", % " No currencies used in this session."
		}
	}

	; ── Position & show ──────────────────────────────────────
	Gui, %GUI_name%: Show, % "NA x10000 y10000"
	WinGetPos,,, w, h, % "ahk_id " cc_logs
	Gui, %GUI_name%: Show, % "NA x" vars.monitor.x + vars.client.xc - w/2 " y" vars.monitor.y + vars.monitor.h * 0.15
	LLK_Overlay(cc_logs, "show", 0, GUI_name), LLK_Overlay(hwnd_old, "destroy")
}

; ──────────────────────────────────────────────────────────────
;  CurrencyCounter_Logs2(cHWND)  –  unified click handler
; ──────────────────────────────────────────────────────────────
CurrencyCounter_Logs2(cHWND)
{
	local
	global vars, settings

	; ── Edit field notifications ──────────────────────────────
	If (cHWND = vars.hwnd.cc_logs.name_edit)
	{
		input := LLK_ControlGet(cHWND)
		If (input != vars.currency_counter.session_name)
		{
			vars.currency_counter.session_name := input
			id := settings.currency_counter.active
			IniWrite, % input, % "ini" vars.poe_version "\currency-counter.ini", % "session_" id, name
			settings.currency_counter.sessions[id] := input
			CurrencyCounter_SaveIndex()
		}
		Return
	}

	If (cHWND = vars.hwnd.cc_logs.search_price)
	{
		input := LLK_ControlGet(cHWND)
		GuiControl, % "+c" (Blank(input) ? "Black" : "Green"), % cHWND
		GuiControl, movedraw, % cHWND
		Return
	}

	; ── Named control dispatch ────────────────────────────────
	check := LLK_HasVal(vars.hwnd.cc_logs, cHWND)

	Switch check
	{
	Case "close":
		KeyWait, LButton
		KeyWait, RButton
		LLK_Overlay(vars.hwnd.cc_logs.main, "destroy")
		vars.hwnd.cc_logs := {"main": ""}
		Return

	Case "filter_reset":
		KeyWait, LButton
		KeyWait, RButton
		vars.cc_logs.keywords := {}
		If vars.hwnd.cc_logs.search_price
			GuiControl,, % vars.hwnd.cc_logs.search_price, % ""
		CurrencyCounter_Logs()
		Return

	Case "dragbar":
		While GetKeyState("LButton", "P") ;dragging the window
		{
			WinGetPos, xWin, yWin, wWin, hWin, % "ahk_id " vars.hwnd.cc_logs.main
			MouseGetPos, xMouse, yMouse
			While GetKeyState("LButton", "P")
			{
				LLK_Drag(wWin, hWin, xPos, yPos, 1,vars.hwnd.cc_logs.main,, xMouse - xWin, yMouse - yWin)
				sleep 1
			}
			KeyWait, LButton
			WinGetPos, xPos, yPos, w, h, % "ahk_id " vars.hwnd.cc_logs.main
			;TODO: save and set - vars.cc_logs.x := xPos, vars.cc_logs.y := yPos, vars.general.drag := 0
			Return
		}
		Return

	Case "filter_button":
		CurrencyCounter_Logs()
		Return

	Case "display_cur_btn":
		KeyWait, LButton
		order := ["chaos", "divine", "exalt"]
		cur := settings.currency_counter.display_cur
		Loop, % order.Count()
			If (order[A_Index] = cur)
			{
				next := order[Mod(A_Index, order.Count()) + 1]
				Break
			}
		settings.currency_counter.display_cur := next
		IniWrite, % next, % "ini" vars.poe_version "\currency-counter.ini", settings, display-currency
		CurrencyCounter_Logs()
		Return

	Case "session_img":
		KeyWait, LButton
		; TODO: image picker
		Return

	Case "add_session":
		KeyWait, LButton
		CurrencyCounter_NewSession()
		CurrencyCounter_Logs()
		Return

	Case "del_btn":
		start := A_TickCount
		While GetKeyState("LButton", "P")
		{
			elapsed := A_TickCount - start
			pct := Min(500, Round(elapsed / 3000 * 500))
			GuiControl,, % vars.hwnd.cc_logs.del_prog, % pct
			If (elapsed >= 3000)
			{
				KeyWait, LButton
				GuiControl,, % vars.hwnd.cc_logs.del_prog, 0
				If settings.currency_counter.sessions.Count() <= 1
				{
					LLK_ToolTip("Cannot delete the only session.", 2,,,, "Red")
					Return
				}
				CurrencyCounter_DeleteSession(settings.currency_counter.active)
				CurrencyCounter_Logs()
				Return
			}
			Sleep, 30
		}
		GuiControl,, % vars.hwnd.cc_logs.del_prog, 0
		Return
	}

	; ── Session tab click ─────────────────────────────────────
	If InStr(check, "tab_")
	{
		id := SubStr(check, 5)
		KeyWait, LButton
		If (id != settings.currency_counter.active)
		{
			CurrencyCounter_SetActive(id)
			CurrencyCounter_Logs()
		}
		Return
	}

	; ── Price cell click – inline edit overlay ────────────────
	If InStr(check, "price_")
	{
		currency_name := SubStr(check, 7)
		If (vars.system.click = 1)
			CurrencyCounter_PriceEdit(cHWND, currency_name)
		Return
	}
}

; ──────────────────────────────────────────────────────────────
;  CurrencyCounter_PriceEdit  –  tiny overlay Edit on the cell
; ──────────────────────────────────────────────────────────────
CurrencyCounter_PriceEdit(cHWND, currency_name)
{
	local
	global vars, settings
	static toggle := 0

	KeyWait, LButton
	entry := vars.currency_counter.currencies[currency_name]
	If !IsObject(entry)
		Return

	WinGetPos, xCtrl, yCtrl, wCtrl, hCtrl, % "ahk_id " cHWND

	toggle := !toggle, eName := "cc_price_edit" toggle
	Gui, %eName%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +E0x02000000 +E0x00080000 HWNDhwnd_edit"
	Gui, %eName%: Color, 101010
	Gui, %eName%: Margin, 1, 1
	Gui, %eName%: Font, % "s" settings.currency_counter.fSize2 " cWhite", % vars.system.font
	Gui, %eName%: Add, Edit, % "w" wCtrl - 2 " h" hCtrl - 2 " Background202020 HWNDhwnd_input", % (entry.price != "") ? entry.price : ""
	Gui, %eName%: Add, Button, % "Default Hidden gCurrencyCounter_PriceEditSave HWNDhwnd_ok", ok
	vars.hwnd.cc_price_edit := {"main": hwnd_edit, "input": hwnd_input, "name": currency_name}
	Gui, %eName%: Show, % "NA x" xCtrl " y" yCtrl
	ControlFocus,, % "ahk_id " hwnd_input
	ControlSend,, {End}, % "ahk_id " hwnd_input

	While WinActive("ahk_id " hwnd_edit)
		Sleep, 10

	CurrencyCounter_PriceEditCommit()
	Gui, %eName%: Destroy
}

CurrencyCounter_PriceEditSave:
	CurrencyCounter_PriceEditCommit()
	Gui, cc_price_edit1: Destroy
	Gui, cc_price_edit2: Destroy
Return

CurrencyCounter_PriceEditCommit()
{
	local
	global vars, settings

	hwnd := vars.hwnd.cc_price_edit.input
	cname := vars.hwnd.cc_price_edit.name
	If !hwnd || !cname
		Return
	raw := StrReplace(LLK_ControlGet(hwnd), ",", ".")
	If IsNumber(raw) && (raw + 0 >= 0)
	{
		vars.currency_counter.currencies[cname].price := raw + 0
		vars.currency_counter.currencies[cname].price_updated := A_Now
		CurrencyCounter_SaveCurrency(cname)
	}
	vars.hwnd.cc_price_edit := {"main": "", "input": "", "name": ""}
	CurrencyCounter_DrawBar()
	CurrencyCounter_Logs()
}

; ──────────────────────────────────────────────────────────────
;  Helpers
; ──────────────────────────────────────────────────────────────
CurrencyCounter_PriceAgeHours(ts)
{
	local
	If !ts || !IsNumber(ts)
		Return 9999
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
		Return Format("{:02X}{:02X}00", Round(180 + 75 * (h-6)/6), Round(170 * (1-(h-6)/6)))
	Return "4A9E4A"
}

CurrencyCounter_FormatAge(ts)
{
	local
	If !ts || !IsNumber(ts)
		Return "—"
	h := CurrencyCounter_PriceAgeHours(ts)
	If (h > 24)
		Return Floor(h / 24) "d"
	If (h >= 1)
		Return Floor(h) "h " Floor((h - Floor(h)) * 60) "m"
	Return Floor(h * 60) "m"
}

CurrencyCounter_CurAbbr(id)
{
	Return (id = "divine") ? "d" : (id = "exalt") ? "e" : "c"
}

CurrencyCounter_ToChaos(price, price_currency)
{
	local
	global settings
	If (price = "" || price = 0)
		Return 0
	rate := (price_currency = "divine") ? (IsNumber(settings.exchange.chaos_div) ? settings.exchange.chaos_div : 250)
		: (price_currency = "exalt") ? (IsNumber(settings.exchange.exalt_div) ? settings.exchange.exalt_div : 180)
		: 1
	Return price * rate
}

CurrencyCounter_FromChaos(chaos, target)
{
	local
	global settings
	rate := (target = "divine") ? (IsNumber(settings.exchange.chaos_div) ? settings.exchange.chaos_div : 250)
		: (target = "exalt") ? (IsNumber(settings.exchange.exalt_div) ? settings.exchange.exalt_div : 180)
		: 1
	Return (rate > 0) ? chaos / rate : 0
}

CurrencyCounter_ComputeTotal()
{
	local
	global vars, settings
	chaos := 0
	For name, entry in vars.currency_counter.currencies
		If IsObject(entry) && entry.count > 0 && entry.price != ""
			chaos += CurrencyCounter_ToChaos(entry.price, entry.price_currency) * entry.count
	Return Round(CurrencyCounter_FromChaos(chaos, settings.currency_counter.display_cur), 1) " " CurrencyCounter_CurAbbr(settings.currency_counter.display_cur)
}

CurrencyCounter_ShiftCarousel() {
    
}

