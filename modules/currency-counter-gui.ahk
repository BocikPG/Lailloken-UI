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

	fSize2 := settings.currency_counter.fSize
	LLK_FontDimensions(fSize2, fHeight2, fWidth2)
	LLK_FontDimensions(fSize2 + 4, fHeight3, fWidth3)
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
			, ["total", "right", ["Total", "7777777777777"]] ]

	totalColumnsWidth := 0
	totalColWidth := 0
	For col_i, val in table
	{
		header := val.1
		LLK_PanelDimensions(val.3, fSize2, width, height,, 4)
		width := (width < hFont) ? hFont : width
		totalColumnsWidth += width
		If (val.1 = "total")
		{
			totalColWidth := width
		}
	}
	hEdit := hFont ; approximation, or compute exactly using LLK_PanelDimensions on a sample string
	totalWidth := totalColumnsWidth

	; ── Gather entries (currencies with count > 0) ──────────

	entries := []
	kw := vars.cc_logs.keywords["name"]
	For name, entry in vars.currency_counter.currencies
		If IsObject(entry) && entry.count > 0
			&& (Blank(kw) || InStr(name, kw))
			entries.Push({"name": name, "entry": entry})

	col := vars.cc_logs.sort_col
	asc := vars.cc_logs.sort_asc
	If (col != "")
	{
		Loop, % entries.Count() - 1
		{
			i := A_Index
			Loop, % entries.Count() - i
			{
				j := A_Index
				a := entries[j], b := entries[j+1]
				If (col = "count")
					swap := asc ? a.entry.count > b.entry.count : a.entry.count < b.entry.count
				Else If (col = "price")
					swap := asc ? a.entry.price > b.entry.price : a.entry.price < b.entry.price
				Else If (col = "name")
					swap := asc ? a.name > b.name : a.name < b.name
				Else If (col = "ts")
					swap := asc ? a.entry.price_updated < b.entry.price_updated : a.entry.price_updated > b.entry.price_updated
				Else If (col = "total")
				{
					chaosA := CurrencyCounter_ToChaos(a.entry.price, a.entry.price_currency) * a.entry.count
					chaosB := CurrencyCounter_ToChaos(b.entry.price, b.entry.price_currency) * b.entry.count
					swap := asc ? chaosA > chaosB : chaosA < chaosB
				}
				If swap
				{
					temp := entries[j]
					entries[j] := entries[j+1]
					entries[j+1] := temp
				}
			}
		}
	}

	toggle := !toggle, GUI_name := "cc_logs" toggle
	Gui, %GUI_name%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDcc_logs"
	Gui, %GUI_name%: Color, Black
	Gui, %GUI_name%: Margin, -1, -1
	Gui, %GUI_name%: Font, % "s" fSize2 " cWhite", % vars.system.font
	hwnd_old := vars.hwnd.cc_logs.main
	vars.hwnd.cc_logs := {"main": cc_logs, "toggle": toggle}

	; ══════════════════════════════════════════════════════════
	;  Drag box – dynamically adjusts to actual window width
	; ══════════════════════════════════════════════════════════
	border_compensation := (table.Count() - 1) * 1 ; each column adds ~2px border
	closeWidth := fWidth2 * 3
	dragWidth := totalWidth - closeWidth - border_compensation + 2

	Gui, %GUI_name%: Font, % "s" fSize2 - 3 " cWhite", % vars.system.font
	Gui, %GUI_name%: Add, Text, % "w" dragWidth " Border Center 0x200 BackgroundTrans gCurrencyCounter_Logs2 HWNDhwnd_drag", % "Currency Counter Viewer"
	vars.hwnd.cc_logs.dragbar := hwnd_drag

	Gui, %GUI_name%: Add, Text, % "x" totalWidth - closeWidth - border_compensation " y-1 w" closeWidth " Border Center 0x200 gCurrencyCounter_Logs2 HWNDhwnd_close", % "x"
	vars.hwnd.cc_logs.close := hwnd_close

	; ══════════════════════════════════════════════════════════
	;  SESSION TABS
	; ══════════════════════════════════════════════════════════
	Gui, %GUI_name%: Font, % "s" fSize2 - 2, % vars.system.font
	Gui, %GUI_name%: Add, Text, x0 y+10 Section Hidden ; invisible anchor
	active_id := settings.currency_counter.active

	settings.currency_counter.spacing := 10 ;TODO: actually make it in setting with clamp
	settings.currency_counter.visibleCount := ssf ? 2 : 4 ;TODO: actually make it in setting with clamp

	visibleCount := settings.currency_counter.visibleCount
	spacing := settings.currency_counter.spacing
	if(Blank(vars.currency_counter.carousel_index))
		vars.currency_counter.carousel_index := 0

	newSessionButtonWidth := hFont * 2
	itemWidth := (totalWidth - newSessionButtonWidth - (visibleCount + 2) * spacing) / visibleCount
	itemHeight := hFont
	picWidth := itemWidth ; Adjust this ratio as needed
	gap := 5
	firstItemAdded := false

	Loop % visibleCount {
		idx := A_Index
		xPos := (idx-1)*(itemWidth + spacing)

		; Picture: left side                   ; top aligned within the element
		picH := itemHeight - 2 ; a little smaller to avoid edge clipping

		; Text: right side, vertically centered
		txtX := xPos + picWidth + gap
		txtW := itemWidth - picWidth - gap

		yOpt := !firstItemAdded ? "ys" : "yp"

		For key, val in settings.currency_counter.sessions
		{
			if(A_Index <= vars.currency_counter.carousel_index)
				continue
			if(A_Index > vars.currency_counter.carousel_index + visibleCount)
				break

			slotNum := A_Index - vars.currency_counter.carousel_index
			xPos := spacing + (slotNum - 1) * (itemWidth + spacing)
			yOpt := (slotNum = 1) ? "ys" : "yp"

			isActive := (key = settings.currency_counter.active)
			textColor := isActive ? " cBlack" : " cWhite"
			bgColor := isActive ? "White" : "1A1A1A"

			if(!Blank(val.img))
			{
				Gui, %GUI_name%: Add, Text, % "x" xPos " " yOpt " w" itemWidth " h" itemHeight " Border Center 0x200 BackgroundTrans", % val.name
				Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled Background" bgColor " HWNDhwnd", 0
				vars.hwnd.cc_logs["tab_" key] := hwnd
			}
			Else
			{
				Gui, %GUI_name%: Font, % "s" fSize2 - 2 (isActive ? " cBlack" : " cWhite"), % vars.system.font
				Gui, %GUI_name%: Add, Text, % "x" xPos " " yOpt " w" itemWidth " h" itemHeight " Border Center 0x200 BackgroundTrans", % val.name
				Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled Background" bgColor " HWNDhwnd", 0
				vars.hwnd.cc_logs["tab_" key] := hwnd ; store Progress hwnd, hotkey sends cMouse which will match it
				Gui, %GUI_name%: Font, % "s" fSize2 - 2 " cWhite", % vars.system.font
			}
		}
	}

	Gui, %GUI_name%: Font, % "s" fSize2 * 3 " c41BB1C", % vars.system.font
	Gui, %GUI_name%: Add, Text, % "yp x" totalWidth - newSessionButtonWidth - spacing " w" newSessionButtonWidth " h" itemHeight " Border Center 0x200 gCurrencyCounter_Logs2 HWNDhwnd", % " + "
	Gui, %GUI_name%: Font, % "s" fSize2 " cWhite", % vars.system.font
	vars.hwnd.cc_logs.add_session := hwnd

	; ══════════════════════════════════════════════════════════
	;  INFO BAR  – image | session label | name edit | delete | spacer | currency picker (right-aligned)
	; ══════════════════════════════════════════════════════════
	Gui, %GUI_name%: Font, % "s" fSize2 " cWhite", % vars.system.font

	; Hidden anchor to measure hEdit for the whole info bar row
	Gui, %GUI_name%: Add, Text, % "xs Section BackgroundTrans Hidden Border HWNDhwnd x-1 y+-1 w" fHeight2, % " "
	ControlGetPos,, yEdit,, hEdit,, % "ahk_id " hwnd

	; Hidden default button (keeps Enter key behaviour)
	Gui, %GUI_name%: Add, Button, % "xp yp wp hp Hidden Default gCurrencyCounter_Logs2 HWNDhwnd_defbtn", ok
	vars.hwnd.cc_logs.filter_button := hwnd_defbtn

	imgSize := fHeight2
	; ── "Session:" label (also larger, clearly visible) ───────
	labelWidth := fWidth2 * 8
	Gui, %GUI_name%: Add, Text, % "xs Section y+0 Border 0x200 Center BackgroundTrans cWhite w" labelWidth " h" imgSize, % "Session:"

	; ── Session image (larger) ─────────────────────────────────
	Gui, %GUI_name%: Add, Text, % "ys yp Border 0x200 Center c404040 w" imgSize " h" imgSize, % "IMG"
	Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled Background1A1A1A HWNDhwnd", 0
	vars.hwnd.cc_logs.session_img := hwnd

	; ── Name edit field ───────────────────────────────────────
	editWidth := fWidth2 * 16
	Gui, %GUI_name%: Add, Edit, % "ys yp cBlack gCurrencyCounter_Logs2 HWNDhwnd_name_edit w" editWidth " h" imgSize, % vars.currency_counter.session_name
	vars.hwnd.cc_logs.name_edit := hwnd_name_edit

	; ── Accept button (X) with progress bar ───────────────────
	accSize := imgSize
	Gui, %GUI_name%: Add, Text, % "ys yp Border 0x200 Center c41BB1C w" accSize " h" accSize, % " + "
	Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled BackgroundBlack cRed HWNDhwnd range0-500", 0
	vars.hwnd.cc_logs.accept_prog := hwnd

	; ── Delete button (X) with progress bar ───────────────────
	delSize := accSize / 2
	Gui, %GUI_name%: Add, Text, % "x+" delSize /2 " ys+" delSize /2 "yp Border 0x200 Center cCC3333 w" delSize " h" delSize, % "X"
	Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled BackgroundBlack cRed HWNDhwnd range0-500", 0
	vars.hwnd.cc_logs.del_prog := hwnd

	; ── Currency picker (only if not SSF) – placed at far right edge ──
	If !ssf
	{
		pickerWidth := totalColWidth
		; Absolute X coordinate: right edge minus picker width
		pickerX := totalWidth - pickerWidth - table.Count() + 1
		Gui, %GUI_name%: Add, Text, % "yp x" pickerX " Border 0x200 Center cC89B3C w" pickerWidth " h" imgSize, % " " CurrencyCounter_CurAbbr(settings.currency_counter.display_cur) " "
		Gui, %GUI_name%: Add, Progress, % "xp yp wp hp Border Disabled Background1A1A1A HWNDhwnd", 0
		vars.hwnd.cc_logs.display_cur_btn := hwnd
	}
	; ══════════════════════════════════════════════════════════
	;  TABLE  – search, headers, data rows
	; ══════════════════════════════════════════════════════════

	row_count := Min(entries.Count(), max_lines)

	For col_i, val in table
	{
		header := val.1
		LLK_PanelDimensions(val.3, fSize2, width, height,, 4)
		width := (width < hFont) ? hFont : width

		Gui, %GUI_name%: Font, % "s" fSize2

		; ── Search / spacer row (above header) ──────────────────
		; col 1:     "Search" + "X"  →  xs Section anchor
		; col total: "Total" label + icon placeholder (ys Section)
		; others:    blank spacer (ys Section)
		If (col_i = 1)
		{
			; Hidden dummy to measure hEdit for the whole table
			Gui, %GUI_name%: Add, Text, % "Section xs BackgroundTrans Hidden Border HWNDhwnd x-1 y+0 w" width, % " "
			ControlGetPos,, yEdit,, hEdit,, % "ahk_id " hwnd

			; Search Edit (Section anchor for col 1) + X reset flush right
			; Search Edit (Section anchor for col 1) + X reset flush right
			Gui, %GUI_name%: Add, Edit, % "xs+1 Section cBlack gCurrencyCounter_Logs2 HWNDhwnd_search w" width - hEdit " h" hEdit (!Blank(pCheck := vars.cc_logs.keywords["name"]) ? " cGreen" : ""), % pCheck
			vars.hwnd.cc_logs.search_name := hwnd_search
			Gui, %GUI_name%: Add, Text, % "ys Border BackgroundTrans Center gCurrencyCounter_Logs2 HWNDhwnd cRed 0x200 x+0 w" hEdit " h" hEdit, % "X"
			vars.hwnd.cc_logs.filter_reset := hwnd
		}
		Else If (header = "total")
		{
			; "Total" label in the spacer row – IS the Section anchor (ys Section).
			; Width covers just the value column; icon is placed separately after.
			Gui, %GUI_name%: Add, Text, % "ys Section BackgroundTrans Border w" width " h" hEdit " Center cWhite", % "Total "
		}
		Else
		{
			; Blank spacer IS the Section anchor for this column
			Gui, %GUI_name%: Add, Text, % "ys Section BackgroundTrans Border w" width " h" hEdit, % " "
		}

		; ── Header label: xs y+-1 snaps to column anchor ────────
		; For "total": show computed value instead of column name.
		Gui, %GUI_name%: Font, % "s" fSize2 + 4
		If (header = "total")
		{
			Gui, %GUI_name%: Add, Text, % "xs y+-1 BackgroundTrans Border Center HWNDhwnd cC89B3C w" width, % CurrencyCounter_ComputeTotal()
			Gui, %GUI_name%: Add, Text, % "xs y+-1 BackgroundTrans Hidden HWNDhwnd w1 h1", % ""
			vars.hwnd.cc_logs.total_value := hwnd
		}
		Else
		{
			Gui, %GUI_name%: Font, % "s" fSize2 - 2
			Gui, %GUI_name%: Add, Text, % "xs y+-1 BackgroundTrans Hidden HWNDhwnd w" width, % val.3.1
			ControlGetPos,,, , textH,, % "ahk_id " hwnd
			offset := Floor((fHeight3 - textH) / 2)
			Gui, %GUI_name%: Add, Text, % "xp yp Border BackgroundTrans HWNDhwnd_border wp h" fHeight3, % ""
			Gui, %GUI_name%: Add, Text, % "xp yp+" offset " BackgroundTrans Center 0x200 HWNDhwnd_col w" width, % val.3.1
			Gui, %GUI_name%: Add, Progress, % "xp yp-" offset " wp h" fHeight3 " Disabled BackgroundBlack HWNDhwnd", 0
			Gui, %GUI_name%: Font, % "s" fSize2 + 4
		}
		vars.hwnd.cc_logs["col_" header] := hwnd_col

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
				cell_text := entry.count " ", color := "", gLabel := " gCurrencyCounter_Logs2"
			Else If (header = "price")
				cell_text := (entry.price != "") ? CurrencyCounter_FormatPrice(entry.price) : "—" . " ", color := " c" CurrencyCounter_PriceColor(entry.price_updated), gLabel := " gCurrencyCounter_Logs2"
			Else If (header = "pc")
				cell_text := " " CurrencyCounter_CurAbbr(entry.price_currency) " ", color := " c808080", gLabel := " gCurrencyCounter_Logs2"
			Else If (header = "ts")
				cell_text := CurrencyCounter_FormatAge(entry.price_updated) " ", color := " c" CurrencyCounter_PriceColor(entry.price_updated), gLabel := " gCurrencyCounter_Logs2"
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

			Gui, %GUI_name%: Add, Text, % "xs Border 0x200 BackgroundTrans " val.2 " w" width . gLabel . color " h" hFont, % cell_text
			Gui, %GUI_name%: Add, Progress, % "xp yp w" width " hp Border Disabled Background" bg " HWNDhwnd0 ", 0
			vars.hwnd.cc_logs[header "_" name] := hwnd0
		}

		; Empty-state row (first column only)
		If (col_i = 1) && !entries.Count()
		{
			Gui, %GUI_name%: Font, % "s" fSize2 " c404040", % vars.system.font
			Gui, %GUI_name%: Add, Text, % "xs y+0 BackgroundTrans w" width " h" hFont " 0x200", % " No currencies used in this session."
		}
	}

	; ── Position & show ──────────────────────────────────────
	showPos := (vars.cc_logs.x != "") ? "x" vars.cc_logs.x " y" vars.cc_logs.y : "xCenter yCenter"
	Gui, %GUI_name%: Show, % showPos " AutoSize", % "Currency Counter"
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
		id := settings.currency_counter.active
		If !IsObject(settings.currency_counter.sessions[id])
			settings.currency_counter.sessions[id] := {img: "", name: input}
		Else
			settings.currency_counter.sessions[id].name := input
		vars.currency_counter.session_name := input
		CurrencyCounter_SaveIndex()
		Return
	}

	If (cHWND = vars.hwnd.cc_logs.search_name)
	{
		input := LLK_ControlGet(cHWND)
		vars.cc_logs.keywords["name"] := input
		GuiControl, % "+cBlack", % cHWND
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
			vars.cc_logs.x := xPos, vars.cc_logs.y := yPos, vars.general.drag := 0
			IniWrite, % xPos, % "ini" vars.poe_version "\currency-counter.ini", settings, logs-x
			IniWrite, % yPos, % "ini" vars.poe_version "\currency-counter.ini", settings, logs-y
			Return
		}
		Return

	Case "filter_button":
		CurrencyCounter_Logs()
		Return

	Case "display_cur_btn", "total_value":
		KeyWait, LButton
		order := ["chaos", "divine", "exalt"]
		cur := settings.currency_counter.display_cur
		next := order[2] ; default if cur not found
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

	If InStr(check, "pc_")
	{
		name := SubStr(check, 4)
		order := ["chaos", "divine", "exalt"]
		cur := vars.currency_counter.currencies[name].price_currency
		next := order[1]
		Loop, % order.Count()
			If (order[A_Index] = cur)
			{
				next := order[Mod(A_Index, order.Count()) + 1]
				Break
			}
		vars.currency_counter.currencies[name].price_currency := next
		CurrencyCounter_SaveCurrency(name)
		CurrencyCounter_Logs()
		Return
	}

	If InStr(check, "col_")
	{
		col := SubStr(check, 5)
		If (vars.cc_logs.sort_col = col)
			vars.cc_logs.sort_asc := !vars.cc_logs.sort_asc
		Else
		{
			vars.cc_logs.sort_col := col
			vars.cc_logs.sort_asc := 1
		}
		CurrencyCounter_Logs()
		Return
	}
}

