; ----------------------------------------------------------------------------------------------------------------------
; Name ..........: TrayIcon library
; Description ...: Provide some useful functions to deal with Tray icons.
; AHK Version ...: AHK_L 1.1.22.02 x32/64 Unicode
; Code from .....: Sean (http://www.autohotkey.com/forum/viewtopic.php?t=17314)
; Author ........: Cyruz (http://ciroprincipe.info) (http://ahkscript.org/boards/viewtopic.php?f=6&t=1229)
; Mod from ......: Fanatic Guru - Cyruz
; License .......: WTFPL - http://www.wtfpl.net/txt/copying/
; Version Date ..: 2019.03.12
; Upd.20160120 ..: Fanatic Guru - Went through all the data types in the DLL and NumGet and matched them up to MSDN
; ...............:                which fixed idCmd.
; Upd.20160308 ..: Fanatic Guru - Fix for Windows 10 NotifyIconOverflowWindow.
; Upd.20180313 ..: Fanatic Guru - Fix problem with "VirtualFreeEx" pointed out by nnnik.
; Upd.20180313 ..: Fanatic Guru - Additional fix for previous Windows 10 NotifyIconOverflowWindow fix breaking non
; ...............:                hidden icons.
; Upd.20190312 ..: Cyruz        - Added TrayIcon_Set, code merged and refactored.
; ----------------------------------------------------------------------------------------------------------------------


class WM {
    static MOUSEMOVE := 0x0200, LBUTTONDOWN := 0x0201, LBUTTONUP := 0x0202, LBUTTONDBLCLK := 0x0203, RBUTTONDOWN := 0x0204
    , RBUTTONUP := 0x0205, RBUTTONDBLCLK := 0x0206, MBUTTONDOWN := 0x0207, MBUTTONUP := 0x0208, MBUTTONDBLCLK := 0x0209
}

class TI_foos {
    static Shell_NotifyIcon := DllCall("Kernel32.dll\GetProcAddress", "Ptr", DllCall("Kernel32.dll\GetModuleHandle", "Str", "Shell32", "Ptr"), "AStr", "Shell_NotifyIcon" (A_IsUnicode ? "W" : "A"), "Ptr")
        , NOTIFYICONDATA_cbSize := A_PtrSize*5 + 40 + 448 * (A_IsUnicode ? 2 : 1)
        , uVersion_off := A_PtrSize*4 + 16 + 384 * (A_IsUnicode ? 2 : 1)
        , dwState_off := A_PtrSize*4 + 8 + 128 * (A_IsUnicode ? 2 : 1)
        , Shell_TrayWnd := TrayIcon_GetTrayBar(), NotifyIconOverflowWindow := TrayIcon_GetTrayBar("NotifyIconOverflowWindow")

    ParseParams(ByRef p, ByRef hWnd, ByRef uId, ByRef _1:="", ByRef _2:="", ByRef _3:="", ByRef _4:="", ByRef _5:="") {
        if (!(isO := IsObject(p[1])) && p.Length() < 2)
            return false
        hWnd := isO ? p[1].hWnd : p[1], uId := isO ? p[2-isO].uId : p[2-isO]
        for k, v in p {
            if (k <= 2-isO)
                continue
            i := k-2+isO, _%i% := v
        }
        return true
    }
    LoadIcon(ByRef hIcon) {
        if !hIcon
            return
        if hIcon is not integer
        {
            if !InStr(hIcon, "*")
                hIcon := LoadPicture(hIcon, , type)
            else {
                Loop, Parse, hIcon, *
                    ( A_Index = 1 ? Filename := A_LoopField : Icon := A_LoopField )
                hIcon := LoadPicture(Filename, "Icon" Icon, type)
            }
        }
        return hIcon
    }
}

; ----------------------------------------------------------------------------------------------------------------------
; Function ......: TrayIcon_GetInfo
; Description ...: Get a series of useful information about tray icons.
; Parameters ....: sExeName  - The exe for which we are searching the tray icon data. Leave it empty to receive data for
; ...............:             all tray icons.
; Return ........: oTrayInfo - An array of objects containing tray icons data. Any entry is structured like this:
; ...............:             oTrayInfo[A_Index].idx     - 0 based tray icon index.
; ...............:             oTrayInfo[A_Index].idcmd   - Command identifier associated with the button.
; ...............:             oTrayInfo[A_Index].pid     - Process ID.
; ...............:             oTrayInfo[A_Index].uid     - Application defined identifier for the icon.
; ...............:             oTrayInfo[A_Index].msgid   - Application defined callback message.
; ...............:             oTrayInfo[A_Index].hicon   - Handle to the tray icon.
; ...............:             oTrayInfo[A_Index].hwnd    - Window handle.
; ...............:             oTrayInfo[A_Index].class   - Window class.
; ...............:             oTrayInfo[A_Index].process - Process executable.
; ...............:             oTrayInfo[A_Index].tray    - Tray Type (Shell_TrayWnd or NotifyIconOverflowWindow).
; ...............:             oTrayInfo[A_Index].tooltip - Tray icon tooltip.
; Info ..........: TB_BUTTONCOUNT message - http://goo.gl/DVxpsg
; ...............: TB_GETBUTTON message   - http://goo.gl/2oiOsl
; ...............: TBBUTTON structure     - http://goo.gl/EIE21Z
; ----------------------------------------------------------------------------------------------------------------------


class TrayInfo {
    __New() {
        this.Shell_TrayWnd := [], this.NotifyIconOverflowWindow := []
    }
    _NewEnum() {
        this.oIcons := []
        for k, proc in this.Shell_TrayWnd
            for k, icon in proc
                    this.oIcons.Push(icon)
        for k, proc in this.NotifyIconOverflowWindow
            for k, icon in proc
                    this.oIcons.Push(icon)
        return this, this.first := true
    }
    Next(ByRef key, ByRef value) {
        ( this.first ? key := this.Remove("first") : ++key )
        if (key <= this.oIcons.Length())
            value := this.oIcons[key]
        else
            return !this.Remove("oIcons")
        return key != ""
    }
    __Get(aName) {
        if aName is integer
        {
            this._NewEnum()
            return this.oIcons[aName], this.Remove("oIcons"), this.Remove("first")
        }
    }
    __Call(name, sExeName:="", sTray:="") {
        if (!name) {
            this.oIcons := []
            if (!sTray || sTray = 1 || sTray = "Shell_TrayWnd")
                for k, proc in this.Shell_TrayWnd
                    for k, icon in proc
                        if (!sExeName || icon.process = sExeName)
                            this.oIcons.Push(icon)
            if (!sTray || sTray = 2 || sTray = "NotifyIconOverflowWindow")
                for k, proc in this.NotifyIconOverflowWindow
                    for k, icon in proc
                        if (!sExeName || icon.process = sExeName)
                            this.oIcons.Push(icon)
            return this, this.first := true
        }
        else if (this.first && name = "_NewEnum")
            return this
    }
}

TrayIcon_GetInfo(sExeName := "", s_uId := "", GetRect := false, bClient := false)
{
    d := A_DetectHiddenWindows
    DetectHiddenWindows, On

    oTrayInfo := new TrayInfo

    For key,sTray in ["Shell_TrayWnd", "NotifyIconOverflowWindow"]
    {
        idxTB := TI_foos[sTray]
        WinGet, pidTaskbar, PID, ahk_class %sTray%

        szBtn := VarSetCapacity(btn, (A_Is64bitOS ? 32 : 20), 0)
        szNfo := VarSetCapacity(nfo, (A_Is64bitOS ? 32 : 24), 0)
        szTip := VarSetCapacity(tip, 128*2, 0)

        hProc := DllCall("Kernel32.dll\OpenProcess",    "UInt",0x38, "Int",0, "UInt",pidTaskbar)
        pRB   := DllCall("Kernel32.dll\VirtualAllocEx", "Ptr",hProc, "Ptr",0, "UPtr",szBtn, "UInt",0x1000, "UInt",0x04)

        ; TB_BUTTONCOUNT = 0x0418
        SendMessage, 0x0418, 0, 0, ToolbarWindow32%idxTB%, ahk_class %sTray%
        Loop, %ErrorLevel%
        {
             ; TB_GETBUTTON 0x0417
            SendMessage, 0x0417, A_Index-1, pRB, ToolbarWindow32%idxTB%, ahk_class %sTray%

            DllCall("Kernel32.dll\ReadProcessMemory", "Ptr",hProc, "Ptr",pRB, "Ptr",&btn, "UPtr",szBtn, "UPtr",0)

            iBitmap := NumGet(btn, 0, "Int")
            idCmd   := NumGet(btn, 4, "Int")
            fsState := NumGet(btn, 8, "UChar")
            fsStyle := NumGet(btn, 9, "UChar")
            dwData  := NumGet(btn, (A_Is64bitOS ? 16 : 12), "UPtr")
            iString := NumGet(btn, (A_Is64bitOS ? 24 : 16), "Ptr")

            DllCall("Kernel32.dll\ReadProcessMemory", "Ptr",hProc, "Ptr",dwData, "Ptr",&nfo, "UPtr",szNfo, "UPtr",0)

            hWnd  := NumGet(nfo, 0, "Ptr")
            uId   := NumGet(nfo, (A_Is64bitOS ?  8 :  4), "UInt")
            msgId := NumGet(nfo, (A_Is64bitOS ? 12 :  8), "UInt")
            hIcon := NumGet(nfo, (A_Is64bitOS ? 24 : 20), "Ptr")

            WinGet, nPid, PID, ahk_id %hWnd%
            WinGet, sProcess, ProcessName, ahk_id %hWnd%
            WinGetClass, sClass, ahk_id %hWnd%

            if (sExeName = hWnd && s_uId = uId)
            {
                DllCall("Kernel32.dll\ReadProcessMemory", "Ptr",hProc, "Ptr",iString, "Ptr",&tip, "UPtr",szTip, "UPtr",0)
                oTrayInfo :=   { "idx"     : A_Index-1
                               , "idcmd"   : idCmd
                               , "pid"     : nPid
                               , "uid"     : uId
                               , "msgid"   : msgId
                               , "hicon"   : hIcon
                               , "hwnd"    : hWnd
                               , "class"   : sClass
                               , "process" : sProcess
                               , "tooltip" : StrGet(&tip, "UTF-16")
                               , "tray"    : sTray
                               , "hidden"  : (fsState & 0x8 ? true : false)} ; TBSTATE_HIDDEN := 0x8
                ( GetRect && oTrayInfo.IconRect := TrayIcon_GetRect(hWnd, uId, bClient) )
                break, 2
            }

            If ( !sExeName || sExeName = sProcess || sExeName = nPid )
            {
                ( !oTrayInfo[sTray].HasKey(sProcess) && oTrayInfo[sTray][sProcess] := [] )
                DllCall("Kernel32.dll\ReadProcessMemory", "Ptr",hProc, "Ptr",iString, "Ptr",&tip, "UPtr",szTip, "UPtr",0)
                iconIndex := oTrayInfo[sTray][sProcess].Push( { "idx"     : A_Index-1
                                                 , "idcmd"   : idCmd
                                                 , "pid"     : nPid
                                                 , "uid"     : uId
                                                 , "msgid"   : msgId
                                                 , "hicon"   : hIcon
                                                 , "hwnd"    : hWnd
                                                 , "class"   : sClass
                                                 , "process" : sProcess
                                                 , "tooltip" : StrGet(&tip, "UTF-16")
                                                 , "tray"    : sTray
                                                 , "hidden"  : (fsState & 0x8 ? true : false)} )  ; TBSTATE_HIDDEN := 0x8
                ( GetRect && oTrayInfo[sTray][sProcess][iconIndex].IconRect := TrayIcon_GetRect(hWnd, uId, bClient) )
            }

        }
        DllCall("Kernel32.dll\VirtualFreeEx", "Ptr",hProc, "Ptr",pRB, "UPtr",0, "UInt",0x8000)
        DllCall("Kernel32.dll\CloseHandle",   "Ptr",hProc)
    }
    DetectHiddenWindows, %d%
    Return oTrayInfo
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Hide
; Description ..: Hide or unhide a tray icon.
; Parameters ...: idCmd - Command identifier associated with the button.
; ..............: sTray - Place where to find the icon ("Shell_TrayWnd" or "NotifyIconOverflowWindow").
; ..............: bHide - True for hide, False for unhide.
; Info .........: TB_HIDEBUTTON message - http://goo.gl/oelsAa
; ----------------------------------------------------------------------------------------------------------------------

TrayIcon_Hide(p*)
{
    if !TI_foos.ParseParams(p, hWnd, uId, bHide)
        return false
    (!IsSet(bHide) && bHide := true)
    VarSetCapacity(NID, TI_foos.NOTIFYICONDATA_cbSize, 0)
    NumPut( TI_foos.NOTIFYICONDATA_cbSize, &NID, "UInt" )
    NumPut( hWnd,  &NID + A_PtrSize )
    NumPut( uId,   &NID + A_PtrSize*2, "UInt" )
    ; NIF_STATE  := 0x8
    NumPut( 0x8, &NID + A_PtrSize*2 + 4, "UInt" )
    ; NIS_HIDDEN := 0x1
    NumPut( (bHide ? 0x1 : 0), &NID + TI_foos.dwState_off, "UInt" )
    NumPut( 0x1, &NID + TI_foos.dwState_off + 4, "UInt" )
    ; NIM_MODIFY  := 0x1
    Return DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x1, "Ptr",&NID)
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Remove
; Description ..: Remove a Tray icon. It should be more reliable than TrayIcon_Delete.
; Parameters ...: hWnd - Window handle.
; ..............: uId  - Application defined identifier for the icon.
; Info .........: NOTIFYICONDATA structure  - https://goo.gl/1Xuw5r
; ..............: Shell_NotifyIcon function - https://goo.gl/tTSSBM
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Remove(p*)
{
    if !TI_foos.ParseParams(p, hWnd, uId)
        return false
    VarSetCapacity(NID, szNID := ( A_PtrSize*2 + 8), 0)
    NumPut( szNID, &NID, "UInt" )
    NumPut( hWnd,  &NID + A_PtrSize )
    NumPut( uId,   &NID + A_PtrSize*2, "UInt" )
    ; NIM_DELETE  := 0x2
    Return DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x2, "Ptr",&NID)
}

TrayIcon_Refresh(oIcons := "") {
    RemovedCnt := 0, VarSetCapacity(NID, szNID := ( A_PtrSize*2 + 8), 0), NumPut( szNID, &NID, "UInt" )
    for k, icon in (oIcons ? oIcons : TrayIcon_GetInfo())
        if (!icon.pid) {
            NumPut( icon.hWnd,  &NID + A_PtrSize ), NumPut( icon.uId,   &NID + A_PtrSize*2, "UInt" )
            RemovedCnt += DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x2, "Ptr",&NID)
        }
    return RemovedCnt
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Move
; Description ..: Move a tray icon.
; Parameters ...: idxOld - 0 based index of the tray icon to move.
; ..............: idxNew - 0 based index where to move the tray icon.
; ..............: sTray  - Place where to find the icon ("Shell_TrayWnd" or "NotifyIconOverflowWindow").
; Info .........: TB_MOVEBUTTON message - http://goo.gl/1F6wPw
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Move(idxOld, idxNew, sTray := "Shell_TrayWnd")
{
    d := A_DetectHiddenWindows
    DetectHiddenWindows, On
    if IsObject(idxOld)
        oIcon := TrayIcon_GetInfo(idxOld.hWnd, idxOld.uId), sTray := oIcon.tray, idxOld := oIcon.idx
    if oIcon.hidden
        return false
    if (idxNew < 0) {
        SendMessage, 0x0418, 0, 0, % "ToolbarWindow32" TI_foos[sTray], ahk_class %sTray%
        idxNew := ErrorLevel - (-idxNew-1)
    }
    SendMessage, 0x452, idxOld, idxNew, % "ToolbarWindow32" TI_foos[sTray], ahk_class %sTray% ; TB_MOVEBUTTON = 0x452
    DetectHiddenWindows, %d%
    return true
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Set
; Description ..: Modify icon with the given index for the given window.
; Parameters ...: hWnd       - Window handle.
; ..............: uId        - Application defined identifier for the icon.
; ..............: p[1] - szTip              - A null-terminated string that specifies the text for a standard tooltip.
; ..............:                             szTip can have a maximum of 128 characters, including the terminating null character.
; ..............:                             Specify "" to completely remove tooltip.
; ..............: p[2] - hIcon              - Handle to the tray icon. Optional.
; ..............: p[3] - hIconSmall         - Handle to the small icon, for window menubar. Optional.
; ..............: p[4] - hIconBig           - Handle to the big icon, for taskbar. Optional.
; ..............: p[5] - uCallbackMessage   - An application-defined message identifier. Optional.
; Return .......: True on success, false on failure.
; Info .........: NOTIFYICONDATA structure  - https://goo.gl/1Xuw5r
; ..............: Shell_NotifyIcon function - https://goo.gl/tTSSBM
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Set(p*)
{
    if !TI_foos.ParseParams(p, hWnd, uId, szTip, hIcon, hIconSmall, hIconBig, uCallbackMessage)
        return false
    TI_foos.LoadIcon(hIcon)

    ; WM_SETICON = 0x0080
    ( hIconSmall && DllCall("SendMessage", "UPtr", hWnd, "UInt", 0x0080, "UPtr", 0, "Ptr", hIconSmall) )
    ( hIconBig   && DllCall("SendMessage", "UPtr", hWnd, "UInt", 0x0080, "UPtr", 1, "Ptr", hIconBig) )

    ; NIF_MESSAGE := 0x1, NIF_ICON = 0x2, NIF_TIP = 0x4
    uFlags := (uCallbackMessage ? 0x1 : 0) | (hIcon ? 0x2 : 0) | (IsSet(szTip) ? 0x4 : 0)
    VarSetCapacity(NID, TI_foos.NOTIFYICONDATA_cbSize, 0)
    NumPut( TI_foos.NOTIFYICONDATA_cbSize, &NID, "UInt" )
    NumPut( hWnd,  &NID + A_PtrSize )
    NumPut( uId,   &NID + A_PtrSize*2, "UInt" )
    NumPut( uFlags,  &NID + A_PtrSize*2 + 4, "UInt" )
    ( uCallbackMessage && NumPut( uCallbackMessage, &NID + A_PtrSize*2 + 8, "UInt" ) )
    ( hIcon && NumPut( hIcon, &NID + A_PtrSize*3 + 8 ) )
    ; szTip[128]
    ( szTip && StrPut( SubStr(szTip, 1, 128-1), &NID + A_PtrSize*4 + 8, , (A_IsUnicode ? "UTF-16" : "CP0") ) )
    ; NIM_MODIFY := 0x1
    Return DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x1, "UPtr",&NID)
}

TrayIcon_SetVersion4(p*) {
    if !TI_foos.ParseParams(p, hWnd, uId, vDisable)
        return false
    VarSetCapacity(NID, TI_foos.NOTIFYICONDATA_cbSize, 0)
    NumPut( TI_foos.NOTIFYICONDATA_cbSize, &NID, "UInt")
    NumPut( hWnd,  &NID + A_PtrSize)
    NumPut( uId,   &NID + A_PtrSize*2, "UInt" )
    ; NOTIFYICON_VERSION_4 := 0x4
    NumPut( vDisable ? 0 : 0x4 , &NID + TI_foos.uVersion_off, "UInt" )
    ; NIM_SETVERSION  := 0x4
    return DllCall(TI_foos.Shell_NotifyIcon, "UInt",4, "UPtr",&NID)
}


TrayIcon_SetFocus(p*)
{
    static szNID := ( A_PtrSize*2 + 8)
    if !TI_foos.ParseParams(p, hWnd, uId)
        return false
    VarSetCapacity(NID, szNID, 0)
    NumPut( szNID, &NID, "UInt" )
    NumPut( hWnd,  &NID + A_PtrSize )
    NumPut( uId,   &NID + A_PtrSize*2, "UInt" )
    ; NIM_SETFOCUS  := 0x3
    Return DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x3, "UPtr",&NID)
}


; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_GetTrayBar
; Description ..: Get the tray icon handle.
; Parameters ...: sTray - Traybar to retrieve.
; Return .......: Tray icon handle.
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_GetTrayBar(sTray:="Shell_TrayWnd")
{
    d := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, ControlList, ControlList, ahk_class %sTray%
    RegExMatch(ControlList, "(?<=ToolbarWindow32)\d+(?!.*ToolbarWindow32)", nTB)
    Loop, %nTB%
    {
        ControlGet, hWnd, hWnd,, ToolbarWindow32%A_Index%, ahk_class %sTray%
        hParent := DllCall("GetParent", Ptr, hWnd)
        WinGetClass, sClass, ahk_id %hParent%
        If !(sClass == "SysPager" || sClass == "NotifyIconOverflowWindow" )
            Continue
        idxTB := A_Index
        Break
    }
    DetectHiddenWindows, %d%
    Return idxTB
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_GetHotItem
; Description ..: Get the index of tray's hot item.
; Return .......: Index of tray's hot item.
; Info .........: TB_GETHOTITEM message - http://goo.gl/g70qO2
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_GetHotItem(sTray:="Shell_TrayWnd")
{
    ( IsObject(sTray) && sTray := sTray.tray )
    d := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SendMessage, 0x0447, 0, 0, % "ToolbarWindow32" TI_foos[sTray], ahk_class %sTray% ; TB_GETHOTITEM = 0x0447
    DetectHiddenWindows, %d%
    Return ErrorLevel << 32 >> 32
}


TrayIcon_isHot(ByRef oTray)
{
    return (TrayIcon_GetHotItem(oTray) == oTray.idx)
}


; ----------------------------------------------------------------------------------------------------------------------
; Function .....: TrayIcon_Button
; Description ..: Simulate mouse button click on a tray icon.
; Parameters ...: sExeName - Executable Process Name of tray icon.
; ..............: sButton  - Mouse button to simulate (L, M, R).
; ..............: bDouble  - True to double click, false to single click.
; ..............: nIdx     - Index of tray icon to click if more than one match.
; ----------------------------------------------------------------------------------------------------------------------
TrayIcon_Button(sExeName, sButton:="L", bDouble:=False, nIdx:=1)
{
    if IsObject(sExeName)
        msgid := sExeName.msgid, uid := sExeName.uid, hwnd := sExeName.hwnd
    else {
        for k, icon in TrayIcon_GetInfo(sExeName)
            if (k = nIdx) {
                msgid := icon.msgid, uid := icon.uid, hwnd := icon.hwnd
                break
            }
    }
    If ( bDouble )
        return  DllCall("PostMessage", "UPtr", hwnd, "UInt", msgid, "UPtr", uid, "Ptr", WM[sButton "BUTTONDBLCLK"])
    Else
    {
                DllCall("PostMessage", "UPtr", hwnd, "UInt", msgid, "UPtr", uid, "Ptr", WM[sButton "BUTTONDOWN"])
        return  DllCall("PostMessage", "UPtr", hwnd, "UInt", msgid, "UPtr", uid, "Ptr", WM[sButton "BUTTONUP"])
    }
}

/* Function:	GetRect
 				Get tray icon rect.
   Parameters:
				Position	- Position of the tray icon. Use negative position to retreive client coordinates.
				x-h			- Refrence to outuptu variables, optional.

   Returns:
				String containing all outuput variables.
   Remarks:
				This function can be used to determine if tray icon is hidden. Such tray icons will have string "0 0 0 0" returned.
  */
TrayIcon_GetRect(p*)
{
    static szNI_id := A_PtrSize*3 + 16
    if !TI_foos.ParseParams(p, hWnd, uId, bClient)
        return false
	VarSetCapacity(RECT, 16)
	if (!bClient) {
        VarSetCapacity(NI_id, szNI_id, 0)
        NumPut( szNI_id, &NI_id, "UInt" )
        NumPut( hWnd,  &NI_id + A_PtrSize )
        NumPut( uId,   &NI_id + A_PtrSize*2, "UInt" )
        DllCall("Shell32.dll\Shell_NotifyIconGetRect", "UPtr",&NI_id, "UPtr",&RECT)
        x := NumGet(RECT, 0, "Int"), y := NumGet(RECT, 4, "Int"),  w := NumGet(RECT, 8, "Int") - x,  h := NumGet(RECT, 12, "Int") - y
        return {"X": x, "Y": y, "W": w, "H": h}
    }

	d := A_DetectHiddenWindows
    DetectHiddenWindows, On

    ( !IsObject(p[1]) && p[1] := TrayIcon_GetInfo(hWnd, uId) )

    ControlGet, tid, HWND, , % "ToolbarWindow32" TI_foos[p[1].tray], % "ahk_class " p[1].tray

	WinGet,	pidTaskbar, PID, % "ahk_class " p[1].tray
	hProc := DllCall("Kernel32.dll\OpenProcess", "Uint", 0x38, "Int", 0, "UInt", pidTaskbar)
	pProc := DllCall("Kernel32.dll\VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "UPtr", 16, "UInt", 0x1000, "UInt", 0x4)

    ; TB_GETITEMRECT := 0x41D
	SendMessage, 0x41D, p[1].idx, pProc, , ahk_id %tid%

	DllCall("Kernel32.dll\ReadProcessMemory", "Ptr", hProc, "Ptr", pProc, "Ptr", &RECT, "UPtr", 16, "UPtr", 0)
	x := NumGet(RECT, 0, "Int"), y := NumGet(RECT, 4, "Int"),  w := NumGet(RECT, 8, "Int") - x,  h := NumGet(RECT, 12, "Int") - y

	if !bClient {
		WinGetPos, xWin, yWin, , , % "ahk_class " p[1].tray
		ControlGetPos, xp, yp, , , % "ToolbarWindow32" TI_foos[p[1].tray], % "ahk_class " p[1].tray
		x+=xp+xWin, y+=yp+yWin
	}

    DllCall("Kernel32.dll\VirtualFreeEx", "Ptr",hProc, "Ptr",pProc, "UPtr",0, "UInt",0x8000)
    DllCall("Kernel32.dll\CloseHandle",   "Ptr",hProc)

	DetectHiddenWindows, %d%
	return {"X": x, "Y": y, "W": w, "H": h}
}



class ahkTrayIcon
{
    static iconCount := 0
    __New(uId, handler, MaxThreads, IconData) {
        this.uId := uId, this.MaxThreads := MaxThreads, IconData.uId := uId
        OnMessage(this.uId, this.handler := IsObject(handler) ? handler : Func(handler), MaxThreads)
        this.onTaskbarRestart := new this._onTaskbarRestart(IconData)
        ++ahkTrayIcon.iconCount
    }
    class _onTaskbarRestart {
        static uTaskbarRestart := DllCall("RegisterWindowMessage", "Str", "TaskbarCreated")
        __New(IconData) {
            this.IconData := IconData, OnMessage(this.uTaskbarRestart, this)
        }
        Call() {
            TrayIcon_Add("", this.IconData.hIcon, this.IconData.szTip
            , this.IconData.Version4, this.IconData.Hidden, , this.IconData.uId)
        }
        Disable() {
            OnMessage(this.uTaskbarRestart, this, 0)
        }
    }
    __Delete() {
        this.onTaskbarRestart.Disable(), OnMessage(this.uId, this.handler, 0)
        TrayIcon_Remove(A_ScriptHwnd, this.uId)
        --ahkTrayIcon.iconCount
    }
    SetTip(szTip) {
        return TrayIcon_Set(A_ScriptHwnd, this.uId, this.onTaskbarRestart.IconData.szTip := szTip)
    }
    SetIcon(hIcon) {
        return TrayIcon_Set(A_ScriptHwnd, this.uId, , this.onTaskbarRestart.IconData.hIcon := TI_foos.LoadIcon(hIcon))
    }
    Hide(bHide:=true) {
        return TrayIcon_Hide(A_ScriptHwnd, this.uId, this.onTaskbarRestart.IconData.Hidden := bHide)
    }
    Move(idxNew) {
        return TrayIcon_Move( {"hWnd" : A_ScriptHwnd, "uId" : this.uId}, idxNew )
    }
    Button(sButton:="L", bDouble:=False) {
        return TrayIcon_Button( {"hWnd" : A_ScriptHwnd, "uId" : this.uId, "msgid" : this.uId}, sButton, bDouble )
    }
    UpdateHandler(handler, MaxThreads:=1) {
        OnMessage(this.uId, this.handler, 0)
        OnMessage(this.uId, this.handler := IsObject(handler) ? handler : Func(handler), this.MaxThreads := MaxThreads)
    }
    SetFocus() {
        return TrayIcon_SetFocus(A_ScriptHwnd, this.uId)
    }
    SetVersion4(vDisable:=false) {
        return TrayIcon_SetVersion4(A_ScriptHwnd, this.uId, vDisable), this.onTaskbarRestart.IconData.Version4 := !vDisable
    }
    GetInfo(GetRect:=false) {
        return TrayIcon_GetInfo(A_ScriptHwnd, this.uId, GetRect)
    }
    GetRect(bClient:=false) {
        return TrayIcon_GetRect(A_ScriptHwnd, this.uId, bClient)
    }
    ToOverflow() {
        return TrayIcon_ToOverflow(this.GetInfo())
    }
    FromOverflow() {
        return TrayIcon_FromOverflow(this.GetInfo())
    }
    isHot() {
        return TrayIcon_isHot(this.GetInfo())
    }
}

TrayIcon_Add(Handler, hIcon:="", szTip:="", Version4:=false, bHidden:=false, MaxThreads:=1, s_uId:="")
{
    static uId
    if !ahkTrayIcon.iconCount
        uId := 0x500
    TI_foos.LoadIcon(hIcon)

    ; NIF_MESSAGE := 0x1, NIF_ICON = 0x2, NIF_TIP = 0x4, NIF_STATE  := 0x8
    uFlags := 0x1 | (hIcon ? 0x2 : 0) | (szTip ? 0x4 : 0) | (bHidden ? 0x8 : 0)
    VarSetCapacity(NID, TI_foos.NOTIFYICONDATA_cbSize, 0)
    NumPut( TI_foos.NOTIFYICONDATA_cbSize, &NID, "UInt" )
    NumPut( A_ScriptHwnd,  &NID + A_PtrSize )
    NumPut( s_uId ? s_uId : uId,   &NID + A_PtrSize*2, "UInt" )
    NumPut( uFlags, &NID + A_PtrSize*2 + 4, "UInt" )
    NumPut( s_uId ? s_uId : uId, &NID + A_PtrSize*2 + 8, "UInt" )
    ( hIcon && NumPut( hIcon, &NID + A_PtrSize*3 + 8 ) )
    ; szTip[128]
    ( szTip && StrPut( szTip:= SubStr(szTip, 1, 128-1), &NID + A_PtrSize*4 + 8, , (A_IsUnicode ? "UTF-16" : "CP0") ) )
    ; NIS_HIDDEN := 0x1
    if bHidden
        NumPut( 0x1, &NID + TI_foos.dwState_off, "UInt" ), NumPut( 0x1, &NID + TI_foos.dwState_off + 4, "UInt" )
    ; NIM_ADD  := 0x0
    DllCall(TI_foos.Shell_NotifyIcon, "UInt",0, "UPtr",&NID)
    if Version4 {
        ; NOTIFYICON_VERSION_4 := 0x4
        NumPut( 0x4, &NID + TI_foos.uVersion_off, "UInt" )
        ; NIM_SETVERSION  := 0x4
        DllCall(TI_foos.Shell_NotifyIcon, "UInt",0x4, "UPtr",&NID)
    }
    if !s_uId
        Return new ahkTrayIcon(uId++, Handler, MaxThreads, {"hIcon" : hIcon, "szTip" : szTip, "Version4" : Version4, "Hidden" : bHidden})
}

TrayIcon_FromOverflow(p*) {
	static delay := 50
    if !TI_foos.ParseParams(p, hWnd, uId)
        hWnd := A_ScriptHwnd, uId := 0x404
	( !IsObject(p[1]) && p[1] := TrayIcon_GetInfo(hWnd, uId) )
	if (p[1].tray == "Shell_TrayWnd" || p[1].hidden)
		return false
	d := A_DetectHiddenWindows, cm := A_CoordModeMouse
    DetectHiddenWindows, On
    CoordMode, Mouse, Screen
	IconLoc := TrayIcon_GetRect(p[1], true)
	MouseGetPos, xpos, ypos
	WinGetPos, taskbarWinX, taskbarWinY, taskbarWinW, taskbarWinH, ahk_class Shell_TrayWnd
	ControlGetPos, trayX, trayY, trayW, trayH, % "ToolbarWindow32" TI_foos.Shell_TrayWnd, ahk_class Shell_TrayWnd
	x := IconLoc.X + IconLoc.W//2
	y := IconLoc.Y + IconLoc.H//2
    SystemCursor(0)
    BlockInput, On
	PostMessage, WM.LBUTTONDOWN, 1, ((y<<16)^x), % "ToolbarWindow32" TI_foos.NotifyIconOverflowWindow, ahk_class NotifyIconOverflowWindow
	MouseMove, taskbarWinX+trayX+10, taskbarWinY+trayY+10, 0
	Sleep, %delay%
	PostMessage, WM.LBUTTONUP, 0, ((y<<16)^x), % "ToolbarWindow32" TI_foos.NotifyIconOverflowWindow, ahk_class NotifyIconOverflowWindow
	MouseMove, xpos, ypos, 0
    SystemCursor(1)
    BlockInput, Off
    CoordMode, Mouse, %cm%
	DetectHiddenWindows, %d%
    return true
}

TrayIcon_ToOverflow(p*) {
	static delay := 50
    if !TI_foos.ParseParams(p, hWnd, uId)
        hWnd := A_ScriptHwnd, uId := 0x404
	( !IsObject(p[1]) && p[1] := TrayIcon_GetInfo(hWnd, uId) )
	if (p[1].tray == "NotifyIconOverflowWindow" || p[1].hidden)
		return false
    d := A_DetectHiddenWindows, cm := A_CoordModeMouse, wd := A_WinDelay
    DetectHiddenWindows, On
    SetWinDelay, -1
    CoordMode, Mouse, Screen
	IconLoc := TrayIcon_GetRect(p[1], true)
	MouseGetPos, xpos, ypos
	WinGetPos, xO, yO, wO, hO, ahk_class NotifyIconOverflowWindow
	x := IconLoc.x + IconLoc.w//2
	y := IconLoc.y + IconLoc.h//2
    SystemCursor(0)
    BlockInput, On
	WinSet, Transparent, 1, ahk_class NotifyIconOverflowWindow
	WinShow, ahk_class NotifyIconOverflowWindow
    WinWait, ahk_class NotifyIconOverflowWindow, , 1
	PostMessage, WM.LBUTTONDOWN, 1, ((y<<16)^x), % "ToolbarWindow32" TI_foos.Shell_TrayWnd, ahk_class Shell_TrayWnd
	MouseMove, xO+wO-10, yO+hO-10, 0
	Sleep, %delay%
	PostMessage, WM.LBUTTONUP, 0, ((y<<16)^x), % "ToolbarWindow32" TI_foos.Shell_TrayWnd, ahk_class Shell_TrayWnd
	WinHide, ahk_class NotifyIconOverflowWindow
	WinSet, Transparent, 255, ahk_class NotifyIconOverflowWindow
	MouseMove, xpos, ypos, 0
    SystemCursor(1)
    BlockInput, Off
    CoordMode, Mouse, %cm%
	DetectHiddenWindows, %d%
    SetWinDelay, %wd%
    return true
}

SystemCursor(OnOff=1)   ; INIT = "I","Init"; OFF = 0,"Off"; TOGGLE = -1,"T","Toggle"; ON = others
{
    static AndMask, XorMask, $, h_cursor
        ,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13 ; system cursors
        , b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13   ; blank cursors
        , h1,h2,h3,h4,h5,h6,h7,h8,h9,h10,h11,h12,h13   ; handles of default cursors
    if (OnOff = "Init" or OnOff = "I" or $ = "")       ; init when requested or at first call
    {
        $ := "h"                                       ; active default cursors
        VarSetCapacity( h_cursor,4444, 1 )
        VarSetCapacity( AndMask, 32*4, 0xFF )
        VarSetCapacity( XorMask, 32*4, 0 )
        system_cursors := "32512,32513,32514,32515,32516,32642,32643,32644,32645,32646,32648,32649,32650"
        StringSplit c, system_cursors, `,
        Loop %c0%
        {
            h_cursor   := DllCall( "LoadCursor", "Ptr",0, "Ptr",c%A_Index% )
            h%A_Index% := DllCall( "CopyImage", "Ptr",h_cursor, "UInt",2, "Int",0, "Int",0, "UInt",0 )
            b%A_Index% := DllCall( "CreateCursor", "Ptr",0, "Int",0, "Int",0
                , "Int",32, "Int",32, "Ptr",&AndMask, "Ptr",&XorMask )
        }
    }
    if (OnOff = 0 or OnOff = "Off" or $ = "h" and (OnOff < 0 or OnOff = "Toggle" or OnOff = "T"))
        $ := "b"  ; use blank cursors
    else
        $ := "h"  ; use the saved cursors

    Loop %c0%
    {
        h_cursor := DllCall( "CopyImage", "Ptr",%$%%A_Index%, "UInt",2, "Int",0, "Int",0, "UInt",0 )
        DllCall( "SetSystemCursor", "Ptr",h_cursor, "UInt",c%A_Index% )
    }
}
