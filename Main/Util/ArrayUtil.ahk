#Requires AutoHotkey v2.0

GetArrayStr(DataArray) {
    ResText := ""
    loop DataArray.Length {
        if (IsObject(DataArray[A_Index])) {
            ResText .= "[" GetArrayStr(DataArray[A_Index]) "]"
        }
        else {
            curText := StrReplace(DataArray[A_Index], ",", "\,")
            curText := StrReplace(curText, "[", "\[")
            curText := StrReplace(curText, "]", "\]")
            curText := StrReplace(curText, "，", "\，")
            curText := StrReplace(curText, "【", "\【")
            curText := StrReplace(curText, "】", "\】")
            ResText .= curText
        }
        ResText .= ","
    }
    ResText := Trim(ResText, ",")
    return ResText
}

GetArray(Text) {
    Text := StrReplace(Text, "\\", "\⎖")
    ResArr := []
    LastSplitPos := 0
    Pos := GetNextSplitPos(Text, LastSplitPos)
    while (Pos != 0) {
        CurText := SubStr(Text, LastSplitPos + 1, Pos - LastSplitPos - 1)
        if (CurText == "") {
            ResArr.Push("")
        }
        else {
            IsArrayStart := SubStr(CurText, 1, 1) == "[" || SubStr(CurText, 1, 1) == "【"
            if (IsArrayStart) {
                ArrayEndPos := GetArrayEndPos(Text, LastSplitPos)
                ArrayText := SubStr(Text, LastSplitPos + 2, ArrayEndPos - LastSplitPos - 2)
                ResArr.Push(GetArray(ArrayText))
                Pos := ArrayEndPos + 1
            }
            else {
                CurText := GetEscapeValue(CurText)
                ResArr.Push(CurText)
            }
        }
        LastSplitPos := Pos
        Pos := GetNextSplitPos(Text, LastSplitPos)
    }

    if (Text == "")
        return ResArr
    else if (LastSplitPos == StrLen(Text)) {
        ResArr.Push("")
        return
    }
    else if (LastSplitPos < StrLen(Text)) {
        LastValue := SubStr(Text, LastSplitPos + 1)
        IsArrayStart := SubStr(LastValue, 1, 1) == "[" || SubStr(LastValue, 1, 1) == "【"
        IsArrayEnd := SubStr(LastValue, StrLen(LastValue)) == "]" || SubStr(LastValue, StrLen(LastValue)) == "】"
        if (IsArrayStart && IsArrayEnd) {
            ; 整段为 [ ... ]：解析内部为子数组，避免 "[a]" 被误做成 ["[a]"]
            ArrayText := SubStr(LastValue, 2, StrLen(LastValue) - 2)
            ResArr.Push(GetArray(ArrayText))
        } else {
            ResArr.Push(GetEscapeValue(LastValue))
        }
    }
    return ResArr
}

GetNextSplitPos(Text, StartPos) {
    EPos := InStr(Text, ",", false, StartPos + 1)
    CPos := InStr(Text, "，", false, StartPos + 1)
    Pos := (EPos == 0 || CPos == 0) ? Max(EPos, CPos) : Min(EPos, CPos)
    if (Pos == 0)
        return 0

    if (Pos == StartPos + 1)
        return Pos

    LastStr := SubStr(Text, Pos - 1, 1)
    while (LastStr == "\") {
        StartPos := Pos
        EPos := InStr(Text, ",", false, StartPos + 1)
        CPos := InStr(Text, "，", false, StartPos + 1)
        Pos := (EPos == 0 || CPos == 0) ? Max(EPos, CPos) : Min(EPos, CPos)
        if (Pos == 0)
            return 0

        if (Pos == StartPos + 1)
            return Pos

        LastStr := SubStr(Text, Pos - 1, 1)
    }

    return Pos
}

