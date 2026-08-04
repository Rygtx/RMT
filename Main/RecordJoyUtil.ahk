#Requires AutoHotkey v2.0
RecordControllerNum := 10
RecordJoyFloat := 10
RecordAxisMaxValue := 100
RecordJoyIndexArr := []
RecordAllJoyMap := Map("Joy1", 1, "Joy2", 1, "Joy3", 1, "Joy4", 1, "Joy5", 1, "Joy6", 1, "Joy7", 1, "Joy8", 1,
    "Joy9", 1, "Joy10", 1, "Joy11", 1, "Joy12", 1, "Joy13", 1, "Joy14", 1, "Joy15", 1, "Joy16", 1,
    "Joy17", 1, "Joy18", 1, "Joy19", 1, "Joy20", 1, "Joy21", 1, "Joy22", 1, "Joy23", 1, "Joy24", 1,
    "Joy25", 1, "Joy26", 1, "Joy27", 1, "Joy28", 1, "Joy29", 1, "Joy30", 1, "Joy31", 1, "Joy32", 1,
    "JoyXMin", 0, "JoyXMax", 100, "JoyYMin", 0, "JoyYMax", 100, "JoyZMin", 0, "JoyZMax", 100,
    "JoyRMin", 0, "JoyRMax", 100, "JoyUMin", 0, "JoyUMax", 100, "JoyVMin", 0, "JoyVMax", 100,
    "JoyPOV_0", 0, "JoyPOV_9000", 9000, "JoyPOV_18000", 18000, "JoyPOV_27000", 27000)

RecordJoyAxises := Map("JoyXMin", 0, "JoyXMax", 100, "JoyYMin", 0, "JoyYMax", 100, "JoyZMin", 0, "JoyZMax", 100,
    "JoyRMin", 0, "JoyRMax", 100, "JoyUMin", 0, "JoyUMax", 100, "JoyVMin", 0, "JoyVMax", 100)
RecordJoyPOVMap := Map("JoyPOV_0", 0, "JoyPOV_9000", 9000, "JoyPOV_18000", 18000, "JoyPOV_27000", 27000)

RecordKeyMap := Map("JoyPOV_0", "Joy12", "JoyPOV_9000", "Joy15", "JoyPOV_18000", "Joy13", "JoyPOV_27000", "Joy14",
    "JoyXMin", "JoyAxis1Min", "JoyXMax", "JoyAxis1Max", "JoyYMin", "JoyAxis2Min", "JoyYMax", "JoyAxis2Max",
    "JoyUMin", "JoyAxis3Min", "JoyUMax", "JoyAxis3Max", "JoyRMin", "JoyAxis4Min", "JoyRMax", "JoyAxis4Max",
    "JoyZMin", "Joy17", "JoyZMax", "Joy18")

XboxJoyAndPOVMap := Map("Joy1", 12, "Joy2", 13, "Joy3", 14, "Joy4", 15, "Joy5", 8, "Joy6", 9, "Joy7", 5,
    "Joy8", 4, "Joy9", 6, "Joy10", 7,
    "JoyPOV_0", 0, "JoyPOV_9000", 3, "JoyPOV_18000", 1, "JoyPOV_27000", 2)

XboxJosAxisMap := Map("JoyXMin", -32768, "JoyXMax", 32767, "JoyYMin", -32768, "JoyYMax", 32767, "JoyZMin",
    255, "JoyZMax", 255, "JoyRMin", -32768, "JoyRMax", 32767, "JoyUMin", -32768, "JoyUMax", 32767, "JoyVMin", -
    32768, "JoyVMax", 32767)

; 物理手柄 XInput 状态列表（排除 ViGEm 虚拟手柄）
RecordXInputStates := []

RecordJoyTimer() {
    global RecordXInputStates

    if (!UIControls.ToolCheckRecord.Value)
        return

    RecordRefreshJoyIndexArr()
    RecordXInputStates := RecordCollectXInputStates()

    ahkToJoyMap := MySoftData.GetAhkToJoyMap()
    for key, value in RecordAllJoyMap {
        isJoyAxis := RecordJoyAxises.Has(key)
        isJoyPOV := RecordJoyPOVMap.Has(key)
        isJoyBtn := !isJoyAxis && !isJoyPOV
        isHold := false
        if (isJoyBtn) {
            isHold := RecordJoyCheckBtnDown(key)
        }
        else if (isJoyPOV) {
            isHold := RecordCheckPOVMacro(key)
        }
        else {
            isHold := RecordCheckAxisMacro(key)
        }

        joyKey := key
        if (ahkToJoyMap.Has(key))
            joyKey := ahkToJoyMap[key]
        if (isHold)
            OnRecordAddMacroStr(joyKey, true)

        if (MainSoftData.RecordHoldKeyMap.Has(joyKey) && !isHold)
            OnRecordAddMacroStr(joyKey, false)
    }
    SetTimer(RecordJoyTimer, -MainSoftData.RecordJoyInterval)
}

RecordJoy() {
    global RecordJoyIndexArr
    RecordRefreshJoyIndexArr()
    SetTimer(RecordJoyTimer, -10)
}

RecordRefreshJoyIndexArr() {
    global RecordJoyIndexArr
    RecordJoyIndexArr := []
    loop RecordControllerNum {
        if GetKeyState(A_Index "JoyName") {
            RecordJoyIndexArr.Push(A_Index)
        }
    }
}

