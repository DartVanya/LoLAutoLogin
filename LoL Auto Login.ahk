﻿; LoL Auto Login by Dart Vanya
#Requires AutoHotkey Unicode 64-bit

#Include <ScriptGuard1>
global ProgVersion := "5.1.2.3", Author := "Dart Vanya", LAL := "LoL Auto Login"
;@Ahk2Exe-Let U_version = %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%
;@Ahk2Exe-Let U_author = %A_PriorLine~U)^(.+"){3}(.+)".*$~$2%
;@Ahk2Exe-Let U_LAL = %A_PriorLine~U)^(.+"){5}(.+)".*$~$2%
;@Ahk2Exe-Obey U_year, = A_YYYY
;@Ahk2Exe-SetName %U_LAL%
;@Ahk2Exe-SetOrigFilename %U_LAL%.exe
;@Ahk2Exe-SetCompanyName %U_author%
;@Ahk2Exe-SetCopyright %U_author%`, %U_year%
;@Ahk2Exe-SetVersion %U_version%
;;@Ahk2Exe-SetLanguage 0x0419
;@Ahk2Exe-SetDescription  Tool to auto-login in League Client
;@Ahk2Exe-SetMainIcon lc.ico

;@Ahk2Exe-Obey U_Bin,= "%A_BasePath~^.+\.%" = "bin" ? "Cont" : "Nop" ; .bin?
;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1 ; Base file ANSI or Unicode?
;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"
;@Ahk2Exe-%U_Bin%  "1%U_au%2.>AUTOHOTKEY SCRIPT<. LOL AUTO LOGIN    "
;@Ahk2Exe-Cont  "%U_au%.AutoHotkeyGUI.LoLAutoLogin"
;@Ahk2Exe-Cont  /ScriptGuard2
;@Ahk2Exe-UpdateManifest 0 ,%U_LAL%

;@Ahk2Exe-PostExec "%A_ScriptDir%\version gen.bat" %U_version%, , %A_ScriptDir%, 1, 1

;@Ahk2Exe-ExeName %A_ScriptDir%\Release\LoL Auto Login

#NoEnv
#SingleInstance Off
#NoTrayIcon
SetBatchLines, -1
ListLines Off
SetWorkingDir %A_ScriptDir%
SendMode Input
SetKeyDelay, , 35
SetControlDelay, -1
SetWinDelay, -1
#Include <Gdip_All>
#Include <Crypt>
#Include <CryptConst>
#Include <CryptFoos>
#Include <AddTooltip>
#Include <Autorun>
#Include <SysMenu>
#Include <ToolTipFM>
#Include <TrayPopUp>
#Include <IWinHttpRequestEvents>

for n, param in A_Args
{
	If SubStr(param, 1, 1) contains "-,/"
		Switch SubStr(param, 2)
		{
		case "acc":
			if (A_Args.HasKey(n+1)) {
				AccNumber := A_Args[n+1]
				AccFromCMD := true
			}
		case "config":
			ShowGuiFlag := true
		case "autorun":
			AutoRun_flag := true
		}
}
if GetKeyState("Ctrl")
	ShowGuiFlag := true

DetectHiddenWindows, On
WinSetTitle, ahk_id %A_ScriptHwnd%, , %LAL%
SetTitleMatchMode, 3
WinGet, LAL_count, Count, %LAL% ahk_class AutoHotkey
if (LAL_count = 1)
	OnMessage(0x004A, "WM_COPYDATA")
else {
	WinGet, LAL_count, List, %LAL% ahk_class AutoHotkey
	Loop, %LAL_count%
	{
		ReceiverId := LAL_count%A_Index%
		if (ReceiverId != A_ScriptHwnd)
			break
	}
	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)  ; Set up the structure's memory area.
	; First set the structure's cbData member to the size of the string, including its zero terminator:
	NumPut(ShowGuiFlag ? 1 : (AccFromCMD ? 0 : -1), CopyDataStruct, 0, A_PtrSize)
	if AccFromCMD {
		NumPut((StrLen(AccNumber) + 1) * 2, CopyDataStruct, A_PtrSize)  ; OS requires that this be done.
		NumPut(&AccNumber, CopyDataStruct, 2*A_PtrSize)  ; Set lpData to point to the string itself.
	}
	; Must use SendMessage not PostMessage.
	SendMessage, 0x004A, 0, &CopyDataStruct,, ahk_id %ReceiverId% ; 0x004A is WM_COPYDATA.
	ExitApp
}
SetTitleMatchMode, 1
DetectHiddenWindows, Off

global ProgName := LAL . " by " . Author
	 , IniName := LAL . ".ini"
	 , LAL_sec := StrReplace(LAL, " ")
	 , IniCopyright := "[" . LAL_sec . "] - " . ProgName . ". Version " . ProgVersion
	 , SC_Name := LAL . " Config.lnk"
	 , MainStart := false, CloseRC_flag, WaitForLC, Persistent_flag, SoftRestart, ForceRestart, gInterrupt := false
	 , CheckForUpdate_flag
LAL_hk := "Ctrl+Win+L", Config_hk := "Ctrl+Win+K", Interrupt_hk := "Ctrl+Win+I"
, MenuSettings := "Настройки" A_Tab Config_hk, MenuExit := "Выход", MenuVersion := "Версия"
, MenuCloseRC := "Закрывать Riot Client", MenuPersistent := "Не выходить после авторизации в игру", MenuAutorun := "Запускать вместе с Windows"
, MenuFR := "Принудительный перезапуск клиента", MenuFRfast := "Быстрый", MenuFRfull := "Полный", MenuFRask := "Спрашивать"
, MenuFRsleep := "При выходе из спящего режима", MenuInterrupt := "Прервать авторизацию" A_Tab Interrupt_hk
, MenuUpdateCheck := "Проверять наличие обновлений"
Locales := "ar_AE|cs_CZ|de_DE|el_GR|en_US|es_MX|es_ES|fr_FR|hu_HU|id_ID|it_IT|ja_JP|ms_MY|pl_PL|pt_BR|ro_RO|ru_RU|th_TH|tr_TR|vi_VN|zh_TW"
;RegionsArr := {BR: "BR", EUNE: "EUNE", EUW: "EUW", JP: "JP", LAN: "LA1", LAS: "LA2", NA: "NA", OCE: "OC1", RU: "ru_RU", TR: "TR"}
FirstRun := true
for FPObj in ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" . A_ComputerName . "\root\cimv2").ExecQuery("Select * From Win32_ComputerSystemProduct")
Fingerprint := FPObj.IdentifyingNumber . "`n" . FPObj.UUID
;ColorsArray := [0xEDEDED, 0xF9F9F9, 0xFAFAFA, 0xEEEEEE, 0xE6E6E6, 0xE8E8E8, 0xF3E2F5, 0x333333]
max_input := 128
VarSetCapacity(dec_buf, (max_input+1)*2, 0), VarSetCapacity(edit_fill, (max_input+1)*2)
Loop, %max_input%
	edit_fill .= A_Space
if !(pToken := Gdip_Startup())
	ExitApp
OnExit("Cleanup")

Menu, Tray, NoStandard
if !(AccNumber) {
	IniRead, AccNumber, % IniName, % LAL_sec, LastAcc
	if !(AccNumber)
		AccNumber := 1
}
if GetAccsList() {
	IniRead, Login, % IniName, % AccNumber, Login
	IniRead, Locale, % IniName, % AccNumber, Locale
}

Menu, Tray, Add, % LAL . A_Tab . LAL_hk, TryMain
IniRead, Persistent_flag, % IniName, % LAL_sec, Persistent, % false
if !(Persistent_flag)
	Menu, Tray, Disable, 1&
Menu, Tray, Default, 1&
Menu, Tray, Add, % "by " . Author . A_Tab . MenuVersion . ": " . ProgVersion, Stub
Menu, Tray, Disable, 2&
UpdateAccsMenu(-1)
Menu, Tray, Add
Menu, Tray, Add, %MenuSettings%, ShowGui
Menu, ForceRestart, Add, %MenuFRfast%, ForceRestartHandler
Menu, ForceRestart, Add, %MenuFRfull%, ForceRestartHandler
Menu, ForceRestart, Add, %MenuFRask%, ForceRestartHandler
Menu, ForceRestart, Add
Menu, ForceRestart, Add, %MenuFRsleep%, ForceRestartFromSleep
Menu, Tray, Add, %MenuFR%, :ForceRestart
IniRead, ForceRestart, % IniName, % LAL_sec, ForceRestart, % false
switch ForceRestart & 3
{
	case 1:
		SysMenu.CheckRadio(1, "ForceRestart", true, 1, 3)
	case 2:
		SysMenu.CheckRadio(2, "ForceRestart", true, 1, 3)
	Default:
		SysMenu.CheckRadio(3, "ForceRestart", true, 1, 3)
}
if (ForceRestart & 4)
	Menu, ForceRestart, Check, 5&
Menu, Tray, Add, %MenuCloseRC%, CloseRC
Menu, Tray, Add, %MenuPersistent%, LAL_Persistent
Autorun := new Autorun(MenuAutorun, "-autorun", "AR_SysMenuCheck")
Menu, Tray, Add, %MenuUpdateCheck%, ToggleUpdateCheck
Menu, Tray, Add, %MenuExit%, Exit
IniRead, CloseRC_flag, % IniName, % LAL_sec, CloseRC, % false
Menu, Tray, % (CloseRC_flag ? "":"Un") "Check", 7&
Menu, Tray, % (Persistent_flag ? "":"Un") "Check", 8&
IniRead, CheckForUpdate_flag, % IniName, % LAL_sec, CheckForUpdate, % true
Menu, Tray, % (CheckForUpdate_flag ? "":"Un") "Check", 10&
Menu, Tray, Tip, %ProgName%
Menu, Tray, Icon

;global TT_Icon := TrayIcon_GetInfo(A_ScriptHwnd, 0x404).hicon
global 	TT_Icon := LoadPicture(A_IsCompiled ? A_ScriptFullPath : "lc.ico", , icon_type)
		, ToolTipFM := new ToolTipFM()
		, UpdateRequest, UpdateEvent, Update := {"size": 0, "FullSize": 0}
		, UpdateUrl := "https://github.com/DartVanya/LoLAutoLogin/releases/latest/download/LoL.Auto.Login.exe"

InitGui()
OnMessage(0x404, "AHK_NotifyTrayIcon")
OnMessage(0x218, "AHK_NotifyTrayIcon")

SetIniCopyright()

if !FileExist(SC_Name)
	FileCreateShortcut, %A_ScriptFullPath%, %A_ScriptDir%\%SC_Name%, %A_ScriptDir%, -config, Интерфейс настройки LoL Auto Login
if FileExist(A_ScriptName ".old")
	FileDelete, % A_ScriptName ".old"

if (CheckForUpdate_flag && DllCall("Sensapi\IsNetworkAlive","UintP", lpdwFlags)) {
	UpdateRequest := ComObjCreate("Msxml2.XMLHTTP")
	UpdateRequest.open("GET", "https://raw.githubusercontent.com/DartVanya/LoLAutoLogin/main/version.txt", true)
	UpdateRequest.onreadystatechange := Func("CheckForUpdate")
	UpdateRequest.send()
}

if (ShowGuiFlag || !FileExist(IniName))
	Goto, ShowGui

if !(AutoRun_flag)
	Goto, Main
return

TryMain:
if (!MainStart && !WaitForLC && AccsCount)
	Goto, Main
goto, Global_Int
return

#If (!MainStart && !WaitForLC && AccsCount)
^#VK4C up:: 	; Ctrl+Win+L
Main:
Gui, +OwnDialogs
MainStart := true, SoftRestart := false
Menu, Tray, Rename, 1&, %MenuInterrupt%
if FirstRun {
	IniRead, LoLPath, % IniName, % LAL_sec, LoLPath, % false
	IniRead, Login, % IniName, % AccNumber, Login, % false
	IniRead, Password, % IniName, % AccNumber, PasswordEnc, % false
	IniRead, Locale, % IniName, % AccNumber, Locale, % false
	if (!pass_checkValid() || !LoLPath || !Password || !Login || !Locale) {
		MainStart := false
		Goto, ShowGui
	}
	FirstRun := false
}
GameExistCheck:
Process, Exist, RiotClientServices.exe
if (ErrorLevel && !WinExist("ahk_exe LeagueClientUx.exe") && !WinExist("ahk_exe RiotClientUx.exe")) {
	Kill_RC_LC()
	Sleep, 500
}
if (LChWND := WinExist("ahk_exe LeagueClientUx.exe")) {
	switch ForceRestart & 3
	{
	case 1:
		SoftRestart := SoftRestart(LChWND)
	case 2:
		if (!FullRestart(LChWND)) {
			gInterrupt := MainStart := false
			return
		}
	Default:
	{
		CancelMess := Persistent_flag ? "" : "`nДля выхода из программы нажмите ""Отмена"""
		MsgBox, 35, % ProgName,
		(LTrim
			Игра уже запущена!%CancelMess%
			Выполнить быструю переавторизацию?
			Для полного перезапуска клиента нажмите "Нет".
		)
		IfMsgBox, Yes
			SoftRestart := SoftRestart(LChWND)
		IfMsgBox, No
		{
			if (!FullRestart(LChWND)) {
				gInterrupt := MainStart := false
				return
			}
		}
		IfMsgBox, Cancel
		{
			if WinExist("ahk_id" . hLAL) {
				MainExit(false)
				WinActivate, ahk_id %hLAL%
				return
			}
			MainExit()
			return
		}
	}
	}
}
if (gInterrupt || SoftRestart = -3) {
	gInterrupt := MainStart := false
	return
}
if !CheckPath() {
	MainStart := false
	Goto, ShowGui
}
MainCont:
if !DllCall("Sensapi\IsNetworkAlive","UintP", lpdwFlags) {
	MsgBox, 33, % ProgName, Вы не подключены к интернету! Желаете продолжить?
	IfMsgBox, Cancel
	{
		MainExit()
		return
	}
}
File := FileOpen(LoLPath . "Config\LeagueClientSettings.yaml", "rw")
RegExMatch(File.Read(), "O)locale:\s*""([a-z]+_[A-Z]+)""", OldLocale)
if (OldLocale.Value(1) != Locale) {
	File.Seek(OldLocale.Pos(1)-1)
	File.Write(Locale)
	NewLocale := true
}
File.Close
if (NewLocale) {
	Kill_RC_LC()
	WinWaitClose, ahk_class RCLIENT ahk_exe RiotClientUx.exe, , 3
	NewLocale := false, SoftRestart := -2
}
if WinExist("ahk_class RCLIENT ahk_exe RiotClientUx.exe")
	goto, AlreadyOpen
Run, % LoLPath "LeagueClient.exe"
switch SoftRestart
{
	case -1:
		ToolTipFM.Color(, 0xCC3300)
		, ToolTipFM.Set("Не удалось выполнить быструю переавторизацию`nВыполняется полный перезапуск…", 4500, LAL, TT_Icon)
	case -2:
		ToolTipFM.Color(, 0xCC3300)
		, ToolTipFM.Set("Был изменён язык клиента`nВыполняется полный перезапуск…", 4500, LAL, TT_Icon)
	case -3:
		return
	Default:
		ToolTipFM.Set("Игра запущена. Ожидание окна Riot Client…", 3000, LAL, TT_Icon)
}
While !WinExist("ahk_class RCLIENT ahk_exe RiotClientUx.exe") {
	if WinExist("ahk_class ScreenManagerWindowClass ahk_exe RiotClientServices.exe") {
		MainExit(), ToolTipFM.Color(, 0x3030A0), ToolTipFM.Set("Нет подключения к интернету, авторизация прервана!", 3500, LAL, TT_Icon)
		return
	}
	if gInterrupt {
		gInterrupt := MainStart := false
		return
	}
	Sleep, 50
}
AlreadyOpen:
global RC := {Coords: {}, HWND: WinExist("ahk_class RCLIENT ahk_exe RiotClientUx.exe")}
WinGet, RCPID, PID,  % "ahk_id" . RC.HWND
RC.PID := RCPID
if WinExist("ahk_id" . hLAL) {
	ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("Открыто окно настроек!`nВход будет выполнен после закрытия окна.", 3500, LAL, TT_Icon)
	WinWaitClose, % "ahk_id" . hLAL
}
ToolTipFM.Off()
WinGet, RC_MinMax, MinMax, % "ahk_id" . RC.HWND
if (RC_MinMax = -1)
	WinRestore, % "ahk_id" . RC.HWND
WinGetPos, , , RCw, RCh, % "ahk_id" . RC.HWND
RC.Coords.X := Round(RCw * .043), RC.Coords.Y := Round(RCh * .29)
, RC.Coords.X_play := Round(RCw * .14), RC.Coords.Y_play := Round(RCh * .91)
, RC.Coords.Y_err := Round(RCh * .337), RC.Coords.Y_load := Round(RCh * .362)
ToolTipFM.Off()

While WinExist("ahk_id" . RC.HWND)
{
	if gInterrupt {
		gInterrupt := MainStart := false
		return
	}
	if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") ||  GetKeyState("Shift", "P")
		|| GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
		if (!TT_HoldKeys)
			ToolTipFM.Color(, 0xCC3300)
			, ToolTipFM.Set("Зажата одна из клавиш Shift, Alt, Ctrl, Win!`nАвторизация выполнится после их отпускания", -1, LAL, TT_Icon)
			, TT_HoldKeys := true
		Sleep, 50
		continue
	}
	ToolTipFM.Off(), TT_HoldKeys := false
	pBitmap := Gdip_BitmapFromHWND(RC.HWND)
	RC.loginColor 		:= Gdip_GetPixel(pBitmap, RC.Coords.X, RC.Coords.Y) & 0x00FFFFFF
	RC.loginColor_play 	:= Gdip_GetPixel(pBitmap, RC.Coords.X_play, RC.Coords.Y_play) & 0x00FFFFFF
	RC.loginColor_err 	:= Gdip_GetPixel(pBitmap, RC.Coords.X, RC.Coords.Y_err) & 0x00FFFFFF
	RC.loginColor_load 	:= Gdip_GetPixel(pBitmap, RC.Coords.X, RC.Coords.Y_load) & 0x00FFFFFF
	if ((RC.loginColor_play & 0xFF) > 0xC0 && RC.loginColor_play < 0x3A0000) {
		ControlClick, % "x" . RC.Coords.X_play . " y" . RC.Coords.Y_play, % "ahk_id" . RC.HWND
		break
	}
	if ((RC.loginColor_load = 0xEDEDED || RC.loginColor_load = 0xE7E7E7)
		&& ((ErrCoords := (RC.loginColor_err > 0xF20000 && RC.loginColor_err < 0xF40000)) || RC.loginColor > 0xE00000)) {
		Critical
		Process, Exist, LeagueClient.exe
		if (ErrorLevel) {
			Process, Close, LeagueClient.exe
			Process, WaitClose, LeagueClient.exe, 3
		}
		BlockInput, On
		ClipSaved := ClipboardAll
		Clipboard := Login
		ControlClick, % "x" . RC.Coords.X . " y" . (ErrCoords && RC.loginColor < 0xF20000
													? RC.Coords.Y_err :  RC.Coords.Y), % "ahk_id" . RC.HWND, , , 2
		ControlSend, Chrome_WidgetWin_01, {Ctrl down}{VK56}{Ctrl up}{TAB}, % "ahk_id" . RC.HWND
		PassToClipboardSecure()
		ControlSend, Chrome_WidgetWin_01, {Ctrl down}{VK56}{Ctrl up}{Enter}, % "ahk_id" . RC.HWND
		Clipboard := ClipSaved
		BlockInput, Off
		break
	}
	ScanNext:
	Gdip_DisposeImage(pBitmap)
	Sleep, 50
}
if (!Persistent_flag && !CloseRC_flag)
	ExitApp