; ──────────────────────────────────────────────────────────────
;  CurrencyCounter_CurPicker  –  3-icon currency selector
;  Appears at the icon position, one row above the table.
;  Clicking any option sets display_cur and closes itself.
;  Wire: already handled via "display_cur_icon" in Logs2.
; ──────────────────────────────────────────────────────────────
CurrencyCounter_CurPicker(cHWND)
{
	local
	global vars, settings
	static toggle := 0

	; Options: id, label shown in picker
	options := [["chaos", "c"], ["divine", "d"], ["exalt", "e"]]

	fSize2 := settings.currency_counter.fSize2
	LLK_FontDimensions(fSize2, fHeight2, fWidth2)
	hFont := fHeight2 * 1.5

	; Get icon position in client-area coords, then add parent GUI screen pos
	ControlGetPos, cx, cy, cw,, % "ahk_id " cHWND
	WinGetPos, gx, gy,,, % "ahk_id " vars.hwnd.cc_logs.main
	px := gx + cx + cw // 2 ; horizontal centre of icon (for centring the picker over it)
	py := gy + cy ; top edge of icon in screen coords

	toggle := !toggle, pName := "cc_cur_picker" toggle
	Gui, %pName%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +Border +E0x02000000 +E0x00080000 HWNDhwnd_picker"
	Gui, %pName%: Color, Black
	Gui, %pName%: Margin, -1, -1
	Gui, %pName%: Font, % "s" fSize2 + 4 " cWhite", % vars.system.font
	vars.hwnd.cc_cur_picker := {"main": hwnd_picker}

	; 3 icon cells side by side, same size as the icon (hFont*2 square)
	icon_side := hFont * 2
	For i, opt in options
	{
		id := opt.1
		label := opt.2
		color := (id = settings.currency_counter.display_cur) ? " cLime" : " cC89B3C"
		pos := (i = 1) ? "Section xs" : "ys"

		; Pic when assets exist; Text placeholder for now
		; Swap this line for: Gui, %pName%: Add, Pic, ...
		Gui, %pName%: Add, Text, % pos " Border BackgroundTrans Center gCurrencyCounter_CurPickerClick HWNDhwnd 0x200" color " w" icon_side " h" icon_side, % label
		vars.hwnd.cc_cur_picker["opt_" id] := hwnd
		Gui, %pName%: Add, Progress, % "xp yp wp hp Border Disabled Background1A1A1A HWNDhwnd", 0
	}

	; Show flush with the top of the icon, horizontally centred on it
	Gui, %pName%: Show, % "NA x10000 y10000"
	WinGetPos,,, pw,, % "ahk_id " hwnd_picker
	; Centre picker horizontally on the icon, place just above it.
	; Subtract 1 to compensate for the -1 GUI margin (border sits outside client area).
	Gui, %pName%: Show, % "NA x" px - pw // 2 " y" py - icon_side - 1
	LLK_Overlay(hwnd_picker, "show", 0, pName)
}

