Email(sFrom, sTo, sSubject, sBody, sUsername, sPassword, sServer, nPort, sAttach="") {
    static schema	:= "http://schemas.microsoft.com/cdo/configuration/"  ; Do not change
         , bTLS		:= True    ; False
         , nSend	:= 2       ; cdoSendUsingPort
         , nAuth	:= 1       ; cdoBasic
    ;ComObjError(false) ;suppress errors from end user

    pmsg := ComObjCreate("CDO.Message"), fields := Object()
    , fields.sendusing := nSend
    , fields.smtpconnectiontimeout := 60
    , fields.smtpserver := sServer
    , fields.smtpserverport := nPort
    , fields.smtpusessl := bTLS
    , fields.smtpauthenticate := nAuth
    , fields.sendusername := sUsername
    , fields.sendpassword := sPassword
    , fields.Update()

    , pmsg.From := sFrom
    , pmsg.To := sTo
    , pmsg.Subject := sSubject
    , pmsg.TextBody := sBody

    pfld := pmsg.Configuration.Fields
    for field,value in fields
        pfld.Item(schema . field) := value
    pfld.Update()

    Loop, Parse, sAttach, |, %A_Space%%A_Tab%
        pmsg.AddAttachment(A_LoopField)
    pmsg.Send()
    return
}