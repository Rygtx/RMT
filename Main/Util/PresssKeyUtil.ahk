#Requires AutoHotkey v2.0
; ------------------------------------------------------------
; Helper
; ------------------------------------------------------------
GetHoldBucket(tableItem, index) {
    return tableItem.HoldKeyArr[index]
}

TrackDown(bucket, key, source) {
    if !MySoftData.OnlyDownKeyMap.Has(key)
        bucket[key] := source
}

TrackUp(bucket, key) {
    if !MySoftData.OnlyDownKeyMap.Has(key)
        bucket.Delete(key)
}

ClearDpadHoldState(bucket) {
    for dpadKey in ["Up", "Down", "Left", "Right"]
        bucket.Delete(dpadKey)
}

ResolveActionForKey(baseAction, key) {
    static LogicNoKeyMap := Map("Volume_Up", 0, "Volume_Down", 0, "Volume_Mute", 0)
    return (baseAction == SendLogicKey && LogicNoKeyMap.Has(key)) ? SendNormalKey : baseAction
}

SendKeysUp(keys, state, tableItem, index, Action) {
    Loop keys.Length {
        key := keys[keys.Length - A_Index + 1]
        SendSingleKey(key, state, tableItem, index, Action)
    }
}
SendKeysDown(keys, state, tableItem, index, Action) {
    for key in keys
        SendSingleKey(key, state, tableItem, index, Action)
}

; ------------------------------------------------------------
; Wrapper
; ------------------------------------------------------------
SendKeyWrapper(KeyArrStr, holdTime, tableItem, index, keyType, Action) {
    KeyArrStr := StrReplace(KeyArrStr, "逗号", ",")
    KeyArr := GetPressKeyArr(KeyArrStr)
    if !IsObject(KeyArr) || (KeyArr.Length = 0)
        return

    switch keyType {
        case 1:
            SendKeysDown(KeyArr, 1, tableItem, index, Action)
        case 2:
            SendKeysUp(KeyArr, 0, tableItem, index, Action)
        case 3:
            SendKeysDown(KeyArr, 1, tableItem, index, Action)
            Sleep(holdTime)
            SendKeysUp(KeyArr, 0, tableItem, index, Action)
    }
}

SendSingleKey(key, state, tableItem, index, Action) {
    static BrightKeyMap := Map("Bright_Up", 0, "Bright_Down", 0)
    if BrightKeyMap.Has(key) {
        if (state = 1)
            SetBrightnessByKey(key)
        return
    }

    if (state = 0) && MySoftData.OnlyDownKeyMap.Has(key)
        return

    RealAction := ResolveActionForKey(Action, key)

    if (state = 1) && HandleRepeatedKeyDown(key, tableItem, index, RealAction)
        return

    RealAction(key, state, tableItem, index)
}

; ------------------------------------------------------------
; Repeated key-down policy
; ------------------------------------------------------------
HandleRepeatedKeyDown(key, tableItem, index, Action) {
    if !(GetKeyState(key) = 1)
        return false

    switch MainSoftData.KeyDownDownType {
        case 1:  ; auto release first
            Action(key, 0, tableItem, index)
        case 2:  ; ignore later press
            return true
        case 3:  ; allow duplicate press
    }
    return false
}

; ------------------------------------------------------------
; Senders
; ------------------------------------------------------------
SendNormalKey(Key, state, tableItem, index) {
    bucket := GetHoldBucket(tableItem, index)

    Send("{Blind}{" Key " " (state ? "down" : "up") "}")
    if state
        TrackDown(bucket, Key, "Normal")
    else
        TrackUp(bucket, Key)
}

SendLogicKey(Key, state, tableItem, index) {
    if !InitLogitechGHubNew()
        return

    bucket := GetHoldBucket(tableItem, index)

    IbSend("{Blind}{" Key " " (state ? "down" : "up") "}")
    if state
        TrackDown(bucket, Key, "Logic")
    else
        TrackUp(bucket, Key)
}

SendAHIKey(Key, state, tableItem, index) {
    if !InitAHI()
        return

    bucket := GetHoldBucket(tableItem, index)

    AhiSendKey(Key, state)
    if state
        TrackDown(bucket, Key, "AHI")
    else
        TrackUp(bucket, Key)
}