GetArrayEndPos(Text, StartPos) {
    EPos := InStr(Text, "]", false, StartPos + 1)
    CPos := InStr(Text, "】", false, StartPos + 1)
    Pos := (EPos == 0 || CPos == 0) ? Max(EPos, CPos) : Min(EPos, CPos)
    if (Pos == 0)
        return 0

    LastStr := SubStr(Text, Pos - 1, 1)
    while (LastStr == "\") {
        StartPos := Pos
        EPos := InStr(Text, ",", false, StartPos + 1)
        CPos := InStr(Text, "，", false, StartPos + 1)
        Pos := (EPos == 0 || CPos == 0) ? Max(EPos, CPos) : Min(EPos, CPos)
        if (Pos == 0)
            return 0

        LastStr := SubStr(Text, Pos - 1, 1)
    }

    return Pos
}

;获取转义后的值
GetEscapeValue(Value) {
    Value := StrReplace(Value, "\,", ",")
    Value := StrReplace(Value, "\，", "，")
    Value := StrReplace(Value, "\[", "[")
    Value := StrReplace(Value, "\【", "【")
    Value := StrReplace(Value, "\]", "]")
    Value := StrReplace(Value, "\】", "】")
    Value := StrReplace(Value, "\⎖", "\")
    return Value
}

GetGuiArrNameArr() {
    ResultArr := []
    for Key in MySoftData.GlobalArrMap {
        ResultArr.Push(Key)
    }
    return ResultArr
}

TryGetArrValue(&ResArr, ArrName, variTip := true) {
    if (!MySoftData.ArrayMap.Has(ArrName)) {
        if (variTip && MainSoftData.NoVariableTip)
            RMTErrorShow(GetLang("当前环境不存在数组") ArrName, RMT_LV_WARN, "宏")
        return false
    }

    ResArr := MySoftData.ArrayMap[ArrName]
    return true
}

GetCmdArray(Data, tableItem, index, variTip := true) {
    if (!MySoftData.ArrayMap.Has(Data.Name)) {
        if (variTip && MainSoftData.NoVariableTip)
            RMTErrorShow(GetLang("当前环境不存在数组") Data.Name, RMT_LV_WARN, "宏")
        return ""
    }

    ResArr := MySoftData.ArrayMap[Data.Name]
    if (Data.MainIndex != 0) {
        isHas := TryGetTabVarValue(&Value, tableItem, index, Data.MainIndex, variTip)
        if (!isHas)
            return ""

        if (ResArr.Length < Value) {
            if (variTip && MainSoftData.NoVariableTip) {
                str1 := Format(GetLang("数组：{}  长度：{}"), Data.Name, ResArr.Length)
                str2 := Format("无法获取第{}的值", Value)
                MsgBox(str1 "`n" str2)
            }
            return ""
        }
        ResArr := ResArr[Value]
    }

    if (Data.MainIndex != 0 && !IsObject(ResArr)) {
        if (variTip && MainSoftData.NoVariableTip) {
            str1 := Format(GetLang("数组：{}  第{}个值不是数组"), Data.Name, Value)
            MsgBox(str1)
        }
        return ""
    }
    return ResArr
}

SetArrayDataNewArr(Data) {
    NewArrName := ""
    if (Data.Type == "创建")
        NewArrName := Data.Name
    else if (Data.Type == "克隆") {
        NewArrName := Data.SaveName
    }
    else if (Data.Type == "取值" || Data.Type == "移除" || Data.Type == "移除最后") {
        if (Data.SaveType == "数组")
            NewArrName := Data.SaveName
    }

    if (NewArrName != "")
        MySoftData.GlobalArrMap[NewArrName] := true
}

SetArrayDataNewVar(Data) {
    NewVarName := ""
    if (Data.Type == "包含" || Data.Type == "长度")
        NewVarName := Data.SaveName
    else if (Data.Type == "取值" || Data.Type == "移除" || Data.Type == "移除最后") {
        if (Data.SaveType == "变量")
            NewVarName := Data.SaveName
    }

    if (NewVarName != "")
        MySoftData.GlobalVariMap[NewVarName] := true
}

ArrayCheckIfContain(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    if (Data.ArgsType == "变量或值") {
        isHas := TryGetTabVarValue(&Value, tableItem, index, Data.ArgsName, true)
        if (!isHas)
            return

        Res := 0
        loop SourceArr.Length {
            if (SourceArr[A_Index] == Value) {
                Res := 1
                break
            }
        }
    }
    else if (Data.ArgsType == "数组") {
        if (!MySoftData.ArrayMap.Has(Data.ArgsName)) {
            if (MainSoftData.NoVariableTip)
                RMTErrorShow(GetLang("当前环境不存在数组") Data.Name, RMT_LV_WARN, "宏")
            return
        }

        Res := 0
        ArgsStr := GetArrayStr(MySoftData.ArrayMap[Data.ArgsName])
        loop SourceArr.Length {
            if (IsObject(SourceArr[A_Index])) {
                if (GetArrayStr(SourceArr[A_Index]) == ArgsStr) {
                    Res := 1
                    break
                }
            }
        }
    }
    MySetGlobalVariable([Data.SaveName], [Res], false)
}

ArrayGetIndexValue(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    isHas := TryGetTabVarValue(&GetIndex, tableItem, index, Data.ArgsIndex, true)
    if (!isHas)
        return

    if (SourceArr.Length < GetIndex) {
        if (MainSoftData.NoVariableTip) {
            tip1 := Format(GetLang("数组：{} 长度：{}"), Data.Name, SourceArr.Length)
            tip2 := Format(GetLang("数组：{}  子数组{}  长度：{}"), Data.Name, MainIndex, SourceArr.Length)
            str1 := MainIndex == 0 ? tip1 : tip2
            str2 := Format("无法获取第{}的值", GetIndex)
            MsgBox(str1 "`n" str2)
        }
        return ""
    }
    Value := SourceArr[GetIndex]

    if (Data.SaveType == "变量")
        MySetGlobalVariable([Data.SaveName], [Value], false)
    else if (Data.SaveType == "数组")
        MySetGlobalArray(Data.SaveName, Value)
}

ArrayModifyIndexValue(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    isHas := TryGetTabVarValue(&SetIndex, tableItem, index, Data.ArgsIndex, true)
    if (!isHas)
        return

    if (SourceArr.Length < SetIndex) {
        if (MainSoftData.NoVariableTip) {
            tip1 := Format(GetLang("数组：{} 长度：{}"), Data.Name, SourceArr.Length)
            tip2 := Format(GetLang("数组：{}  子数组{}  长度：{}"), Data.Name, MainIndex, SourceArr.Length)
            str1 := MainIndex == 0 ? tip1 : tip2
            str2 := Format("无法修改第{}的值", SetIndex)
            MsgBox(str1 "`n" str2)
        }
        return ""
    }

    if (Data.ArgsType == "变量或值") {
        isHas := TryGetTabVarValue(&Value, tableItem, index, Data.ArgsName, true)
        if (!isHas)
            return
        MyModifyGlobalArray(Data.Name, MainIndex, SetIndex, 0, Value)
    }
    else if (Data.ArgsType == "数组") {
        if (!MySoftData.ArrayMap.Has(Data.ArgsName)) {
            if (MainSoftData.NoVariableTip)
                RMTErrorShow(GetLang("当前环境不存在数组") Data.Name, RMT_LV_WARN, "宏")
            return
        }
        Value := MySoftData.ArrayMap[Data.ArgsName]
        MyModifyGlobalArray(Data.Name, MainIndex, SetIndex, 1, Value)
    }
}

ArrayInsertIndexValue(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    isHas := TryGetTabVarValue(&InsertIndex, tableItem, index, Data.ArgsIndex, true)
    if (!isHas)
        return

    if (SourceArr.Length < InsertIndex) {
        if (MainSoftData.NoVariableTip) {
            TryGetTabVarValue(&SubIndex, tableItem, index, Data.MainIndex, false)
            tip1 := Format(GetLang("数组：{} 长度：{}"), Data.Name, SourceArr.Length)
            tip2 := Format(GetLang("数组：{}  子数组{}  长度：{}"), Data.Name, SubIndex, SourceArr.Length)
            str1 := SubIndex == 0 ? tip1 : tip2
            str2 := Format("无法在第{}位置插入数据", InsertIndex)
            MsgBox(str1 "`n" str2)
        }
        return ""
    }

    if (Data.ArgsType == "变量或值") {
        isHas := TryGetTabVarValue(&Value, tableItem, index, Data.ArgsName, true)
        if (!isHas)
            return
        MyInsertGlobalArray(Data.Name, MainIndex, InsertIndex, 0, Value)
    }
    else if (Data.ArgsType == "数组") {
        if (!MySoftData.ArrayMap.Has(Data.ArgsName)) {
            if (MainSoftData.NoVariableTip)
                RMTErrorShow(GetLang("当前环境不存在数组") Data.Name, RMT_LV_WARN, "宏")
            return
        }
        Value := MySoftData.ArrayMap[Data.ArgsName]
        MyInsertGlobalArray(Data.Name, MainIndex, InsertIndex, 1, Value)
    }
}

ArrayPushValue(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    PushIndex := SourceArr.Length + 1
    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    if (Data.ArgsType == "变量或值") {
        isHas := TryGetTabVarValue(&Value, tableItem, index, Data.ArgsName, true)
        if (!isHas)
            return
        MyInsertGlobalArray(Data.Name, MainIndex, PushIndex, 0, Value)
    }
    else if (Data.ArgsType == "数组") {
        if (!MySoftData.ArrayMap.Has(Data.ArgsName)) {
            if (MainSoftData.NoVariableTip)
                RMTErrorShow(GetLang("当前环境不存在数组") Data.Name, RMT_LV_WARN, "宏")
            return
        }
        Value := MySoftData.ArrayMap[Data.ArgsName]
        MyInsertGlobalArray(Data.Name, MainIndex, PushIndex, 1, Value)
    }
}

ArrayRemoveAtIndex(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    isHas := TryGetTabVarValue(&RemoveIndex, tableItem, index, Data.ArgsIndex, true)
    if (!isHas)
        return

    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    if (SourceArr.Length < RemoveIndex) {
        if (MainSoftData.NoVariableTip) {
            tip1 := Format(GetLang("数组：{} 长度：{}"), Data.Name, SourceArr.Length)
            tip2 := Format(GetLang("数组：{}  子数组{}  长度：{}"), Data.Name, MainIndex, SourceArr.Length)
            str1 := MainIndex == 0 ? tip1 : tip2
            str2 := Format("无法移除第{}位置的数据", RemoveIndex)
            MsgBox(str1 "`n" str2)
        }
        return
    }
    Value := SourceArr[RemoveIndex]
    MyRemoveAtGlobalArray(Data.Name, MainIndex, RemoveIndex)

    if (Data.SaveType == "变量")
        MySetGlobalVariable([Data.SaveName], [Value], false)
    else if (Data.SaveType == "数组")
        MySetGlobalArray(Data.SaveName, Value)
}

ArrayPopValue(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return
    if (SourceArr.Length == 0) {
        if (MainSoftData.NoVariableTip) {
            tip1 := Format(GetLang("数组：{} 长度：{}"), Data.Name, SourceArr.Length)
            tip2 := Format(GetLang("数组：{}  子数组{}  长度：{}"), Data.Name, MainIndex, SourceArr.Length)
            str1 := MainIndex == 0 ? tip1 : tip2
            str2 := Format("无法移除末尾的数据")
            MsgBox(str1 "`n" str2)
        }
        return
    }

    TryGetTabVarValue(&MainIndex, tableItem, index, Data.MainIndex, false)
    Value := SourceArr[SourceArr.Length]
    MyRemoveAtGlobalArray(Data.Name, MainIndex, SourceArr.Length)

    if (Data.SaveType == "变量")
        MySetGlobalVariable([Data.SaveName], [Value], false)
    else if (Data.SaveType == "数组")
        MySetGlobalArray(Data.SaveName, Value)
}

ArrayReverse(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    ResArr := []
    loop SourceArr.Length {
        Value := SourceArr[SourceArr.Length - A_Index + 1]
        ResArr.Push(Value)
    }

    MySetGlobalArray(Data.SaveName, ResArr)
}

ArrayGetLength(Data, tableItem, index) {
    SourceArr := GetCmdArray(Data, tableItem, index, true)
    if (SourceArr == "")
        return

    Value := SourceArr.Length
    MySetGlobalVariable([Data.SaveName], [Value], false)
}

ArrayTrimRightNull(Arr) {
    if (!IsObject(Arr))
        return
    loop {
        if (Arr.Length == 0 || Arr[Arr.Length] != "")
            return

        Arr.Pop()
    }
}
