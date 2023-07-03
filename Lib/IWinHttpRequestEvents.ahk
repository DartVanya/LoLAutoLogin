class IWinHttpRequestEvents
{ ; https://docs.microsoft.com/en-us/windows/win32/winhttp/iwinhttprequestevents-interface
   __New(Whr, UserFunc) {
      this.UserFunc := UserFunc
      this._CreateInterface()
      this._ConnectInterface(Whr)
   }

   Status[] {
      get {
         Return this.Info.status
      }
   }

   _CreateInterface() {
      static Methods := [ {name: "QueryInterface"         , paramCount: 3}
                        , {name: "AddRef"                 , paramCount: 1}
                        , {name: "Release"                , paramCount: 1}
                        , {name: "OnResponseStart"        , paramCount: 3}
                        , {name: "OnResponseDataAvailable", paramCount: 2}
                        , {name: "OnResponseFinished"     , paramCount: 1}
                        , {name: "OnError"                , paramCount: 3} ]

      this.SetCapacity("vtable", A_PtrSize*(Methods.Count() + 1))
      pVtable := this.GetAddress("vtable")
      this.SetCapacity("IUnknown", A_PtrSize)
      NumPut(pVtable, this.GetAddress("IUnknown"))

      this.Info := {refOffset: A_PtrSize * Methods.Count(), UserFunc: this.UserFunc}
      this.EventInst := new this.Events(this.Info)
      this.Callbacks := []
      for k, v in Methods {
         Callback := new BoundFuncCallback( ObjBindMethod(this.EventInst, v.name), v.paramCount, "Fast" )
         NumPut(Callback.addr, pVtable + A_PtrSize*(k - 1))
         this.Callbacks.Push(Callback)
      }
      NumPut(0, pVtable + this.Info.refOffset)
   }

   _ConnectInterface(Whr) {
   ; IConnectionPointContainer, IConnectionPoint — OCIdl.h
   ; IWinHttpRequestEvents — httprequest.idl
      static IID_IConnectionPointContainer := "{B196B284-BAB4-101A-B69C-00AA00341D07}"
           , IID_IWinHttpRequestEvents     := "{F97F4E15-B787-4212-80D1-D380CBBF982E}"

      pICPC := pIConnectionPointContainer := ComObjQuery(Whr, IID_IConnectionPointContainer)
      riid := CLSIDFromString(IID_IWinHttpRequestEvents, _)

      ; IConnectionPointContainer::FindConnectionPoint
      DllCall(NumGet(NumGet(pICPC + 0) + A_PtrSize*4), "Ptr", pICPC, "Ptr", riid, "PtrP", pIConnectionPoint)
      ObjRelease(pICPC), pICP := pIConnectionPoint

      ; IConnectionPoint::Advise
      DllCall(NumGet(NumGet(pICP + 0) + A_PtrSize*5), "Ptr", pICP, "Ptr", this.GetAddress("IUnknown"), "UIntP", cookie)
      this.pICP := pICP, this.cookie := cookie
   }

   __Delete() {
      ; IConnectionPoint::Unadvise
      DllCall(NumGet(NumGet(this.pICP + 0) + A_PtrSize*6), "Ptr", this.pICP, "UInt", this.cookie)
      ObjRelease(this.pICP)
      this.Delete("Callbacks")
      this.SetCapacity("vtable", 0), this.Delete("vtable")
      this.Delete("EventInst")
   }

   class Events {
      __New(Info) {
         this.Info := Info
      }

      QueryInterface(pIWinHttpRequestEvents, riid, ppvObject) {
         static IID_IUnknown              := "{00000000-0000-0000-C000-000000000046}"
              , IID_IWinHttpRequestEvents := "{F97F4E15-B787-4212-80D1-D380CBBF982E}"
              , E_NOINTERFACE := 0x80004002, S_OK := 0, _, __
              , p1 := CLSIDFromString(IID_IUnknown             ,  _)
              , p2 := CLSIDFromString(IID_IWinHttpRequestEvents, __)

         if !( DllCall("Ole32\IsEqualGUID", "Ptr", riid, "Ptr", p1)
            || DllCall("Ole32\IsEqualGUID", "Ptr", riid, "Ptr", p2) )
         { ; if riid doesn't match IID_IUnknown nor IID_IWinHttpRequestEvents
            NumPut(0, ppvObject + 0)
            Return E_NOINTERFACE
         }
         else {
            NumPut(pIWinHttpRequestEvents, ppvObject + 0)
            DllCall(NumGet(NumGet(ppvObject + 0) + A_PtrSize), "Ptr", ppvObject)
            Return S_OK
         }
      }

      AddRef(pIWinHttpRequestEvents) {
         refOffset := NumGet(pIWinHttpRequestEvents + 0) + this.Info.refOffset
         NumPut(refCount := NumGet(refOffset + 0, "UInt") + 1, refOffset, "UInt")
         Return refCount
      }

      Release(pIWinHttpRequestEvents) {
         refOffset := NumGet(pIWinHttpRequestEvents + 0) + this.Info.refOffset
         NumPut(refCount := NumGet(refOffset + 0, "UInt") - 1, refOffset, "UInt")
         Return refCount
      }

      OnResponseStart(pIWinHttpRequestEvents, status, pType) {
         ; type := StrGet(pType)
         this.Info.status := status
         this.Info.start := true
      }

      OnResponseDataAvailable(pIWinHttpRequestEvents, ppSafeArray) {
         Critical
         pSafeArray := NumGet(ppSafeArray + 0)
         pData := NumGet(pSafeArray + 8 + A_PtrSize)
         length := NumGet(pSafeArray + 8 + A_PtrSize*2, "UInt")
         this.Info.UserFunc.Call(pData, length, true)
      }

      OnResponseFinished(pIWinHttpRequestEvents) {
         this.Info.UserFunc.Call(0, 0, false)
      }

      OnError(pIWinHttpRequestEvents, errorNumber, pErrorDescription) {
         this.Info.UserFunc.Call("error", errorNumber, StrGet(pErrorDescription))
      }
   }
}

class BoundFuncCallback
{
   __New(BoundFuncObj, paramCount, options := "") {
      this.pInfo := Object( {BoundObj: BoundFuncObj, paramCount: paramCount} )
      this.addr := RegisterCallback(this.__Class . "._Callback", options, paramCount, this.pInfo)
   }
   __Delete() {
      ObjRelease(this.pInfo)
      DllCall("GlobalFree", "Ptr", this.addr, "Ptr")
   }
   _Callback(Params*) {
      Info := Object(A_EventInfo), Args := []
      Loop % Info.paramCount
         Args.Push( NumGet(Params + A_PtrSize*(A_Index - 2)) )
      Return Info.BoundObj.Call(Args*)
   }
}

CLSIDFromString(IID, ByRef CLSID) {
   VarSetCapacity(CLSID, 16, 0)
   if res := DllCall("ole32\CLSIDFromString", "WStr", IID, "Ptr", &CLSID, "UInt")
      throw Exception("CLSIDFromString failed. Error: " . Format("{:#x}", res))
   Return &CLSID
}
