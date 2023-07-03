/*
     __    __  __          __ __       __    __                 _       __
    / /_  / /_/ /_____  _ / // /____ _/ /_  / /________________(_)___  / /_ ____  _______
   / __ \/ __/ __/ __ \(_) // // __ '/ __ \/ //_/ ___/ ___/ __/ / __ \/ __// __ \/ __/ _ \
  / / / / /_/ /_/ /_/ / / // // /_/ / / / / ,< (__  ) /__/ / / / /_/ / /__/ /_/ / / / // /
 /_/ /_/\__/\__/ .___(_) // / \__,_/_/ /_/_/|_/____/\___/_/ /_/ .___/\__(_)____/_/  \__ /
              /_/     /_//_/                                 /_/                   (___/SystemMenu

  Script  :  System Menu : Add custom and/or remove standard items
  Author  :  SKAN ( arian.suresh@gmail.com ),  Created: 19-Dec-2013
  Topic   :  http://ahkscript.org/boards/viewtopic.php?p=7630#p7630

*/
class MF {
	static BYCOMMAND := 0, BYPOSITION := 0x400, CHECKED := 0x8, UNCHECKED := 0, POPUP := 0x10, STRING := 0, GRAYED := 0x1
			, ENABLED := 0, DISABLED := 0x2,  MENUBARBREAK := 0x20, MENUBREAK := 0x40, SEPARATOR := 0x800
}