Gdip_DisposeImage(pBitmap)
WaitForLC := CloseRC_flag
if (CloseRC_flag) {
	TrayPopUp.SuspendGui(),  ToolTipFM.SetOffset(, -40)
	, TrayPopUp.onShow("RC_tt"), TrayPopUp.onHide(Func("RC_tt").Bind(false))
	Menu, Tray, Disable, 5&
	Menu, Tray, Disable, 3&
}
if (Persistent_flag && !CloseRC_flag) {
	Menu, Tray, Rename, 1&, % LAL . A_Tab . LAL_hk
}

MainStart := false
Critical, Off

FuckYouRiots := 1250
While !WinExist("ahk_exe LeagueClientUx.exe") && WinExist("ahk_id" . RC.HWND) {
	if gInterrupt {
		gInterrupt := WaitForLC := false
		return
	}
	WinGet, RC_MinMax, MinMax, % "ahk_id" . RC.HWND
	if (RC_MinMax = -1)
		WinRestore, % "ahk_id" . RC.HWND
	pBitmap := Gdip_BitmapFromHWND(RC.HWND)
	RC.loginColor_err 	:= Gdip_GetPixel(pBitmap, RC.Coords.X, RC.Coords.Y_err) & 0x00FFFFFF
	if (RC.loginColor_err > 0xF20000 && RC.loginColor_err < 0xF40000) {
		Gdip_DisposeImage(pBitmap)
		TryExit()
		return
	}
	RC.loginColor_play := Gdip_GetPixel(pBitmap, RC.Coords.X_play, RC.Coords.Y_play) & 0x00FFFFFF
	if ((RC.loginColor_play & 0xFF) > 0xC0 && RC.loginColor_play < 0x3A0000) {
		Sleep, % FuckYouRiots
		Process, Exist, LeagueClient.exe
		if !(ErrorLevel)
			ControlClick, % "x" . RC.Coords.X_play . " y" . RC.Coords.Y_play, % "ahk_id" . RC.HWND
		break
	}
	Gdip_DisposeImage(pBitmap)
	Sleep, 50
}
Gdip_DisposeImage(pBitmap)
Process, Wait, LeagueClient.exe, 5
if (CloseRC_flag) {
	Process, Close, % RC.PID
	Process, WaitClose, % RC.PID
	DetectHiddenWindows, On
	TrayIcon_Remove(WinExist("ahk_class TrayIconClass ahk_exe RiotClientServices.exe"), 1)
	DetectHiddenWindows, Off
}
TryExit()
if GuiAsked {
	GuiAsked := false, ToolTipFM.Off()
	goto, ShowGui
}
return