CurrencyCounter_CurPickerClick()
{
	local
	global vars, settings

	cHWND := A_GuiControl ; hwnd of the clicked Text control
	check := LLK_HasVal(vars.hwnd.cc_cur_picker, cHWND)
	If !InStr(check, "opt_")
		Return
	KeyWait, LButton
	chosen := SubStr(check, 5) ; strip "opt_"
	settings.currency_counter.display_cur := chosen
	IniWrite, % chosen, % "ini" vars.poe_version "\currency-counter.ini", settings, display-currency
	LLK_Overlay(vars.hwnd.cc_cur_picker.main, "destroy")
	vars.hwnd.cc_cur_picker := {"main": ""}
	CurrencyCounter_Logs()
	Return
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
	Gui, %eName%: Font, % "s" settings.currency_counter.fSize2 " cBlack", % vars.system.font

	; Determine initial display value: convert decimal to fraction (if price exists)
	initialText := ""
	if (entry.price != "" && IsNumber(entry.price))
		initialText := CurrencyCounter_DecimalToFraction(entry.price + 0)
	else
		initialText := ""

	Gui, %eName%: Add, Edit, % "w" wCtrl - 2 " h" hCtrl - 2 " Background202020 HWNDhwnd_input", % initialText
	Gui, %eName%: Add, Button, % "Default Hidden gCurrencyCounter_PriceEditSave HWNDhwnd_ok", ok
	vars.hwnd.cc_price_edit := {"main": hwnd_edit, "input": hwnd_input, "name": currency_name}
	Gui, %eName%: Show, % "NA x" xCtrl " y" yCtrl
	ControlFocus,, % "ahk_id " hwnd_input
	; Select all text for easy replacement
	ControlSend,, ^{a}, % "ahk_id " hwnd_input

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
	raw := Trim(raw)

	; Check for fraction format "XX/YY"
	If InStr(raw, "/")
	{
		; Split numerator and denominator
		parts := StrSplit(raw, "/")
		If (parts.Length() = 2)
		{
			num := Trim(parts[1])
			den := Trim(parts[2])
			; Both must be numbers and denominator > 0
			If IsNumber(num) && IsNumber(den) && (num + 0 > 0)
			{
				price := (den + 0) / (num + 0)
				If (price >= 0)
				{
					vars.currency_counter.currencies[cname].price := price
					vars.currency_counter.currencies[cname].price_updated := A_Now
					CurrencyCounter_SaveCurrency(cname)
				}
			}
		}
	}
	Else ; Decimal format
	{
		If IsNumber(raw) && (raw + 0 >= 0)
		{
			vars.currency_counter.currencies[cname].price := raw + 0
			vars.currency_counter.currencies[cname].price_updated := A_Now
			CurrencyCounter_SaveCurrency(cname)
		}
	}

	vars.hwnd.cc_price_edit := {"main": "", "input": "", "name": ""}
	CurrencyCounter_DrawBar()
	CurrencyCounter_Logs()
}

