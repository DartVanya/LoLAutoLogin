class TrayPopUp {
    static uTaskbarRestart := DllCall("RegisterWindowMessage", "Str", "TaskbarCreated"), OSWin11 := VerCompare(A_OSVersion, ">=10.0.22000")
            , WM_NCACTIVATE := 0x086
    __New(hWnd, CloseDelay := 450, Margin := 0, AnimSpeed := 0, uId:=0x404) {
        this.timer := ObjBindMethod(this, "TryHide"), this.timerW11 := ObjBindMethod(this, "ShowPopUp", false, false)
        this.SelectGui(hWnd), this.uId := uId, this.CloseDelay := CloseDelay, this.AnimSpeed := AnimSpeed, this.Margin := Margin
        TrayIcon_SetVersion4(A_ScriptHwnd, this.uId), TrayIcon_Set(A_ScriptHwnd, this.uId, "")
        OnMessage(this.uId, this), OnMessage(this.uTaskbarRestart, this), OnMessage(this.WM_NCACTIVATE, this)
    }
    Disable(bDisable:=true) {
        timer := this.timer, this.POPUPCLOSE := false
        SetTimer, % timer, Off
        OnMessage(this.uId, this, !bDisable), OnMessage(this.WM_NCACTIVATE, this, !bDisable), OnMessage(this.uTaskbarRestart, this, !bDisable) 
        return ResetIcon && TrayIcon_SetVersion4(A_ScriptHwnd, this.uId, bDisable)
    }
	onShow(UserFN) {
		this.ShowHandler := IsObject(UserFN) ? UserFN : Func(UserFN)
	}
	onHide(UserFN) {
		this.HideHandler := IsObject(UserFN) ? UserFN : Func(UserFN)
	}
    SelectGui(hWnd) {
        timer := this.timer, this.POPUPCLOSE := false
        SetTimer, % timer, Off
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
        switch msg
        {
        case this.uId:
        {
            switch (lparam & 0xFFFF)
            {
            case NIN_POPUPOPEN:
                this.POPUPCLOSE := false
                if (this.OSWin11) {
                    timer := this.timerW11
                    SetTimer, % timer, % -this.CloseDelay
                }
                else
                    this.ShowPopUp()
                return true
            case NIN_POPUPCLOSE:
                this.POPUPCLOSE := true, this.SetCloseTimer()
                return true
            case WM.MOUSEMOVE:
                goto, ReTranslateMsg
            Default:
                this.POPUPCLOSE := true
            }
            ReTranslateMsg:
            return DllCall("SendMessage", "UPtr", hwnd, "UInt", msg, "UPtr", (lparam >> 16) & 0xFFFF, "Ptr", lparam & 0xFFFF)
        }
        case this.WM_NCACTIVATE:
            if (hwnd = this.HWND && !wParam) {
                this.POPUPCLOSE := true, timer := this.timer
                SetTimer, % timer, -100
            }
            return true
        case this.uTaskbarRestart:
            Sleep, 0
            return TrayIcon_SetVersion4(A_ScriptHwnd, this.uId)
        }
    }
    ShowPopUp(vActivate:=false, vManual:=false) {
        if (this.POPUPCLOSE &= !vActivate)
            return
        if this.GuiOff
            return this.ShowHandler && this.ShowHandler()
        this.activeMonitorInfo()
        IconRect := TrayIcon_GetRect(A_ScriptHwnd, this.uId)
        WinGetPos, panelX, panelY, panelWidth, panelHeight, ahk_class Shell_TrayWnd
        ; Shell_NotifyIconGetRect для скрытых иконок в Windows 11 был успешно сломан МС и возвращает неизвестный бред
        if (this.OSWin11 && IconRect.Y > this.monitorHeight) {  ; По известной лишь МС причине, если иконка скрыта, то её Y-координата больше высоты монитора
            ControlGetPos, W11TrayX, W11TrayY, , , TrayNotifyWnd1, ahk_class Shell_TrayWnd
            IconRect.X := W11TrayX + panelX, IconRect.Y := W11TrayY + panelY, IconRect.W -= 10
        }
        if (panelWidth = this.monitorWidth) {
            X := IconRect.X + IconRect.W//2 - this.W//2
            switch (panelY) {
                case this.monitorY: Y := IconRect.Y + IconRect.H + this.Margin
                                    , this.flag_show := 0x4, this.flag_hide := 0x8
                Default:            Y := IconRect.Y - this.H - this.Margin + 3 - this.OSWin11*8
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
        if (!vActivate || vManual)
            this.SetCloseTimer(), this.POPUPCLOSE := vManual
    }
    SetCloseTimer() {
        if this.GuiOff
            return this.HideHandler && this.HideHandler()
        if WinExist("ahk_id" this.HWND) {
            timer := this.timer
            SetTimer, % timer, % this.CloseDelay
        }
    }
    TryHide() {
        if (this.POPUPCLOSE && !WinActive("ahk_id" this.HWND) && !this.WinMouseOver()) {
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