#If (MainStart || WaitForLC)
#^VK49::
Global_Int:
gInterrupt := true
TryExit()
ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("Авторизация прервана! Возврат к фоновому режиму.", 3000, LAL, TT_Icon)
return

SoftRestart(ByRef LChWND) {
	;WinGet, LC_MinMax, MinMax, ahk_id %LChWND%
	;if (LC_MinMax = -1)
		;WinRestore, ahk_id %LChWND%
	WinClose, ahk_id %LChWND%
	attempts := 0
	ClickLogoff:
	if (attempts >= 3)
		return -1, Kill_RC_LC()
	WinGetPos, , , LCw, LCh, ahk_id %LChWND%
	ControlClick, % "x" . LCw * .538 . " y" . LCh * .567, ahk_id %LChWND%
	time := A_TickCount
	While !WinExist("ahk_class RCLIENT ahk_exe RiotClientUx.exe") {
		if (gInterrupt)
			return -3
		Process, Exist, RiotClientServices.exe
		if !(ErrorLevel)
			return -1
		if (A_TickCount-time > 1000 && WinExist("ahk_id " . LChWND)) {
			++attempts
			goto, ClickLogoff
		}
		Sleep, 50
	}
	return !gInterrupt ? true : -3
}

FullRestart(ByRef LChWND, FromSleep:=false) {
	ToolTipFM.Set("Выполняется перезапуск клиента.`nОжидание закрытия процессов Riot Client…", 4000, LAL, TT_Icon)
	if (FromSleep) {
		Kill_RC_LC()
		SetTimer, main, -1
		return
	}
	WinClose, ahk_id %LChWND%
	WinClose, ahk_id %LChWND%
	Process, WaitClose, RiotClientServices.exe, 10
	if (gInterrupt)
		return false
	if (ErrorLevel)
		Kill_RC_LC()
	return true
}