SendGameModeKey(Key, state, tableItem, index) {
    static MouseVK := Map(
        1, 0,     ; LButton
        2, 0,     ; RButton
        4, 0,     ; MButton
        5, 0,     ; XButton1
        6, 0,     ; XButton2
        158, 0,   ; WheelDown
        159, 0    ; WheelUp
    )

    static ExtendedVK := Map(
        0x21, 0,  ; PageUp
        0x22, 0,  ; PageDown
        0x23, 0,  ; End
        0x24, 0,  ; Home
        0x25, 0,  ; Left
        0x26, 0,  ; Up
        0x27, 0,  ; Right
        0x28, 0,  ; Down
        0x2D, 0,  ; Insert
        0x2E, 0   ; Delete
    )

    bucket := GetHoldBucket(tableItem, index)

    VK := GetKeyVK(Key)
    if MouseVK.Has(VK) {
        SendGameMouseKey(Key, state, tableItem, index)
        return
    }

    SC := GetKeySC(Key)
    flags := (state ? 0 : 2) | (ExtendedVK.Has(VK) ? 1 : 0)
    DllCall("keybd_event", "UChar", VK, "UChar", SC, "UInt", flags, "UPtr", 0)

    if state
        TrackDown(bucket, Key, "Game")
    else
        TrackUp(bucket, Key)
}

SendGameMouseKey(key, state, tableItem, index) {
    static MouseMap := Map(
        "LButton",   {Down: 0x0002, Up: 0x0004, Data: 0},
        "RButton",   {Down: 0x0008, Up: 0x0010, Data: 0},
        "MButton",   {Down: 0x0020, Up: 0x0040, Data: 0},
        "WheelUp",   {Down: 0x0800, Up: 0,      Data: 120},
        "WheelDown", {Down: 0x0800, Up: 0,      Data: -120},
        "XButton1",  {Down: 0x0080, Up: 0x0100, Data: 0x0001},
        "XButton2",  {Down: 0x0080, Up: 0x0100, Data: 0x0002}
    )

    bucket := GetHoldBucket(tableItem, index)
    info := MouseMap[key]

    if state {
        DllCall("mouse_event", "UInt", info.Down, "UInt", 0, "UInt", 0, "UInt", info.Data, "UInt", 0)
        TrackDown(bucket, key, "GameMouse")
    } else {
        if info.Up
            DllCall("mouse_event", "UInt", info.Up, "UInt", 0, "UInt", 0, "UInt", info.Data, "UInt", 0)
        TrackUp(bucket, key)
    }
}

SendJoyBtnKey(key, state, tableItem, index) {
    bucket := GetHoldBucket(tableItem, index)

    JoyBtnName := SubStr(key, 4)
    if (JoyBtnName = "LT" || JoyBtnName = "RT")
        MyViGJoySetState("Axis", JoyBtnName, state ? 100 : 0)
    else
        MyViGJoySetState("Btn", JoyBtnName, state)

    if state
        TrackDown(bucket, key, "Joy")
    else
        TrackUp(bucket, key)
}

SendJoyAxisKey(key, state, tableItem, index) {
    bucket := GetHoldBucket(tableItem, index)

    Value := InStr(key, "Min") ? 0 : 100
    MyViGJoySetState("Axis", SubStr(key, 8, 2), state ? Value : 50)

    if state
        TrackDown(bucket, key, "JoyAxis")
    else
        TrackUp(bucket, key)
}

SendJoyDpadKey(key, state, tableItem, index) {
    bucket := GetHoldBucket(tableItem, index)

    RealKey := SubStr(key, 8)
    MyViGJoySetState("Dpad", state ? RealKey : "None", 0)

    if state && (RealKey != "None")
        TrackDown(bucket, key, "JoyDpad")
    else
        ClearDpadHoldState(bucket)
}

; ------------------------------------------------------------
; Brightness
; ------------------------------------------------------------
SetBrightnessByKey(key, *) {
    if (key = "Bright_Down")
        ChangeBrightness(false)
    else if (key = "Bright_Up")
        ChangeBrightness(true)
}

ChangeBrightness(isAdd) {
    CurrentBrightness := GetBrightness()
    Value := Max(0, Min(100, CurrentBrightness + (isAdd ? 10 : -10)))
    wmi := ComObjGet("winmgmts:\\.\root\WMI")
    for item in wmi.ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods")
        item.WmiSetBrightness(1, Value)
}