; Convert decimal to closest fraction XX/YY with denominator up to maxDenom (default 100)
CurrencyCounter_DecimalToFraction(decimal, maxDenom := 100)
{
	if (decimal = 0)
		return "0/1"
	bestNum := 0, bestDenom := 1, bestError := Abs(decimal)
	Loop % maxDenom
	{
		denom := A_Index
		num := Round(decimal * denom)
		error := Abs(decimal - num/denom)
		if (error < bestError)
		{
			bestError := error
			bestNum := num
			bestDenom := denom
		}
	}
	; Simplify by GCD
	g := CurrencyCounter_GCD(bestNum, bestDenom)
	bestNum //= g
	bestDenom //= g
	return bestDenom "/" bestNum
}

CurrencyCounter_GCD(a, b)
{
	while b
		t := b, b := Mod(a, b), a := t
	return Abs(a)
}

; ──────────────────────────────────────────────────────────────
;  Helpers
; ──────────────────────────────────────────────────────────────
CurrencyCounter_PriceAgeHours(ts)
{
	local
	If !ts || !IsNumber(ts)
		Return 0
	diff := A_Now
	EnvSub, diff, % ts, minutes
	Return diff / 60
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

; Format a number to show at most 4 decimal places, removing trailing zeros
CurrencyCounter_FormatPrice(price)
{
	if (price = "")
		return ""
	; Round to 4 decimal places
	rounded := Round(price, 4)
	; Convert to string and trim trailing zeros and decimal point if needed
	str := rounded + 0.0 ; force numeric then string conversion
	; Remove trailing zeros after decimal
	if InStr(str, ".")
	{
		while SubStr(str, 0) = "0"
			str := SubStr(str, 1, -1)
		if SubStr(str, 0) = "."
			str := SubStr(str, 1, -1)
	}
	return str
}

CurrencyCounter_SortCount(asc, a, b)
{
	Return asc ? (a.entry.count - b.entry.count) : (b.entry.count - a.entry.count)
}