AHK_NotifyTrayIcon(wParam, lParam, msg, hwnd) {
	switch (lparam)
	{
		case WM.MBUTTONUP:
		{
			timer := Func("FullRestart").Bind(LChWND, true)
		SetTimer, % timer, -2000
		return
			if (WaitForLC)
				ToolTipFM.SetOffset(), ToolTipFM.Color(, 0xCC3300)
				, ToolTipFM.Set("Аккаунт можно будет сменить только после окончания авторизации!"
								, 3500, LAL . " [РЕЖИМ ЗАКРЫТИЯ RC]", TT_Icon)
			else
				Menu, AccsMenu, Show
		}
		case WM.LBUTTONDOWN:
			SetTimer, ShowGui, -1
		case WM.LBUTTONDBLCLK:
			Gui, Hide
	}
	if (ForceRestart & 4 && msg = 0x218 && wParam = 0x7 && (LChWND := WinExist("ahk_exe LeagueClientUx.exe"))) {
		timer := Func("FullRestart").Bind(LChWND, true)
		SetTimer, % timer, -2000
	}
}

#If
^#VK4B up:: 	; Ctrl+Win+K
ShowGui:
if (WaitForLC && !ToolTipFM.isOn()) {
	GuiAsked := true, ToolTipFM.SetOffset(), ToolTipFM.Color(, 0xCC3300)
	, ToolTipFM.Set("В данный момент настройки недоступны!", 2500, LAL . " [РЕЖИМ ЗАКРЫТИЯ RC]", TT_Icon)
	return
}
else if (WaitForLC)
	return
ToolTipFM.Off()
SetIniCopyright()
GuiControl, ChooseString, AccNumberGUI, % AccNumber
ReadAccount()
if WinExist("ahk_id" . hLAL) {
	WinActivate, ahk_id %hLAL%
	return
}
WheelOnOff("On")
;TrayIcon_FromOverflow()
TrayPopUp.ShowPopUp(true)
return

InitGui() {
	global
	Gui, +HwndhLAL -MinimizeBox +AlwaysOnTop
	Gui, Add, Text, section, Путь к League of Legends:
	Gui, Add, Button, ys-2 x+49 w20 h20 hwndhAbout gAbout, ?
	Gui, Add, Edit, section xm w165 vLoLPath +ReadOnly
	CheckPath()
	GuiControl, Text, LoLPath, % LoLPath
	Gui, Add, Button, w30 x+5 ys-1 hwndhChoosePath gChoosePath, ...
	Gui, Add, Text, xm section, Введите логин:
	Gui, Add, Text, xp+140, Аккаунт #:
	Gui, Add, Edit, w135 xm vLogin Limit%max_input%
	Gui, Add, DDL, hwndhAccNumberGUI vAccNumberGUI gReadAccount -tabstop w60 x+5, % GetAccsList(AccsCount)
	if !(AccFromCMD){
		IniRead, AccNumber, % IniName, % LAL_sec, LastAcc, % false
		if !(AccNumber) && AccsCount
			AccNumber := 1
	}
	else
		AccFromCMD := false
	GuiControl, ChooseString, AccNumberGUI, % AccNumber ? AccNumber : ""
	Gui, Add, Text, xm section, Введите пароль:
	Gui, Add, CheckBox, hwndhPassCheck vPassCheck gShowPass -tabstop Right section x+45 ys, Показать
	Gui, Add, Edit, xm w200 vPassword +Password Limit%max_input%
	Gui, Add, Text, y+9 section, Язык:
	Gui, Add, DDL, ys-3 x+4 section w165 hwndhLocale vLocale, % Locales
	Gui, Add, Button, hwndhEnterPass gEnterPass +default section w90 x18, Подтвердить
	Gui, Add, Button, hwndhCreateShortcut gCreateShortcut section w90 x+4 ys, Создать ярлык
	Gui, Add, Text, xm section, Управление аккаунтами:
	Gui, Add, Button, hwndhAddAccount gAddAccount section w90 x18, Добавить
	Gui, Add, Button, hwndhDeleteAccount gDeleteAccount w90 x+4 ys, Удалить
	AddTooltip(hAbout, "Справка/О программе (F1)")
	AddTooltip(hChoosePath, "Выбрать путь к папке с игрой")
	AddTooltip(hAccNumberGUI, "Выбор аккаунта из имеющихся в базе (Прокрутка колеса, Up/Down)")
	AddTooltip(hPassCheck, "Показать/скрыть пароль (Ctrl+Space)")
	AddTooltip(hLocale, "Выбор языка локали для клиента игры")
	AddTooltip(hEnterPass, "Сохранить и выполнить вход в игру (Enter)")
	AddTooltip(hCreateShortcut, "Создать ярлык на выбранные аккаунт (Ctrl+Q).`nОткроется стандартное окно сохранения.")
	AddTooltip(hAddAccount, "Добавить аккаунт в базу (Ctrl+N)")
	AddTooltip(hDeleteAccount, "Удалить аккаунт из базы (Del)")
	AddToolTip("AutoPopDelay", 10)
	if !LoLPath
		GuiControl, Focus, % hChoosePath
	else if (LoLPath && Login)
		GuiControl, Focus, % hEnterPass
	else
		GuiControl, Focus, Login
	SysMenuItems=
	( LTrim Comments
		MF_SEPARATOR
		"%LAL%	%MenuVersion%: %ProgVersion%",		MF_GRAYED
		MF_SEPARATOR
		"%MenuFR%",									:ForceRestart
				ForceRestart,	%MenuFRfast%,		ForceRestartHandler
				ForceRestart,	%MenuFRfull%,		ForceRestartHandler
				ForceRestart,	%MenuFRask%,		ForceRestartHandler
				ForceRestart, 	MF_SEPARATOR
				ForceRestart,	%MenuFRsleep%,		ForceRestartFromSleep
		"%MenuCloseRC%",							CloseRC
		"%MenuPersistent%",							LAL_Persistent
		"%MenuUpdateCheck%",						ToggleUpdateCheck
		"%MenuExit%",								Exit
	)
	SysMenu := new SysMenu(hLAL, SysMenuItems, "Restore,Move,Size,Minimize,Maximize,Separator")
	SysMenu.Insert("ToggleUpdateCheck", MenuAutorun, ObjBindMethod(Autorun, "AutorunSetup"), , , true)

	if (CloseRC_flag)
		SysMenu.Check("CloseRC", , true)
	if (Persistent_flag)
		SysMenu.Check("LAL_Persistent", , true)
	if (Autorun.isOn())
		SysMenu.Check(MenuAutorun)
	if (CheckForUpdate_flag)
		SysMenu.Check("ToggleUpdateCheck", , true)
	switch ForceRestart & 3
	{
		case 1:
			SysMenu.ForceRestart.CheckRadio(1, 1, 3)
		case 2:
			SysMenu.ForceRestart.CheckRadio(2, 1, 3)
		Default:
			SysMenu.ForceRestart.CheckRadio(3, 1, 3)
	}
	if (ForceRestart & 4)
		SysMenu.ForceRestart.Check(5)
	ReadAccount()
	Gui, Show, Hide, % ProgName
	TrayPopUp := new TrayPopUp(hLAL)
	TrayPopUp.onShow("RereadAccount")
	TrayPopUp.onHide("HidePass")
	WheelFn := Func("WinMouseOver").Bind(hLAL)
	WheelOnOff("On")
	OnMessage(0x102, "WM_CHAR")
	Gui, gHelp:New, +hwndhHelp, О программе %LAL%
	return true
}