Class SysMenu {
	hWnd := 0, WM_SYSCOMMAND := "", SystemMenu := { "Items":{} }, __Menus := {}
	, START_ID := 1025, id := this.START_ID, sub_id := 0, CallSubMenu := ""

	class __WM_SYSCOMMAND {
		static WM_SYSCOMMAND := 0x112
		__New(pSuper) {
			OnMessage( this.WM_SYSCOMMAND, this ), this.pSuper := pSuper
		}
		Call(wParam, lParam, Msg, hWnd) {
			super := Object(this.pSuper)
			if wParam between % super.START_ID and % super.id
				return super.__MenuHandler(wParam)
		}
		Reset() {
			OnMessage( this.WM_SYSCOMMAND, this, 0 )
		}
	}

    __New(hWnd, SysMenuItems = "", RemovedItems="") {
		this.hWnd := hWnd
		, this.SystemMenu.hMenu := DllCall("GetSystemMenu", "UPtr",this.hWnd, "Int",false)   ; GetSystemMenu() goo.gl/cfW40p
		, this.__GetDefaultItems(), this.Set(SysMenuItems, RemovedItems)
		, this.WM_SYSCOMMAND := new SysMenu.__WM_SYSCOMMAND(&this)
    }

	__GetDefaultItems() {
		for pos, item in ["Restore", "Move", "Size", "Minimize", "Maximize", "", "Close"]
			this.SystemMenu.Items[DllCall( "GetMenuItemID", UPtr,this.SystemMenu.hMenu, UInt,pos-1 )]
				:= { "ItemName":item, "ItemPos":pos
					, "uFlags" : DllCall( "GetMenuState", UPtr,this.SystemMenu.hMenu, UInt,pos-1, UInt,MF.BYPOSITION ) }
		this.SystemMenu.count := DllCall( "GetMenuItemCount", UPtr,this.SystemMenu.hMenu )
	}

	__CreateSubMenu(SubMenu) {
		if (this.__Menus.HasKey(SubMenu))
			return this.__Menus[SubMenu].hMenu
		this.__Menus[SubMenu] := { "hMenu" : hMenu := DllCall("CreateMenu"), "count":0, "Items":{} }
		return hMenu
	}

	Set(AddItems="", RemovedItems="", NumFlags="") {
		if RemovedItems {
			RemovedItems := RegExReplace(RemovedItems, "[ \t]")
			if (RemovedItems = "All")
				this.DeleteAll()
			else
				Loop, Parse, RemovedItems, CSV					; RemoveMenu()    goo.gl/KzP0Yg
					this.Delete( (A_LoopField = "Separator" || A_LoopField = "_") ? -2 : A_LoopField)
		}

		Loop, Parse, AddItems,`n, `r%A_Space%%A_Tab%
		{
			Item := A_LoopField, F1 := "", F2 := "", F3 := "", F4 := "", uFlags := MF.STRING

			Loop, Parse, % RegExReplace(Item, ",[ \t]+(?![^""]|"""")", ","), CSV, %A_Space%%A_Tab%
				F%A_Index% := A_LoopField

			if NumFlags is not integer
			{
				Loop, Parse, % (F4 ? F4 : (F3 ? F3 : (F2 ? F2 : F1))), |, %A_Space%%A_Tab%
				{
					if (!(flag := StrSplit(A_LoopField, "_")) || flag.Length() != 2 || flag[1] != "MF" || !MF.HasKey(flag[2]))
						break
					uFlags |= MF[flag[2]]
				}
			}
			else
				uFlags := NumFlags
			if (uFlags & MF.SEPARATOR)
				uFlags := MF.SEPARATOR

			if ((!F3 && SubStr(F2,1,1) = ":") || SubStr(F3,1,1) = ":") {
				SubMenu := SubStr(F3 ? F3 : F2, 2), hMenu := (F3 ? this.__Menus[F1].hMenu : this.SystemMenu.hMenu), uFlags |= MF.POPUP
				hMenuPopup := this.__CreateSubMenu(SubMenu)
				if (hMenu = hMenuPopup)
					throw Exception("Error! Handle to popup menu can not be equal to parrent hMenu.", , Item)
				if (F3)
					this.__Menus[F1].Items[SubMenu "_" this.sub_id++] := {"ItemName":F2, "ItemPos" : ++this.__Menus[F1].count
						, "uFlags":uFlags}
				else
					this.SystemMenu.Items[SubMenu "_" this.sub_id++] := {"ItemName":F1, "ItemPos" : ++this.SystemMenu.count
						, "uFlags":uFlags}
				DllCall( "AppendMenu", UPtr,hMenu, UInt,uFlags, UPtr,hMenuPopup, UPtr, F3 ? &F2 : &F1)
				continue
			}

			if (this.__Menus.HasKey(F1)) {
				this.__Menus[F1].Items[this.id] := {"Handler":(SubStr(F3, 1, 3) != "MF_" ? Func(F3) : 0), "ItemName":(F3 ? F2 : F3)
					, "ItemPos" : ++this.__Menus[F1].count, "uFlags":uFlags}
				DllCall( "AppendMenu", UPtr,this.__Menus[F1].hMenu, UInt,uFlags, UPtr,this.id++, UPtr, F3 ? &F2 : 0 )
				continue
			}

			this.SystemMenu.Items[this.id] := {"Handler":(SubStr(F2, 1, 3) != "MF_" ? Func(F2) : 0), "ItemName":(F2 ? F1 : F2)
				, "ItemPos":++this.SystemMenu.count, "uFlags":uFlags}
			DllCall( "AppendMenu", UPtr, this.SystemMenu.hMenu                     ; AppendMenu()    goo.gl/ggTuwF
								 , UInt, uFlags
								 , UPtr, this.id++
								 , UPtr, F2 ? &F1 : 0 )
		}
	}

	Add( NewItem="", HandlerOrSubmenu="", uFlags=0, SubMenu="") {
		if (!NewItem || NewItem = "MF_SEPARATOR")
			return this.Set( (SubMenu ? SubMenu "," : "") . "MF_SEPARATOR" )
		CmdSet := (SubMenu ? SubMenu "," : "") . (NewItem ? NewItem "," : "MF_SEPARATOR") . HandlerOrSubmenu
		return this.Set(Trim(CmdSet, ","), , uFlags)
	}

	Count( SubMenu="" ) {
		return SubMenu ? this.__Menus[SubMenu].count : this.SystemMenu.count
	}

	GetHandle( SubMenu="" ) {
		return SubMenu ? this.__Menus[SubMenu].hMenu : this.SystemMenu.hMenu
	}

	Reset() {
		for k, sub in this.__Menus
			DllCall("DestroyMenu", UPtr, sub.hMenu)
		for id, item in this.SystemMenu.Items
			if (item.hBitmap)
				DllCall("DeleteObject", UPtr, item.hBitmap)
		for k, sub in this.__Menus
			for id, item in sub.Items
				if (item.hBitmap)
					DllCall("DeleteObject", UPtr, item.hBitmap)
		this.SystemMenu := { "Items":{} }, this.__Menus := {}, this.id := SysMenu.START_ID, this.sub_id := 0
		, DllCall( "GetSystemMenu", UPtr,this.hWnd, Int,true )
		, this.SystemMenu.hMenu := DllCall( "GetSystemMenu", UPtr,this.hWnd, Int,false )
		return this.__GetDefaultItems()
	}

	__MenuHandler(ByRef wParam) {
		for id, item in this.SystemMenu.Items
			if (id = wParam)
				return item.Handler.Call(item.ItemName, item.ItemPos, "SystemMenu")
		for sub_name, sub in this.__Menus
			for id, item in sub.Items
				if (id = wParam)
					return item.Handler.Call(item.ItemName, item.ItemPos, sub_name)
	}

	__Get(aName) {
		if (this.__Menus.HasKey(aName) || aName = "") {
			this.CallSubMenu := aName
			return this
		}
		else if (!this.CallSubMenu) {
			this.CallSubMenu := aName, this.__CreateSubMenu(aName)
			return this
		}
	}

	__Call(fn, p*) {
		if (this.CallSubMenu && IsFunc(this[fn]) && (fn = "__CreateSubMenu" || !InStr(fn, "_"))) {
			sub := this.CallSubMenu, this.CallSubMenu := ""
			switch fn
			{
			case "CheckRadio":
				return this[fn](p[1], sub, false, p[2] ? p[2] : 1, p[3] ? p[3] : 0, p[4])
			case "Rename", "Icon", "UpdateHandler":
				return this[fn](p[1], p[2], sub, p[3])
			case "NoDefault", "Count", "DeleteAll", "GetHandle":
				return this[fn](sub)
			case "Insert":
				return this[fn](p[1], p[2], p[3], p[4] ? p[4] : 0, sub, p[5])
			case "Add":
				return this[fn](p[1], p[2], p[3], sub)
			;~ case "Set":
				;~ return this[fn](p[1], p[2], p[3] ? p[3] : 0)
			case "__CreateSubMenu":
				return this[fn](sub), this.CallSubMenu := sub
			Default:
				return this[fn](p[1], sub, p[2])
			}
		}
	}

	__Delete() {
		this.WM_SYSCOMMAND.Reset()
		return this.Reset()
	}

	_NewEnum() {
		EnumAll := this.__Menus.Clone(), EnumAll[""] := this.SystemMenu.Clone()
		return EnumAll._NewEnum()
    }

	;~ Redraw() {
		;~ Static SWP_Flag := 0x33 ; SWP_DRAWFRAME|SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE goo.gl/sah2Dm
		;~ return DllCall( "SetWindowPos", UPtr,this.hWnd, Int,0, Int,0, Int,0, Int,0, Int,0, UInt,SWP_Flag )
	;~ }

	ToggleCheck( Item, SubMenu="", ByHandler:=false ) {
		return this.__Check("Toggle", Item, SubMenu, ByHandler)
	}

	Check( Item, SubMenu="", ByHandler:=false ) {
		return this.__Check(MF.CHECKED, Item, SubMenu, ByHandler)
	}

	UnCheck( Item, SubMenu="", ByHandler:=false ) {
		return this.__Check(MF.UNCHECKED, Item, SubMenu, ByHandler)
	}

	__Check(uFlag, ByRef Item, ByRef SubMenu, ByRef ByHandler) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		if (uFlag = "Toggle")
			uFlag := Item.Ref.uFlags ^= MF.CHECKED
		else
			( (uFlag = MF.CHECKED && Item.Ref.uFlags |= MF.CHECKED) || Item.Ref.uFlags &= ~MF.CHECKED )
		return DllCall( "CheckMenuItem", UPtr,Item.hMenu, UInt,Item.Pos, UInt, uFlag | MF.BYPOSITION ) 		; 	goo.gl/L4FlQy
	}

	CheckRadio( Item, SubMenu="", Extern=false, First := 1, Last := 0, ByHandler:=false) {
		if (Extern)
			Item := { "hMenu" : MenuGetHandle(SubMenu), "Pos" : Item - 1 }
		else if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false

		; http://msdn.microsoft.com/en-us/library/ms647621(v=vs.85).aspx
		If (Last < 1)
			Last := DllCall( "GetMenuItemCount", UPtr,Item.hMenu )
		return DllCall( "CheckMenuRadioItem", UPtr,Item.hMenu, UInt,First - 1, UInt,Last - 1, UInt,Item.Pos, UInt,MF.BYPOSITION )
	}

	ToggleEnable( Item, SubMenu="", ByHandler:=false ) {
		return this.__Enable("Toggle", Item, SubMenu, ByHandler)
	}

	Enable( Item, SubMenu="", ByHandler:=false ) {
		return this.__Enable(MF.ENABLED, Item, SubMenu, ByHandler)
	}

	Disable( Item, SubMenu="", ByHandler:=false ) {
		return this.__Enable(MF.DISABLED, Item, SubMenu, ByHandler)
	}

	__Enable(uFlag, ByRef Item, ByRef SubMenu, ByRef ByHandler) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		if (uFlag = "Toggle")
			uFlag := (Item.Ref.uFlags & MF.GRAYED) ? (Item.Ref.uFlags := MF.ENABLED) : (Item.Ref.uFlags ^= MF.DISABLED)
		else
			( (uFlag = MF.DISABLED && Item.Ref.uFlags |= MF.DISABLED) || Item.Ref.uFlags &= ~MF.DISABLED )
		return DllCall( "EnableMenuItem", UPtr,Item.hMenu, UInt,Item.Pos, UInt, uFlag | MF.BYPOSITION )
		;     goo.gl/L4FlQy
	}

	Default( Item, SubMenu="", ByHandler:=false ) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		return DllCall( "SetMenuDefaultItem", UPtr,Item.hMenu, UInt,Item.Pos, UInt, true )
	}
	NoDefault( SubMenu="" ) {
		if !(hMenu := SubMenu ? this.__Menus[SubMenu].__hMenu : this.hMenu)
			return false
		return DllCall( "SetMenuDefaultItem", UPtr,hMenu, UInt,-1, UInt, true )
	}

	Rename( Item, NewName="", SubMenu="", ByHandler:=false ) {
		static MIIM_STRING := 0x40, MIIM_FTYPE := 0x100, MFT_STRING := 0x0, MFT_SEPARATOR := 0x800, MIIM_STATE := 0x1, MFS_DISABLED := 0x3
			, sz_info := A_PtrSize = 8 ? 80 : 48, dwTypeData_off := A_PtrSize = 8 ? 56 : 36
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		VarSetCapacity(item_info, sz_info, 0), Item.Ref.ItemName := NewName
		NumPut( sz_info, &item_info, "UInt" )
		NumPut( MIIM_STRING | MIIM_FTYPE | MIIM_STATE, &item_info + 4, "UInt" )
		DllCall( "GetMenuItemInfo", UPtr,Item.hMenu, UInt,Item.Pos, Int,true, UPtr, &item_info )
		fType := NumGet(&item_info, 8, "UInt"), fState := NumGet(&item_info, 12, "UInt")
		if (fType & MFT_SEPARATOR && !(Item.Ref.uFlags & (MF.DISABLED|MF.GRAYED)))
			fState &= ~MFS_DISABLED
		( NewName ? (fType &= ~MFT_SEPARATOR) : (fType |= MFT_SEPARATOR) )
		NumPut( fType, &item_info + 8, "UInt" ), NumPut( fState, &item_info + 12, "UInt" )
		( NewName && NumPut( &NewName, &item_info + dwTypeData_off) )
		( NewName ? Item.Ref.uFlags &= ~MF.SEPARATOR : Item.Ref.uFlags |= MF.SEPARATOR )
		return DllCall( "SetMenuItemInfo", UPtr,Item.hMenu, UInt,Item.Pos, Int,true, UPtr, &item_info )
	}

	Delete( Item="", SubMenu="", ByHandler:=false, KeepBmp:=false ) {
		if ( Item && !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		if (!Item && SubMenu) {
			While (this.__Menus[SubMenu].count)
				this.Delete(this.__Menus[SubMenu].count, SubMenu)
			DllCall("DestroyMenu", UPtr, this.__Menus[SubMenu].hMenu)
			this.__Menus.Delete(SubMenu)
			return true
		}
		if (!KeepBmp && Item.Ref.hBitmap)
			DllCall("DeleteObject", UPtr, Item.Ref.hBitmap)
		if (SubMenu)
			this.__Menus[SubMenu].Items.Delete(Item.Id), cnt := this.__Menus[SubMenu].count--
		else
			this.SystemMenu.Items.Delete(Item.Id), cnt := this.SystemMenu.count--
		if (Item.Pos+1 != cnt)
			for _id, _item in (SubMenu ? this.__Menus[SubMenu].Items : this.SystemMenu.Items)
				if (_item.ItemPos > Item.Pos+1)
					--_item.ItemPos

		return DllCall( "RemoveMenu", UPtr,Item.hMenu, UInt,Item.Pos, UInt, MF.BYPOSITION )
	}
	DeleteAll( SubMenu="" ) {
		if SubMenu
			While (this.__Menus[SubMenu].count)
				this.Delete(this.__Menus[SubMenu].count, SubMenu)
		else
			While (this.SystemMenu.count)
				this.Delete(this.SystemMenu.count)
	}

	Icon( Item, Icon, SubMenu="", ByHandler:=false, KeepBmp:=false ) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		if (Item.Ref.hBitmap = Icon)
			return true
		if (Icon && !(hBitmap := this.__LoadBitmap(Icon)))
			return false
		if (!KeepBmp && Item.Ref.hBitmap)
			DllCall("DeleteObject", UPtr, Item.Ref.hBitmap)

		this.__SetIcon(Item.hMenu, Item.Pos, Item.Ref.hBitmap := hBitmap)
		return hBitmap
	}
	NoIcon( Item, SubMenu="", ByHandler:=false ) {
		return this.Icon(Item, 0, SubMenu, ByHandler)
	}

	__SetIcon(ByRef hMenu, ByRef Pos, ByRef hBitmap) {
		static MIIM_BITMAP := 0x80, sz_info := A_PtrSize = 8 ? 80 : 48, hbmpItem_off := A_PtrSize = 8 ? 72 : 44
		VarSetCapacity(item_info, sz_info, 0)
		NumPut( sz_info, &item_info, "UInt" )
		NumPut( MIIM_BITMAP, &item_info + 4, "UInt" )
		NumPut( hBitmap, &item_info + hbmpItem_off )
		return DllCall( "SetMenuItemInfo", UPtr,hMenu, UInt,Pos, Int,true, UPtr, &item_info )
	}

	Insert( Item, NewItem="", HandlerOrSubmenu="", uFlags=0, SubMenu="", ByHandler:=false ) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		( NewItem != "" ? uFlags |= MF.STRING | MF.BYPOSITION : uFlags := MF.SEPARATOR | MF.BYPOSITION )

		if (SubStr(HandlerOrSubmenu,1,1) = ":") {
			hMenuPopup := this.__CreateSubMenu(InsertSubmenu := SubStr(HandlerOrSubmenu, 2))
			if (Item.hMenu = hMenuPopup)
				throw Exception("Error! Handle to popup menu can not be equal to parrent hMenu.", , InsertSubmenu)
			uFlags |= MF.POPUP, Handler := 0, NewId := InsertSubmenu "_" this.sub_id++
		}
		else
			Handler := IsObject(HandlerOrSubmenu) ? HandlerOrSubmenu : Func(HandlerOrSubmenu), NewId := this.id

		for _id, _item in (SubMenu ? this.__Menus[SubMenu].Items : this.SystemMenu.Items)
			if (_item.ItemPos > Item.Pos)
				++_item.ItemPos
		if (SubMenu)
			this.__Menus[SubMenu].Items[NewId] := {"ItemName":NewItem, "ItemPos":Item.Pos+1, "uFlags":uFlags, "Handler":Handler}
			, ++this.__Menus[SubMenu].count
		else
			this.SystemMenu.Items[NewId] := {"ItemName":NewItem, "ItemPos":Item.Pos+1, "uFlags":uFlags, "Handler":Handler}
			, ++this.SystemMenu.count

		return DllCall( "InsertMenu", UPtr,Item.hMenu, UInt,Item.Pos, UInt,uFlags
				, UPtr, (hMenuPopup ? hMenuPopup : this.id++), UPtr, &NewItem)
	}

	UpdateHandler( Item, NewHandler, SubMenu="", ByHandler:=false ) {
		if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			return false
		if (Item.Ref.uFlags & MF.SEPARATOR)
			this.Rename(Item.Ref.ItemPos, NewHandler, SubMenu)
		if (SubStr(NewHandler,1,1) = ":") {
			hMenuPopup := this.__CreateSubMenu(UpdateSubMenu := SubStr(NewHandler, 2))
			if (Item.hMenu = hMenuPopup)
				throw Exception("Error! Handle to popup menu can not be equal to parrent hMenu." , , UpdateSubMenu)
			Item.Ref.uFlags |= MF.POPUP, NewId := UpdateSubMenu "_" this.sub_id++
		}
		else if (Item.Ref.uFlags & MF.POPUP)
			Item.Ref.uFlags &= ~MF.POPUP, NewId := this.id

		if NewId {
			if SubMenu
				this.__Menus[SubMenu].Items.Delete(Item.Id), this.__Menus[SubMenu].Items[NewId] := Item.Ref
			else
				this.SystemMenu.Items.Delete(Item.Id), this.SystemMenu.Items[NewId] := Item.Ref
			DllCall( "RemoveMenu", UPtr,Item.hMenu, UInt,Item.Pos, UInt, MF.BYPOSITION )
			DllCall( "InsertMenu", UPtr,Item.hMenu, UInt,Item.Pos, UInt,Item.Ref.uFlags | MF.BYPOSITION
				, UPtr, (hMenuPopup ? hMenuPopup : this.id++), UPtr, Item.Ref.GetAddress("ItemName"))
			if (Item.Ref.hBitmap)
				this.__SetIcon(Item.hMenu, Item.Pos, Item.Ref.hBitmap)
		}

		Item.Ref.Handler := IsObject(NewHandler) ? NewHandler : Func(NewHandler)
		return true
	}

	__LoadBitmap(ByRef hBitmap) {
		static SM_CXSMICON
		if !SM_CXSMICON
			SysGet, SM_CXSMICON, 49

        if hBitmap is not integer
        {
			SplitPath, hBitmap ,,, Ext
            if !InStr(hBitmap, "*")
                hBitmap := LoadPicture(hBitmap, "GDI+" (Ext != "ico" ? " w" SM_CXSMICON : ""))
            else {
				Icon := StrSplit(hBitmap, "*")
				if (Icon.Length() != 2)
					return false
                hBitmap := LoadPicture(Icon[1], "GDI+ w" SM_CXSMICON " Icon" Icon[2])
            }
        }
        return hBitmap
    }

	__FindItem(ByRef Item, ByRef SubMenu, ByRef ByHandler) {
		if !(hMenu := SubMenu ? this.__Menus[SubMenu].hMenu : this.SystemMenu.hMenu)
			return false
		if item is integer
		{
			cnt := SubMenu ? this.__Menus[SubMenu].count : this.SystemMenu.count
			if (Item > cnt || -Item > cnt)
				return false
			if (Item < 0)
				Item := cnt + (Item+1)
			ByPos := true
		}

		for _id, _item in (SubMenu ? this.__Menus[SubMenu].Items : this.SystemMenu.Items) {
			if (ByPos && Item = _item.ItemPos)
				return {"hMenu":hMenu, "Pos": _item.ItemPos-1, "Id": _id, "Ref":_item}
			if (!ByHandler && Item = _item.ItemName)
				return {"hMenu":hMenu, "Pos": _item.ItemPos-1, "Id": _id, "Ref":_item}
			if (Item = _item.Handler.Name)
				return {"hMenu":hMenu, "Pos": _item.ItemPos-1, "Id": _id, "Ref":_item}
		}
		return false
	}

	;~ GetState( ItemRef=0, ByPos=1, MF=0x8 ) {
		;~ Flag    := ByPos ? MF.BYPOSITION : MF.BYCOMMAND
		;~ ItemRef := ItemRef - ( ByPos ? 1 : 0 )
		;~ R := DllCall( "GetMenuState", UPtr,this.SystemMenu.hMenu, UInt,ItemRef, UInt,Flag )  ; goo.gl/PdRLR9
		;~ Return ( MF=MF.POPUP ? ( R&16 ? R>>8 : 0 ) : MF>0 ? ( R & MF = MF ) : R )
	;~ }

	;~ Hilite( Item, SubMenu="", ByHandler:=false ) {
		;~ MF_HILITE := 0x80
		;~ if ( !(Item := this.__FindItem(Item, SubMenu, ByHandler)) )
			;~ return false
		;~ return DllCall( "HiliteMenuItem", UPtr,this.hWnd, UPtr,Item.hMenu, UInt,Item.Pos, UInt, MF.BYPOSITION | MF_HILITE )
	;~ }

	;~ res := DllCall( "SetMenuItemBitmaps", UPtr, this.hMenu
			 ;~ , UInt, this.id-1				; AppendMenu()    goo.gl/ggTuwF
			 ;~ , UInt, MF.BYCOMMAND
			 ;~ , UPtr, hIcon1
			 ;~ , UPtr, hIcon2 )
}
