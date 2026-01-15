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
                ArrayText := SubStr(Text, LastSplitPos + 2, ArrayEndPos - LastSplitPos + 2)
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
    
    if (LastSplitPos == StrLen(Text)) {
        ResArr.Push("")
        return
    }
    else if (LastSplitPos < StrLen(Text)) {
        LastValue := SubStr(Text, LastSplitPos + 1)
        IsArrayStart := SubStr(LastValue, 1, 1) == "[" || SubStr(LastValue, 1, 1) == "【"
        IsArrayEnd := SubStr(LastValue, StrLen(LastValue)) == "]" || SubStr(LastValue, StrLen(LastValue)) == "】"
        IsArray := IsArrayStart && IsArrayEnd
        LastValue := GetEscapeValue(LastValue)
        LastValue := IsArray ? [LastValue] : LastValue
        ResArr.Push(LastValue)
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