WM_CHAR(wParam, lParam){
	static SND_FILENAME := 0x1, SND_ASYNC := 0x00020000, fdwSound := SND_FILENAME | SND_ASYNC
			, pszSound := A_WinDir "\Media\Windows Ding.wav"
	if (A_GuiControl = "Login" && Chr(wParam) ~= "[ !""#\$%&’\(\)\*\+,-\./:;<=>\?@\[\\\]\^_`{|}~]")
		return DllCall("winmm.dll\PlaySoundW", "Str",pszSound, "Ptr",0, "UInt",fdwSound) & false
}

CloseRC(){
	global
	IniWrite, % CloseRC_flag := !CloseRC_flag, % IniName, % LAL_sec, CloseRC
	Menu, Tray, ToggleCheck, 7&
	SysMenu.ToggleCheck("CloseRC", , true)
}

LAL_Persistent(){
	global
	IniWrite, % Persistent_flag := !Persistent_flag, % IniName, % LAL_sec, Persistent
	Menu, Tray, ToggleCheck, 8&
	Menu, Tray, ToggleEnable, 1&
	SysMenu.ToggleCheck("LAL_Persistent", , true)
}

AR_SysMenuCheck(){
	global
	SysMenu.ToggleCheck(MenuAutorun)
}

ToggleUpdateCheck() {
	IniWrite, % CheckForUpdate_flag := !CheckForUpdate_flag, % IniName, % LAL_sec, CheckForUpdate
	Menu, Tray, ToggleCheck, 10&
	SysMenu.ToggleCheck("ToggleUpdateCheck", , true)
}

#If (WinActive("ahk_id" . hLAL) || WinMouseOver()) && AccsCount
^n::
AddAccount:
Gui, +OwnDialogs
Gui, Submit, NoHide
if !CheckCorrectEnter()
	return
