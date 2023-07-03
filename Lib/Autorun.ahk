;
; AutoHotkey Version: 1.0.35.11
; Language:       All
; Platform:       XP
; Author:         Dmitry B. Lyudmirsky <lud@skpress.ru>
; File Name:      Autorun.ahk
;
; Script Function:
; 	Put Autorun.ahk into your script's directory.
; 	To provide Autorun capability
; 	simply insert a line
; 	#Include Autorun.ahk ; place Autorun item here
; 	anywhere in your script's tray menu declaration.
; 	If using Registry mode don't forget a line
; 	#Include %A_ScriptDir% ; 1.0.35.11+
; 	at the beginning of the script
;

class Autorun {
	static ScriptName := SubStr(A_ScriptName, 1, StrLen(A_ScriptName)-4)
	__New(ItemName = "Запускать вместе с Windows", cmd = "", fn = "", RegMode = true)
    {
		this.AutorunMenuItemName := ItemName, this.Params := cmd ? (" " cmd) : "", this.AddSetup := fn, this.RegistryMode := RegMode
		if this.RegistryMode
			this.SK := "Software\" . (A_PtrSize=4 ? "WOW6432Node\" : "") . "Microsoft\Windows\CurrentVersion\Run" ; Registry SubKey name
		else {
			this.SF := A_Startup ; Startup Folder - you may choose A_StartupCommon
			this.LF := this.SF . "\" . this.ScriptName . ".lnk" ; LinkFile
		}
		AR_Setup := ObjBindMethod(this, "AutorunSetup")
		Menu Tray, Add, % this.AutorunMenuItemName, % AR_Setup
		this.AutorunSetup()
    }
	AutorunSetup()
	{
		if this.AddSetup
			this.AddSetup()
		if this.AutorunInit
		{
			if this.AutorunOn
			{
				if this.RegistryMode
					RegDelete HKLM, % this.SK, % this.ScriptName
				else
					FileDelete % this.LF
				this.AutorunOn := ErrorLevel
				if !this.AutorunOn
					Menu Tray, Uncheck, % this.AutorunMenuItemName
			return
			} ; else
			if this.RegistryMode
				RegWrite REG_SZ, HKLM, % this.SK, % this.ScriptName, % """" . A_ScriptFullPath . """" .  this.Params
			else
				FileCreateShortcut %A_ScriptFullPath%, % this.LF, %A_ScriptDir%
			this.AutorunOn := !ErrorLevel
			if this.AutorunOn
				Menu Tray, Check, % this.AutorunMenuItemName
			return
		}
		this.AutorunInit := true
		if this.RegistryMode
			RegRead SPath, HKLM, % this.SK, % this.ScriptName
		else
			FileGetShortcut % this.LF, SPath
		this.AutorunOn := !ErrorLevel
		if this.AutorunOn
		{
			IfNotEqual SPath, A_ScriptFullPath
			{ ; update record in case of the script file was moved
				Menu Tray, Check, % this.AutorunMenuItemName
				if this.RegistryMode
					RegWrite, REG_SZ, HKLM, % this.SK, % this.ScriptName, % """" . A_ScriptFullPath . """" . this.Params
				else
					FileCreateShortcut %A_ScriptFullPath%, % this.LF, %A_ScriptDir%
				this.AutorunOn := !ErrorLevel
			}
		}
	}
	isOn(){
		return this.AutorunOn
	}
}
