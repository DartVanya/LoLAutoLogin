class TrayPopUp {
    static uTaskbarRestart := DllCall("RegisterWindowMessage", "Str", "TaskbarCreated")
    __New(hWnd, CloseDelay := 450, Margin := 0, AnimSpeed := 0, uId:=0x404) {
        this.SelectGui(hWnd), this.uId := uId, this.CloseDelay := CloseDelay, this.AnimSpeed := AnimSpeed, this.Margin := Margin
        this.timer := ObjBindMethod(this, "TryHide")
        this.onTaskbarRestart := Func("TrayIcon_SetVersion4").Bind(A_ScriptHwnd, this.uId)
        TrayIcon_SetVersion4(A_ScriptHwnd, this.uId)
        OnMessage(this.uId, this), OnMessage(this.uTaskbarRestart, this)
    }
    Disable(bDisable:=true) {
        OnMessage(this.uId, this, !bDisable), OnMessage(this.uTaskbarRestart, this, bDisable ? 0 : 1)
        return TrayIcon_SetVersion4(A_ScriptHwnd, this.uId, bDisable)
    }
	onShow(UserFN) {
		this.ShowHandler := IsObject(UserFN) ? UserFN : Func(UserFN)
	}
	onHide(UserFN) {
		this.HideHandler := IsObject(UserFN) ? UserFN : Func(UserFN)
	}
    SelectGui(hWnd) {
        Gui %hWnd%: +LastFound +AlwaysOnTop +Owner
		Gui %hWnd%: Show, Hide
        WinGetPos, x, y, w, h
        this.X := x, this.Y := y, this.W := w, this.H := h, this.HWND := hWnd
    }
    SuspendGui(bSuspend:=true) {
        this.GuiOff := bSuspend
    }
    Call(wParam, lParam, msg, hwnd) {
        static NIN_POPUPOPEN := 0x406, NIN_POPUPCLOSE := 0x407
        switch (lparam & 0xFFFF)
        {
            case NIN_POPUPOPEN:
                this.ShowPopUp(, false)
            case NIN_POPUPCLOSE:
                this.SetCloseTimer()
			Default:
            if (msg = this.uTaskbarRestart) {
                timer := this.onTaskbarRestart
                SetTimer, % timer, -1
                return
            }
            DllCall("SendMessage", "UPtr", hwnd, "UInt", msg, "UPtr", (lparam >> 16) & 0xFFFF, "Ptr", lparam & 0xFFFF)
        }
    }
    ShowPopUp(vActivate:=false, vManual := true) {
        if this.GuiOff
            return this.ShowHandler && this.ShowHandler()
        this.activeMonitorInfo()
        IconRect := TrayIcon_GetRect(A_ScriptHwnd, this.uId)
        WinGetPos, panelX, panelY, panelWidth, panelHeight, ahk_class Shell_TrayWnd
        if (panelWidth = this.monitorWidth) {
            X := IconRect.X + IconRect.W//2 - this.W//2
            switch (panelY) {
                case this.monitorY: Y := IconRect.Y + IconRect.H + this.Margin
                                    , this.flag_show := 0x4, this.flag_hide := 0x8
                Default:            Y := IconRect.Y - this.H - this.Margin + 5
                                    , this.flag_show := 0x8, this.flag_hide := 0x4
            }
        }
        else if (panelHeight = this.monitorHeight) {
            Y := IconRect.Y + IconRect.H//2 - this.H//2
            switch (panelX) {
                case this.monitorX: X := IconRect.X + IconRect.W + this.Margin
                                    , this.flag_show := 0x1, this.flag_hide := 0x2
                Default:            X := IconRect.X - this.W - this.Margin
                                    , this.flag_show := 0x2, this.flag_hide := 0x1
            }
        }
        if !(X && Y)
            return
        if (X + this.W > this.monitorWidth)
            X := this.monitorWidth - this.W - this.Margin
        ( this.ShowHandler && this.ShowHandler() )
        if this.AnimSpeed {
            Gui, % this.HWND ": Show", Hide x%X% y%Y%
            DllCall("AnimateWindow", "Ptr", this.HWND, "Int", this.AnimSpeed, "Int", 0x40000|this.flag_show)
        }
        Gui, % this.HWND ": Show", % (vActivate ? "" : "NA") "x" X " y" Y
        ( vManual && this.SetCloseTimer() )

    }
    SetCloseTimer() {
        if this.GuiOff
            return this.HideHandler && this.HideHandler()
        timer := this.timer
        SetTimer, % timer, % this.CloseDelay
    }
    TryHide() {
        if (!this.WinMouseOver() && !WinActive("ahk_id " this.HWND)) {
            SetTimer, , Off
            ( this.HideHandler && this.HideHandler() )
            if !this.AnimSpeed
                Gui, % this.HWND ": Hide"
            else
                DllCall("AnimateWindow", "Ptr", this.HWND, "Int", this.AnimSpeed, "Int", 0x10000|0x40000|this.flag_hide)
        }
    }
    WinMouseOver() {
        MouseGetPos,,, Win
        return (Win == this.HWND)
    }
    ; https://www.autohotkey.com/board/topic/111638-activemonitorinfo-get-monitor-resolution-and-origin-from-of-monitor-with-mouse-on/
    activeMonitorInfo()
    { ; retrieves the size of the monitor, the mouse is on
        MouseGetPos, mouseX , mouseY
        SysGet, monCount, MonitorCount
        Loop %monCount%
        { 	SysGet, curMon, Monitor, %A_Index%
            if ( mouseX >= curMonLeft && mouseX <= curMonRight && mouseY >= curMonTop && mouseY <= curMonBottom ) {
                return this.monitorX := curMonLeft, this.monitorY := curMonTop
                , this.monitorHeight := curMonBottom - curMonTop , this.monitorWidth  := curMonRight  - curMonLeft
            }
        }
    }
}

#Include <TrayIcon>