if !(AccsCount) {
	WriteAccount(++AccsCount)
	GuiControl, , AccNumberGUI, 1|
	GuiControl, Choose, AccNumberGUI, % AccNumber := 1
	GuiControl, Enable, AccNumberGUI
	GuiControl, Enable, % hCreateShortcut
	GuiControl, Enable, % hDeleteAccount
	UpdateAccsMenu()
	return
}
if (NewAcc) {
	WriteAccount(++AccsCount)
	NewAccExit()
	UpdateAccsMenu(false)
	return
}
WriteAccount(OldAccGui := AccNumberGui)
GuiControl, Text, Login
GuiControl, Text, Password
GuiControl, Choose, Locale, ru_RU
GuiControl, , AccNumberGUI, |новый
GuiControl, Choose, AccNumberGUI, 1
GuiControl, Text, % hAddAccount, Сохранить
GuiControl, Text, % hDeleteAccount, Отмена
GuiControl, -g +gNewAccCancel, % hDeleteAccount
GuiControl, -g, % hAccNumberGUI
GuiControl, -Default, % hEnterPass
GuiControl, +Default, % hAddAccount`
GuiControl, Focus, Login
GuiControl, Disable, % hCreateShortcut
GuiControl, Disable, % hAccNumberGUI
AddTooltip(hAddAccount, "Записать аккаунт в базу (Enter)")
AddTooltip(hEnterPass, "Сохранить и выполнить вход в игру")
AddTooltip(hDeleteAccount, "Отменить добавление аккаунта (Esc)")
if !WinActive("ahk_id" . hLAL)
	WinActivate, ahk_id %hLAL%
NewAcc := true
return

NewAccExit(cancel=false) {
	global
	GuiControl, Text, % hAddAccount, Добавить
	GuiControl, Text, % hDeleteAccount, Удалить
	GuiControl, -g +gDeleteAccount,  % hDeleteAccount
	GuiControl, +gReadAccount, % hAccNumberGUI
	GuiControl, -Default, % hAddAccount
	GuiControl, +Default, % hEnterPass
	GuiControl, , AccNumberGUI, |
	GuiControl, , AccNumberGUI, % GetAccsList(AccsCount)
	GuiControl, Choose, AccNumberGUI, % cancel ? OldAccGui : AccsCount
	GuiControl, Enable, % hCreateShortcut
	GuiControl, Enable, % hAccNumberGUI
	AddTooltip(hAddAccount, "Добавить аккаунт в базу (Ctrl+N)")
	AddTooltip(hEnterPass, "Сохранить и выполнить вход в игру (Enter)")
	AddTooltip(hDeleteAccount, "Удалить аккаунт из базы (Del)")
	NewAcc := false
}

#If NewAcc && (WinActive("ahk_id" . hLAL) || WinMouseOver())
Esc::
NewAccCancel:
NewAccExit(true)
ReadAccount()
return

#If !NewAcc && (WinActive("ahk_id" . hLAL) || WinMouseOver())
Delete::
DeleteAccount:
Gui, Submit, NoHide
IniDelete, % IniName, % AccNumberGui
GuiControl, +AltSubmit, % hAccNumberGUI
Gui, Submit, NoHide
GuiControl, , AccNumberGUI, |
GuiControl, , AccNumberGUI, % GetAccsList(AccsCount)
GuiControl, Choose, AccNumberGUI, % (AccNumberGui < AccsCount) ? AccNumberGui : AccsCount
GuiControl, -AltSubmit, % hAccNumberGUI
ReadAccount()
UpdateAccsMenu(false)
return

WinMouseOver(hwnd:="") {
	global
	local Win
	MouseGetPos,,, Win
	return (Win == (hwnd ? hwnd : hLAL))
}

#If WinActive("ahk_id" . hLAL) || WinMouseOver()
Up::
ScrollUp:
if (Newacc || AccNumberGui = 1)
	return
GuiControl, Choose, AccNumberGUI, % AccNumberGui-1
ReadAccount()
return

#If WinActive("ahk_id" . hLAL) || WinMouseOver()
Down::
ScrollDown:
if (Newacc || AccNumberGui = AccsCount)
	return
GuiControl, Choose, AccNumberGUI, % AccNumberGui+1
ReadAccount()
return

WheelOnOff(state) {
	global
	Hotkey, If, % WheelFn
	Hotkey, WheelUp, ScrollUp, %state%
	Hotkey, WheelDown, ScrollDown, %state%
}

ReadAccount() {
	global
	Gui, Submit, NoHide
	if !(AccsCount) {
		GuiControl, , AccNumberGUI, |
		GuiControl, Text, Login
		GuiControl, Text, Password
		GuiControl, Choose, Locale, ru_RU
		GuiControl, Disable, AccNumberGUI
		GuiControl, Disable, % hCreateShortcut
		GuiControl, Disable, % hDeleteAccount
		return
	}
	IniRead, Login, % IniName, % AccNumberGUI, Login, % false
	GuiControl, Text, Login, % Login
	IniRead, Password, % IniName, % AccNumberGUI, PasswordEnc, % false
	if (PassCheck)
		GuiControl, , Password, % StrGet(&edit_fill, sLen/2)
	if (sLen := Crypt.Encrypt.StrDecrypt(dec_buf, Password, Fingerprint, 7, 6)) {
		GuiControl, Text, Password, % dec_buf
		memzero(&dec_buf, sLen)
	}
	else
		GuiControl, Text, Password
	IniRead, Locale, % IniName, % AccNumberGUI, Locale, % false
	GuiControl, Choose, Locale, % Locale ? Locale : "ru_RU"
}

WriteAccount(ByRef AccN) {
	global
	IniWrite, % Login, % IniName, % AccN, Login
	IniWrite, % PassEnc := Crypt.Encrypt.StrEncrypt(Password, Fingerprint, 7, 6), % IniName, % AccN, PasswordEnc
	pass_cleanup()
	IniWrite, % Locale, % IniName, % AccN, Locale
	return true
}

CheckCorrectEnter() {
	global
	if !(Login) {
		MsgBox, 8240, % ProgName, Вы не ввели логин!
		return false
	}
	if !(Password) {
		MsgBox, 8240, % ProgName, Вы не ввели пароль!
		return false
	}
	return true
}

CheckPath() {
	global
	IniRead, LoLPath, % IniName, % LAL_sec, LoLPath, % false
	if FileExist(LoLPath . "LeagueClient.exe")
		return true
	else {
		RegRead, LoLPath, HKLM, % "SOFTWARE\WOW6432Node\Riot Games, Inc\League of Legends", Location
		if (ErrorLevel) {
			EnvGet, SysDrive, HOMEDRIVE
			if FileExist(SysDrive . "\Riot Games\League of Legends\LeagueClient.exe") {
				IniWrite, % LoLPath := SysDrive . "\Riot Games\League of Legends\", % IniName, % LAL_sec, LoLPath
				return true
			}
			MsgBox, 33, % ProgName, Не удалось найти путь к игре! Вы хотите указать его вручную?
			IfMsgBox, Ok
			{
				FileSelectFile, LoLPath, , %SysDrive%\, Выберите путь к LeagueClient.exe, LeagueClient.exe
				if !(LoLPath)
					return false
				SplitPath, LoLPath, , LoLPath
			}
			IfMsgBox, Cancel
				return false
		}
	}
	IniWrite, % LoLPath .= "\", % IniName, % LAL_sec, LoLPath
	return true
}

SetIniCopyright() {
	global IniName, IniCopyright
	if !(FileExist(IniName)) {
		FileAppend, % IniCopyright, % IniName
		return
	}
	FileReadLine, VerifyStr, %  IniName, 1
	if (VerifyStr != IniCopyright) {
		File := FileOpen(IniName, "rw `n")
		FirstLine := File.ReadLine()
		IniData := File.Read()
		File.Seek := 0
		File.Length := 0
		File.WriteLine(IniCopyright)
		File.Write(IniData)
		File.Close
	}
}

ChoosePath:
Gui, +OwnDialogs
EnvGet, SysDrive, HOMEDRIVE
FileSelectFile, LoLPath, , %SysDrive%\, Выберите путь к LeagueClient.exe, LeagueClient.exe
if !(LoLPath)
	return
SplitPath, LoLPath, , LoLPath
LoLPath .= "\"
IniWrite, % LoLPath, % IniName, % LAL_sec, LoLPath
GuiControl, Text, LoLPath, % LoLPath
return

ShowPass:
Gui, Submit, NoHide
pass_cleanup()
GuiControl, % (PassCheck ? "-" : "+") . "Password", Password
return

#If WinActive("ahk_id" . hLAL) || WinMouseOver()
^Space::
GuiControl, % ((PassCheck := !PassCheck) ? "-" : "+") . "Password", Password
GuiControl, , % hPassCheck, % PassCheck
return

EnterPass:
Gui, +OwnDialogs
Gui, Submit, NoHide
if !LoLPath {
	MsgBox, 8240, % ProgName, Вы не указали путь к игре!
	return
}
if !CheckCorrectEnter()
	return
GuiControl, +Password, Password
GuiControl, , % hPassCheck, % PassCheck := false
Gui, Hide
WheelOnOff("Off")
if !AccsCount
	gosub, AddAccount
else {
	AccNumber := AccNumberGui
	IniWrite, % Login, % IniName, % AccNumber, Login
	IniWrite, % PassEnc := Crypt.Encrypt.StrEncrypt(Password, Fingerprint, 7, 6), % IniName, % AccNumber, PasswordEnc
	pass_cleanup()
	IniWrite, % Locale, % IniName, % AccNumber, Locale
	UpdateAccsMenu()
}
IniWrite, % AccNumber, % IniName, % LAL_sec, LastAcc
Password := PassEnc
if (MainStart && WinExist("ahk_class RCLIENT ahk_exe RiotClientUx.exe"))
	return
Menu, Tray, Enable, 1&
FirstRun := false
Goto, % MainStart ? "MainCont" : "Main"
return

#If (WinActive("ahk_id" . hLAL) || WinMouseOver()) && AccsCount
^q::
CreateShortcut:
Gui, +OwnDialogs
Gui, Submit, NoHide
if !CheckCorrectEnter()
	return
WriteAccount(AccNumberGui)
FileSelectFile, SC_path, S, %A_Desktop%\LoL Auto Login - %Login%.lnk, Выберите путь к LeagueClient.exe, Ярлыки (*.lnk)
if !(SC_path)
	return
FileCreateShortcut, %A_ScriptFullPath%, %SC_path%, %A_ScriptDir%, -acc %AccNumberGui%
return

