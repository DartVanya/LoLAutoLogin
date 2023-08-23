class ToolTipFM
{
	static __WhichToolTip := 16, ScriptPID := DllCall("GetCurrentProcessId"), hModule := DllCall("GetModuleHandle", "UInt", 0, "Ptr")
	__New(xOffset=12, yOffset=12) {
		this.xOffset := xOffset, this.yOffset := yOffset, this.WhichToolTip := ToolTipFM.__WhichToolTip++
		if (ToolTipFM.__WhichToolTip > 20)
			return ""
		SysGet, VirtualScreenWidth, 78
		SysGet, VirtualScreenHeight, 79
		this.VirtualScreenWidth := VirtualScreenWidth, this.VirtualScreenHeight := VirtualScreenHeight
		, this.pCallBack := RegisterCallback("__LowLevelMouseProc",,, &this)
	}
	__Delete() {
		SetTimer % this, Off
		this._On := false, this.__ToolTipFM()
		DllCall("GlobalFree", "Ptr", this.pCallBack, "Ptr")
		return this.__SetHook(false)
	}
    Set(Text:="", Time:=2500, Title:="", Icon:=0) {
        this.Text := Text, this.Time := Time, this.Title := Title, this.hIcon := Icon, this._On := true
		this.__ToolTipFM()
		if (this.Time != 0)
			this.__SetHook()
		if (this.Time != -1 && this.Time != 0) {
			this.start_time := A_TickCount
			SetTimer % this, 50
		}
    }
	SetOffset(xOffset=12, yOffset=12) {
		this.xOffset := xOffset, this.yOffset := yOffset
	}
	SetUserProc(fn) {
		this.UserProc := IsObject(fn) ? fn : Func(fn)
	}
    Off() {
		if !this._On
			return
		SetTimer % this, Off
		this._On := false, this.__SetHook(false), this.__ToolTipFM()
		, this.Text := "", this.Title := "", this.hIcon := "", this.hfont := 0, this.bc := "", this.tc := ""
    }
	isOn() {
		return this._On
	}
    Call() {
		if (A_TickCount-this.start_time > this.Time) {
			SetTimer, , Off
			this._On := false, this.__SetHook(false), this.__ToolTipFM()
			, this.Text := "", this.Title := "", this.hIcon := "", this.hfont := 0, this.bc := "", this.tc := ""
		}
    }
	__ToolTipFM(x:="", y:="", ForceRenew:=false) { ; ToolTip which Follows the Mouse
		; http://www.autohotkey.com/forum/post-430240.html#430240
		static TTM_SETTITLE := 0x420 + !!A_IsUnicode

		if !this._On ; destroy tooltip
		{
			ToolTip,,,, % this.WhichToolTip
			this.hwnd := "", this.LastText := "", this.LastTitle := "", this.LastIcon := ""
			return
		}
		else ; move or recreate tooltip
		{
			if (x = "" || y = "") {
				VarSetCapacity(lpPoint, 8, 0)
				DllCall("GetCursorPos", "Ptr", &lpPoint)
				x := NumGet(lpPoint, 0, "Int"), y := NumGet(lpPoint, 4, "Int")
			}

			x += this.xOffset, y += this.yOffset
			WinGetPos,,,w,h, % "ahk_id " . this.hwnd

			; if necessary, adjust Tooltip position
			if ((x+w) > this.VirtualScreenWidth)
				AdjustX := 1
			if ((y+h) > this.VirtualScreenHeight)
				AdjustY := 1

			if (AdjustX and AdjustY)
				x := x - this.xOffset*2 - w, y := y - this.yOffset*2 - h
			else if AdjustX
				x := this.VirtualScreenWidth - w
			else if AdjustY
				y := this.VirtualScreenHeight - h
			if (!ForceRenew && this.Text = this.LastText && this.Title = this.LastTitle && this.hIcon = this.LastIcon) ; move tooltip
				DllCall("MoveWindow", "UPtr",this.hwnd,"Int",x,"Int",y,"Int",w,"Int",h,"Int",0)
			else ; recreate tooltip
			{
				; Perfect solution would be to update tooltip text (TTM_UPDATETIPTEXT), but must be compatible with all versions of AHK_L and AHK Basic.
				; My Ask For Help link: http://www.autohotkey.com/forum/post-421841.html#421841
				CoordMode, ToolTip, Screen
				;ToolTip,,,, % this.WhichToolTip ; destroy old
				ToolTip, % this.Text, x, y, % this.WhichToolTip ; show new
				if (!this.hwnd)
					this.hwnd := WinExist("ahk_class tooltips_class32 ahk_pid " ToolTipFM.ScriptPID)
				this.LastText := this.Text, this.LastTitle := this.Title, this.LastIcon := this.hIcon
				if (this.Title)
					DllCall("SendMessage", "UPtr", this.hwnd, "UInt", TTM_SETTITLE, "Ptr", this.hIcon, "Ptr", this.GetAddress("Title"))

				this.__SetFontColor()
				this.__ToolTipFM() 	; fix pos after apply Title and Font
			}
			Winset, AlwaysOnTop, on, % "ahk_id " . this.hwnd
		}
	}
	__SetHook(on := true) {  ; https://www.autohotkey.com/boards/viewtopic.php?p=286942#p286942
		static WH_MOUSE_LL := 14
		if !on
			DllCall("UnhookWindowsHookEx", "Ptr", this.hHook), this.hHook := false
		else if (!this.hHook)
			this.hHook := DllCall("SetWindowsHookEx", "Int", WH_MOUSE_LL, "Ptr", this.pCallBack
									, "Ptr", ToolTipFM.hModule, "UInt", 0, "Ptr")
	}

	; ToolTipOpt v1.004
	; Changes:
	;  v1.001 - Pass "Default" to restore a setting to default
	;  v1.002 - ANSI compatibility
	;  v1.003 - Added workarounds for ToolTip's parameter being overwritten
	;           by code within the message hook.
	;  v1.004 - Fixed text colour.

	Font(Options := "", Name := "") {
		this.hfont := Options="Default" ? 0 : ToolTipFM._TTG("Font", Options, Name)
		return this._On ? this.__ToolTipFM(,, true) : ""
	}
	Color(Background := 0xFFFFFF, Text := "") {
		if Background is integer
			this.bc := Background
		else
			this.bc := (Background="Default" || Background="") ? "" : ToolTipFM._TTG("Color", Background)
		if Text is integer
			this.tc := Text
		else
			this.tc := (Text="Default" || Text="") ? "" : ToolTipFM._TTG("Color", Text)
		return this._On ? this.__ToolTipFM(,, true) : ""
	}

	__SetFontColor() {
		static TTM_UPDATE := 0x41D, TTM_SETTIPBKCOLOR := 0x413, TTM_SETTIPTEXTCOLOR := 0x414, WM_SETFONT := 0x30
		VarSetCapacity(empty, 2, 0)
        DllCall("UxTheme.dll\SetWindowTheme", "UPtr", this.hwnd, "Ptr", 0, "Ptr", (this.bc != "" && this.tc != "") ? &empty : 0)
		if (this.bc != "")
			DllCall("SendMessage", "UPtr", this.hwnd, "UInt", TTM_SETTIPBKCOLOR, "UPtr", this.bc, "Ptr", 0)
		if (this.tc != "")
			DllCall("SendMessage", "UPtr", this.hwnd, "UInt", TTM_SETTIPTEXTCOLOR, "UPtr", this.tc, "Ptr", 0)
		if (this.hfont)
			DllCall("SendMessage", "UPtr", this.hwnd, "UInt", WM_SETFONT, "UPtr", this.hfont, "Ptr", 0)

		DllCall("SendMessage", "UPtr", this.hwnd, "UInt", TTM_UPDATE, "UPtr", 0, "Ptr", 0)
	}

	_TTG(Cmd, Arg1, Arg2 := "") {
		static htext := 0, hgui := 0
		if !htext {
			Gui _TTG: Add, Text, +hwndhtext
			Gui _TTG: +hwndhgui +0x40000000
		}
		Gui _TTG: %Cmd%, %Arg1%, %Arg2%
		if (Cmd = "Font") {
			GuiControl _TTG: Font, %htext%
			SendMessage 0x31, 0, 0,, ahk_id %htext%
			return ErrorLevel
		}
		if (Cmd = "Color") {
			hdc := DllCall("GetDC", "Ptr", htext, "Ptr")
			SendMessage 0x138, hdc, htext,, ahk_id %hgui%
			clr := DllCall("GetBkColor", "Ptr", hdc, "UInt")
			DllCall("ReleaseDC", "Ptr", htext, "Ptr", hdc)
			return clr
		}
	}
}

__LowLevelMouseProc(nCode, wParam, lParam) {
    static WM_MOUSEMOVE := 0x200
	Critical 999
	ToolTipFM := Object(A_EventInfo)
	if (wParam = WM_MOUSEMOVE)
		ToolTipFM.__ToolTipFM(NumGet(lParam+0, "Int"), NumGet(lParam+4, "Int"))
	if (ToolTipFM.UserProc)
		ToolTipFM.UserProc.Call(wParam, lParam)
    Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
}