RecordGetVirtualXInputIdx() {
    global ViGJoy
    try {
        if (IsSet(ViGJoy))
            return ViGJoy.ViGJoyXInputIdx
    }
    return -1
}

; 采集所有物理手柄的 XInput 状态（跳过 ViGEm 虚拟手柄占用的槽位）
RecordCollectXInputStates() {
    states := []
    virtualIdx := RecordGetVirtualXInputIdx()
    loop 4 {
        idx := A_Index - 1
        if (idx == virtualIdx)
            continue
        try state := RecordXInputState(idx)
        catch
            continue
        if (state != 0)
            states.Push(state)
    }
    return states
}

RecordJoyCheckBtnDown(key) {
    loop RecordJoyIndexArr.Length {
        index := RecordJoyIndexArr[A_Index]
        if (GetKeyState(index "" key)) {
            return true
        }
    }
    return CheckXboxBtnOrPOVMacro(key)
}

RecordCheckPOVMacro(key) {
    loop RecordJoyIndexArr.Length {
        index := RecordJoyIndexArr[A_Index]
        cont_info := GetKeyState(index "JoyInfo")
        if InStr(cont_info, "P") {
            state := GetKeyState(index "JoyPOV")
            value := RecordJoyPOVMap.Get(key)
            if (state == value) {
                return true
            }
        }
    }

    return CheckXboxBtnOrPOVMacro(key)
}

CheckXboxBtnOrPOVMacro(key) {
    global RecordXInputStates
    if (!XboxJoyAndPOVMap.Has(key))
        return false
    bitSymbol := XboxJoyAndPOVMap.Get(key)
    for state in RecordXInputStates {
        if ((state.wButtons >> bitSymbol) & 1)
            return true
    }
    return false
}

RecordCheckAxisMacro(key) {
    loop RecordJoyIndexArr.Length {
        index := RecordJoyIndexArr[A_Index]
        cont_info := GetKeyState(index "JoyInfo")
        if (cont_info == "ZRUPD")
            continue
        joyAxisName := SubStr(key, 1, 4)
        state := GetKeyState(index joyAxisName)
        valueSection := GetAxisTriggerSection(key, false)
        if (IsNumber(state) && state >= valueSection[1] && state <= valueSection[2]) {
            return true
        }
    }

    if (SubStr(key, 1, 4) == "JoyV") ; xbox 没有这个轴
        return false

    return CheckXboxAxisMacro(key)
}

CheckXboxAxisMacro(key) {
    global RecordXInputStates
    valueSection := GetAxisTriggerSection(key, true)
    for state in RecordXInputStates {
        value := GetXboxAxisValueFromState(key, state)
        if (value == 0)
            continue
        if (value >= valueSection[1] && value <= valueSection[2])
            return true
    }
    return false
}

GetAxisTriggerSection(axisKey, isXbox) {
    value := RecordJoyAxises.Get(axisKey)
    floatValue := RecordAxisMaxValue * (RecordJoyFloat / 100)
    if (isXbox) {
        value := XboxJosAxisMap.Get(axisKey)
        floatValue := Abs(value) * (RecordJoyFloat / 100)
    }
    if (value <= 0) {
        return [value, value + floatValue]
    }
    else {
        return [value - floatValue, value]
    }
}

GetXboxAxisValueFromState(joyAxisSymbol, State) {
    joyAxisName := SubStr(joyAxisSymbol, 1, 4)
    if (State == 0)
        return 0

    if (joyAxisSymbol == "JoyZMin") {
        return State.bLeftTrigger
    }
    else if (joyAxisSymbol == "JoyZMax") {
        return State.bRightTrigger
    }

    if (joyAxisName == "JoyX") {
        return State.sThumbLX
    }
    else if (joyAxisName == "JoyY") {
        return State.sThumbLY
    }
    else if (joyAxisName == "JoyR") {
        return State.sThumbRY
    }
    else if (joyAxisName == "JoyU") {
        return State.sThumbRX
    }
    else if (joyAxisName == "JoyV") {
        return State.sThumbRY
    }

    return 0
}

RecordXInputState(UserIndex) {
    xiState := Buffer(16)
    if err := DllCall("XInput1_4\XInputGetState", "uint", UserIndex, "ptr", xiState) {
        if err = 1167 ; ERROR_DEVICE_NOT_CONNECTED
            return 0
        throw OSError(err, -1)
    }
    return {
        dwPacketNumber: NumGet(xiState, 0, "UInt"),
        wButtons: NumGet(xiState, 4, "UShort"),
        bLeftTrigger: NumGet(xiState, 6, "UChar"),
        bRightTrigger: NumGet(xiState, 7, "UChar"),
        sThumbLX: NumGet(xiState, 8, "Short"),
        sThumbLY: NumGet(xiState, 10, "Short"),
        sThumbRX: NumGet(xiState, 12, "Short"),
        sThumbRY: NumGet(xiState, 14, "Short"),
    }
}

; 兼容旧调用名
XInputState(UserIndex) {
    return RecordXInputState(UserIndex)
}

GetXboxAxisValue(joyAxisSymbol) {
    global RecordXInputStates
    if (RecordXInputStates.Length > 0)
        return GetXboxAxisValueFromState(joyAxisSymbol, RecordXInputStates[1])
    return 0
}