#If WinActive("ahk_id" . hLAL) || WinMouseOver()
F1::
About() {
	global
	static AhkVersion := "AutoHotkey Unicode " . (A_PtrSize = 8 ? "64-bit " : "32-bit ") . A_AhkVersion
	Gui, %hLAL%:+Disabled
	Gui, gHelp:New, +hwndhHelp +Owner%hLAL% -MinimizeBox +AlwaysOnTop +LastFound, О программе %LAL%
	Gui, gHelp:Add, Link, w500,
	(
	Эта утилита создана для более быстрой авторизации в League of Legends.
	С версии 3.0 добавлена поддержка нескольких аккаунтов.
	При первом запуске будет открыто это окно настроек. В нём можно осуществлять управление аккаунтами в базе программы, а так же устанавливать путь к папке с игрой. Все элементы имеют всплывающие подсказки (версия 3.5+).

	Так же окно настроек можно открыть:
	 - с автоматически создаваемого ярлыка "LoL Auto Login Config" в папке с программой
	 - обычным запуском с зажатой клавишей CTRL
	 - из меню в трее во время работы программы

	После нажатия кнопки "Подтвердить", при обычном запуске программы будет осуществляться авторизация на выбранный аккаунт из базы.
	Так же из настроек можно создать ярлыки для входа в любые конкретные аккаунты.
	Возможен выбор языка локали для клиента игры, настройка уникальна для каждого аккаунта.

	Существует опция (версия 3.0+) закрытия окна Riot Client (в том числе его значка в трее) после успешной авторизации. Активация осуществляется соответствущим пунктом в меню трея.

	Все пароли храняются в конфиге программы в зашифрованном виде (используется шифрование AES-256), ключ шифрования уникален для каждой машины, поэтому невозможно использование базы аккаунтов из ini-файла, созданного на другом ПК. Так же с версии 3.5 повышена безопасность во время работы программы, пароль расшифровывается только в самый нужный момент, и сразу после использования происходит затирание областей памяти, где он хранился.

	Версия %ProgVersion%
	2015-%A_YYYY% %Author%
	<a href="mailto:dartvanya@gmail.com">dartvanya@gmail.com</a>
	Скомпилировано в %AhkVersion%
	)
	LAL_WasActive  := WinActive("ahk_id " hLAL)
	TrayPopUp.SelectGui(hHelp), TrayPopUp.ShowPopUp(), TrayPopUp.SelectGui(hLAL)
	WinActivate, ahk_id %hHelp%
}

#If WinActive("ahk_id" . hHelp) || WinMouseOver(hHelp)
Esc::
gHelpGuiClose:
Gui, gHelp:Destroy
Gui, %hLAL%:-Disabled
TrayPopUp.ShowPopUp()
if LAL_WasActive
	WinActivate, ahk_id %hLAL%
return

ForceRestartHandler(ItemName, ItemPos) {
	global
	switch ItemPos
	{
		case 1:
			ForceRestart := (ForceRestart & 4) | 1
		case 2:
			ForceRestart := (ForceRestart & 4) | 2
		case 3:
			ForceRestart := ForceRestart & 4
	}
	IniWrite, % ForceRestart, % IniName, % LAL_sec, ForceRestart
	SysMenu.CheckRadio(ItemPos, "ForceRestart", true, 1, 3), SysMenu.ForceRestart.CheckRadio(ItemPos, 1, 3)
}

ForceRestartFromSleep() {
	global
	Menu, ForceRestart, ToggleCheck, 5&
	SysMenu.ForceRestart.ToggleCheck(5)
	IniWrite, % ForceRestart ^= 4, % IniName, % LAL_sec, ForceRestart
}

AccKey:
if !ChangeAcc( SubStr(A_ThisHotkey, 4, InStr(A_ThisHotkey, " ")-InStr(A_ThisHotkey, "F")-1) )
	return
if (!MainStart && !WaitForLC) {
	GuiChooseAcc()
	goto, main
}
ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("Аккаунт можно будет сменить только после окончания авторизации!", 3500, LAL, TT_Icon)
return

UpdateAccsMenu(TrayUpdate = true) {
	global
	local Log, Loc, Accs
	if (TrayUpdate = -1)
		Menu, Tray, Add
	if MenuGetHandle("AccsMenu")
		Menu, AccsMenu, DeleteAll
	if (Accs := GetAccsList(AccsCount)) {
		if (TrayUpdate)
			Menu, Tray, Rename, 3&, Аккаунт [%AccNumber%] - %Login% [%Locale%]`tCtrl+Win+F%AccNumber%
		Hotkey, If
		Loop, Parse, Accs, |
		{
			if !(A_LoopField)
				break
			IniRead, Log, % IniName, % A_LoopField, Login, % false
			IniRead, Loc, % IniName, % A_LoopField, Locale, % false
			if (A_LoopField < 13) {
				Hotkey, % "^#F" A_LoopField " up", AccKey
				Menu, AccsMenu, Add, % Log "  [" Loc "]`tCtrl+Win+F" A_LoopField, MenuSelAcc
			}
			else
				Menu, AccsMenu, Add, % Log "  [" Loc "]", MenuSelAcc

		}
		if (AccsCount = 1 || TrayUpdate = -1) {
			Menu, Tray, Enable, 1&
			Menu, Tray, Add, 3&, :AccsMenu
			Menu, Tray, Enable, 3&
		}
		SysMenu.CheckRadio(AccNumber, "AccsMenu", true)
	}
	else {
		Menu, Tray, Disable, 1&
		Menu, Tray, Disable, 3&
		Menu, Tray, Add, 3&, Stub
		Menu, Tray, Rename, 3&, Нет аккаунтов в базе
	}
}

Stub:
return

#If WinActive("ahk_id " . hLAL) || WinMouseOver()
Esc::
GuiClose:
if (Persistent_flag || MainStart) {
	HidePass()
	Gui, Hide
	return
}
else
	ExitApp


HidePass() {
	global
	WheelOnOff("Off")
	GuiControl, +Password, Password
	Sleep, 0
	GuiControl, , % hPassCheck, % PassCheck := false
}

RereadAccount() {
	global
	if WinExist("ahk_id " hHelp) {
		Gui, gHelp:Destroy
		Gui, -Disabled
	}
	GuiControl, ChooseString, AccNumberGUI, % AccNumber
	ReadAccount()
	WheelOnOff("On")
}

RC_tt(bEnable=true) {
	if (bEnable)
		ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("В данный момент настройки недоступны!", 0, LAL . " [РЕЖИМ ЗАКРЫТИЯ RC]", TT_Icon)
	else
		ToolTipFM.Off()
}

Exit() {
	ExitApp
}

GetAccsList(ByRef AccsCount:="") {
	AccsCount := 0
	VarSetCapacity(AccsList, 10*2)
	IniRead, Accs, % IniName
	Loop, Parse, Accs, `n
	{
		if (A_LoopField = LAL_sec)
			continue
		AccsList .= A_LoopField "|"
		AccsCount++
	}
	return AccsList
}

Kill_RC_LC() {
	Process, Close, LeagueClient.exe
	Process, Close, RiotClientServices.exe
	Process, WaitClose, RiotClientServices.exe, 5
	Process, WaitClose, RiotClientCrashHandler.exe, 5
	Process, WaitClose, LeagueClient.exe, 5
	Process, WaitClose, LeagueCrashHandler64.exe, 5
	Process, WaitClose, LeagueClientUxRender.exe, 5
	Process, WaitClose, RiotClientUx.exe, 5
	Process, WaitClose, RiotClientUxRender.exe, 5
}

MainExit(DoExit = true) {
	if (DoExit && !Persistent_flag)
		ExitApp
	Menu, Tray, Rename, 1&, % LAL . A_Tab . LAL_hk
	MainStart := false
}

TryExit() {
	global
	local HoverOnTray
	if(!Persistent_flag)
		ExitApp
	Menu, Tray, Rename, 1&, % LAL . A_Tab . LAL_hk
	Menu, Tray, Enable, 5&
	Menu, Tray, Enable, 3&
	TrayPopUp.SuspendGui(false), ToolTipFM.SetOffset()
	TrayPopUp.onShow("RereadAccount"), TrayPopUp.onHide("HidePass")
	HoverOnTray := WaitForLC && ToolTipFM.isOn(), ToolTipFM.Off()
	WaitForLC := false
	if HoverOnTray
		SetTimer, ShowGui, -1
}

PassToClipboardSecure() {
	static CF_UNICODETEXT := 13
	global dec_buf, Password, Fingerprint
	sLen := Crypt.Encrypt.StrDecrypt(dec_buf, Password, Fingerprint, 7, 6)

	; Allocate a global memory object for the text
	mem := DllCall("Kernel32.dll\GlobalAlloc"
			, "UInt", 2 ; GMEM_MOVEABLE
			, "UInt", sLen+2) ; +2 in case it is a zero-terminated string
	; Lock the handle and copy the text to the buffer
	memmove(str := DllCall("Kernel32.dll\GlobalLock", "UInt", mem), &dec_buf, sLen+2)
	DllCall("Kernel32.dll\GlobalUnlock", "UInt", mem)
	; Open the clipboard, and empty it.
	DllCall("OpenClipboard", "UInt", 0), DllCall("EmptyClipboard")
	; Place the handle on the clipboard
	DllCall("SetClipboardData"
			, "UInt", CF_UNICODETEXT
			, "UInt", mem)
	DllCall("CloseClipboard")

	return memzero(str, sLen), memzero(&dec_buf, sLen)
}

pass_checkValid() {
	global dec_buf, Password, Fingerprint
	return sLen := Crypt.Encrypt.StrDecrypt(dec_buf, Password, Fingerprint, 7, 6), memzero(&dec_buf, sLen)
}

pass_cleanup() {
	global Password
	return memzero(&Password, StrLen(Password)*2)
}

Cleanup() {
	global
	pass_cleanup()
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(pToken)
}

ChangeAcc(number) {
	global
	IniRead, Login, % IniName, % number, Login, % false
	IniRead, Password, % IniName, % number, PasswordEnc, % false
	IniRead, Locale, % IniName, % number, Locale, % false
	if (!pass_checkValid() || !Password || !Login || !Locale) {
		local OldAcc := AccNumber
		AccFromCMD := true, AccNumber := number
		gosub, ShowGui
		AccNumber := OldAcc
		IniRead, Login, % IniName, % AccNumber, Login, % false
		IniRead, Password, % IniName, % AccNumber, PasswordEnc, % false
		IniRead, Locale, % IniName, % AccNumber, Locale, % false
		return false
	}
	IniWrite, % AccNumber := number, % IniName, % LAL_sec, LastAcc
	Menu, Tray, Rename, 3&, Аккаунт [%AccNumber%] - %Login% [%Locale%]`tCtrl+Win+F%AccNumber%
	SysMenu.CheckRadio(AccNumber, "AccsMenu", true)
	return true
}

GuiChooseAcc() {
	global
	if WinExist("ahk_id" . hLAL) {
		GuiControl, ChooseString, AccNumberGUI, % AccNumber
		ReadAccount()
		WinActivate, ahk_id %hLAL%
	}
}

MenuSelAcc(ItemName, ItemPos) {
	global
	if !(ChangeAcc(ItemPos))
		return
	if (!MainStart && !WaitForLC) {
		GuiChooseAcc()
		SetTimer, main, -1
		return
	}
	ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("Аккаунт можно будет сменить только после окончания авторизации!", 4000, LAL, TT_Icon)
}

WM_COPYDATA(wParam, lParam) {
	global
	if (NumGet(lParam+0) == -1) {
		SetTimer, main, -1
		return true
	}
	local NewAccNumber := StrGet(NumGet(lParam + 2*A_PtrSize))  ; Copy the string out of the structure.
	if NewAccNumber {
		if !InStr(GetAccsList(), NewAccNumber)
			return true
		ChangeAcc(NewAccNumber)
	}
	if (NumGet(lParam+0) == 1) {
		SetTimer, ShowGui, -1
		return true
	}
	GuiChooseAcc()
	SetTimer, main, -1
    return true  ; Returning 1 (true) is the traditional way to acknowledge this message.
}

CheckForUpdate() {
	if (UpdateRequest.readyState != 4)  ; Not done yet.
        return
	if (UpdateRequest.status == 200) {  ; OK.
		if (ProgVersion != (NewVersion := UpdateRequest.responseText) && VerCompare(ProgVersion, NewVersion) < 0) {
			MsgBox, 36, % ProgName,
			(LTrim
				Доступна новая версия LoL Auto Login.
				Выполнить обновление?

				Текущая версия: %ProgVersion%
				Доступная версия: %NewVersion%
			)
			IfMsgBox, Yes
			{
				FileMove, % A_ScriptName, % A_ScriptName ".old"
				ToolTipFM.Color(, 0xCC3300), ToolTipFM.Set("Выполняется загрузка обновления...", -1, LAL, TT_Icon)

				WinHttp := ComObjCreate("WinHttp.WinHttpRequest.5.1")
				WinHttp.Open("HEAD", UpdateUrl, true), WinHttp.Send()
				WinHttp.WaitForResponse()
				Update.FullSize := WinHttp.GetResponseHeader("Content-Length"), Update.FullSizeTT := Round(Update.FullSize/1024/1024, 2)
				UpdateEvent := new IWinHttpRequestEvents(WinHttp, Func("ReceiveUpdate"))
				WinHttp.Open("GET", UpdateUrl, true)
				Update.File := FileOpen(A_ScriptName, "w")
				WinHttp.Send()
				return
			}
		}
	}
}

ReceiveUpdate(pData, length, moreDataAvailable) {
	if moreDataAvailable {
		Update.File.RawWrite(pData+0, length), Update.size += length
		ToolTipFM.Set("Выполняется загрузка обновления...`nЗавершено " Round(Update.size/Update.FullSize*100) "%  - "
					  . Round(Update.size/1024/1024, 2) "/" Update.FullSizeTT " МБ", -1, LAL, TT_Icon)
	}
	else {
		ToolTipFM.Color(, "Green")
		, ToolTipFM.Set("Выполняется загрузка обновления...`nЗавершено 100% - "
					  . Update.FullSizeTT "/" Update.FullSizeTT " МБ`nУстановка обновления...", -1, LAL, TT_Icon)
		Update.File.Close()
		Sleep, 700
		Run, % DllCall("GetCommandLine", "Str")
		ExitApp
	}
}

GetParentProcess(PID) {
	static function := DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "kernel32.dll", "ptr"), "astr", "Process32Next" (A_IsUnicode ? "W" : ""), "ptr")
	if !(h := DllCall("CreateToolhelp32Snapshot", "uint", 2, "uint", 0))
		return
	VarSetCapacity(pEntry, sz := (A_PtrSize = 8 ? 48 : 36)+(A_IsUnicode ? 520 : 260))
	Numput(sz, pEntry, 0, "uint")
	DllCall("Process32First" (A_IsUnicode ? "W" : ""), "ptr", h, "ptr", &pEntry)
	loop
	{
		if (pid = NumGet(pEntry, 8, "uint") || !DllCall(function, "ptr", h, "ptr", &pEntry))
			break
	}
	DllCall("CloseHandle", "ptr", h)
	return Numget(pEntry, 16+2*A_PtrSize, "uint")
}