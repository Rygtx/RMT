#Requires AutoHotkey v2.0

CompatGetData(Symbol, LineStr, FilePath) {
    FoundPos := InStr(LineStr, "=")
    if (SubStr(LineStr, 1, StrLen(Symbol)) != Symbol)
        return ""

    if (FoundPos == 0)
        return ""

    SerialStr := SubStr(LineStr, 1, FoundPos - 1)
    saveStr := IniRead(FilePath, IniSection, SerialStr, "")
    Data := JSON.parse(saveStr, , false)

    if (saveStr == "")
        return ""

    return Data
}

CompatMacro(MacroStr, &isFix) {
    CMDArr := SplitMacro(MacroStr)
    isFix := false
    loop CMDArr.Length {
        paramArr := SplitCommand(CMDArr[A_Index])

        ;1.0.9F3 间隔指令调整 统一使用两个参数  调整处理时机
        if (paramArr[1] == "间隔" && paramArr.Length == 3) {
            isFix := true
            paramArr[2] := paramArr[3]
            paramArr.RemoveAt(3)
            CMDArr[A_Index] := GetCmdByParams(paramArr)
        }

        ;1.1F1 按键指令动作类型改成中文
        if (paramArr[1] == "按键" && IsInteger(paramArr[3])) {
            keyTypeMap := Map(1, "按下", 2, "松开", 3, "点击")
            if (keyTypeMap.Has(Integer(paramArr[3]))) {
                isFix := true
                paramArr[3] := keyTypeMap[Integer(paramArr[3])]
                CMDArr[A_Index] := GetCmdByParams(paramArr)
            }
        }
    }
    MacroStr := GetMacroStrByCmdArr(CMDArr)
    return MacroStr
}

;1.0.8F4到新版本兼容, 模块中新增菜单模块相关数据
Compat1_0_8F4FlodInfo(FoldInfo) {
    if (FoldInfo == "" || ObjHasOwnProp(FoldInfo, "FrontInfoArr"))
        return

    FoldInfo.FrontInfoArr := []
    FoldInfo.TKTypeArr := []
    FoldInfo.TKArr := []
    FoldInfo.HoldTimeArr := []
    loop FoldInfo.RemarkArr.Length {
        FoldInfo.FrontInfoArr.Push("")
        FoldInfo.TKTypeArr.Push(1)
        FoldInfo.TKArr.Push("")
        FoldInfo.HoldTimeArr.Push(500)
    }
}

;1.0.8F7到新版本兼容, 新增鼠标类型
CompatMMPro(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "MMPro"
    loop read, filePath {
        LineStr := A_LoopReadLine
        FoundPos := InStr(LineStr, "=")
        if (SubStr(LineStr, 1, StrLen(Symbol)) != Symbol)
            continue

        if (FoundPos == 0)
            continue

        SerialStr := SubStr(LineStr, 1, FoundPos - 1)
        saveStr := IniRead(FilePath, IniSection, SerialStr, "")
        Data := JSON.parse(saveStr, , false)

        if (saveStr == "")
            continue

        ;1.0.8F7到新版本兼容, 新增鼠标类型
        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ActionType")) {
            Data.ActionType := 1
            hasFix := true
        }

        ;1.0.9F4 新增窗口分辨率映射不同的配置
        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ConfigName")) {
            Data.ConfigName := "默认"
            Data.ConfigArr := []
            hasFix := true

        }

        ;自动选择对应的窗口规则配置如果有的话
        if (!Data.ConfigArr.Length == 0) {
            CurConfigRuleStr := StrSplit(Data.ConfigName, "_")[1]
            CurScreenRuleStr := Format("{}*{}", A_ScreenWidth, A_ScreenHeight)
            ;默认就是这个配置就不用更换了
            if (CurConfigRuleStr == CurScreenRuleStr)
                continue

            ConfigData := ""
            loop Data.ConfigArr.Length {
                ConfigRuleStr := StrSplit(Data.ConfigArr[A_Index].ConfigName, "_")[1]
                if (ConfigRuleStr == CurScreenRuleStr) {
                    ConfigData := Data.ConfigArr.RemoveAt(A_Index)
                    break
                }
            }
            ;匹配上了，交换内容
            if (ConfigData != "") {
                LastConfig := Object()
                LastConfig.ConfigName := Data.ConfigName
                LastConfig.PosVarX := Data.PosVarX
                LastConfig.PosVarY := Data.PosVarY
                LastConfig.ActionType := Data.ActionType
                LastConfig.IsRelative := Data.IsRelative
                LastConfig.IsGameView := Data.IsGameView
                LastConfig.Speed := Data.Speed
                LastConfig.Count := Data.Count
                LastConfig.Interval := Data.Interval
                Data.ConfigArr.Push(LastConfig)

                Data.ConfigName := ConfigData.ConfigName
                Data.PosVarX := ConfigData.PosVarX
                Data.PosVarY := ConfigData.PosVarY
                Data.ActionType := ConfigData.ActionType
                Data.IsRelative := ConfigData.IsRelative
                Data.IsGameView := ConfigData.IsGameView
                Data.Speed := ConfigData.Speed
                Data.Count := ConfigData.Count
                Data.Interval := ConfigData.Interval

                hasFix := true
            }

        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

;1.0.9F1到新版本兼容 增加配置音选项
Compat1_0_9F1TipSound(tableItem) {
    if (tableItem.ModeArr.Length == tableItem.StartTipSoundArr.Length &&
        tableItem.ModeArr.Length == tableItem.EndTipSoundArr.Length)
        return

    for index, value in tableItem.ModeArr {
        if (tableItem.StartTipSoundArr.Length < index) {
            tableItem.StartTipSoundArr.Push(1)
        }

        if (tableItem.EndTipSoundArr.Length < index) {
            tableItem.EndTipSoundArr.Push(1)
        }
    }
}

CompatCMD(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    loop MySoftData.TabSymbolArr.Length {
        symbol := GetTableSymbol(A_Index)
        loop {
            MacroLabel := symbol "MacroArr" A_Index
            MacroStr := IniRead(filePath, IniSection, MacroLabel, "")
            if (MacroStr == "")
                break

            MacroStr := CompatMacro(MacroStr, &isFix)
            if (isFix) {
                hasFix := true
                IniWrite(MacroStr, filePath, IniSection, MacroLabel)
            }
        }

    }
    return hasFix
}

CompatSubMacro(FilePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "SubMacro"
    loop read, FilePath {
        LineStr := A_LoopReadLine
        FoundPos := InStr(LineStr, "=")
        if (SubStr(LineStr, 1, StrLen(Symbol)) != Symbol)
            continue

        if (FoundPos == 0)
            continue

        SerialStr := SubStr(LineStr, 1, FoundPos - 1)
        saveStr := IniRead(FilePath, IniSection, SerialStr, "")
        Data := JSON.parse(saveStr, , false)
        if (saveStr == "")
            continue

        ;宏插入可以指定次数
        if (!ObjHasOwnProp(Data, "InsertCount")) {
            hasFix := true
            Data.InsertCount := 1
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, FilePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatSearch(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "Search"
    loop read, filePath {
        Data := CompatGetData(Symbol, A_LoopReadLine, filePath)
        if (Data == "")
            continue

        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatSearchPro(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "Search"
    loop read, filePath {
        LineStr := A_LoopReadLine
        FoundPos := InStr(LineStr, "=")
        if (SubStr(LineStr, 1, StrLen(Symbol)) != Symbol)
            continue

        if (FoundPos == 0)
            continue

        SerialStr := SubStr(LineStr, 1, FoundPos - 1)
        saveStr := IniRead(FilePath, IniSection, SerialStr, "")
        Data := JSON.parse(saveStr, , false)

        if (saveStr == "")
            continue

        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ConfigName")) {
            Data.ConfigName := "默认"
            Data.ConfigArr := []
            hasFix := true
        }

        ;自动选择对应的窗口规则配置如果有的话
        if (Data.ConfigArr.Length != 0) {
            CurConfigRuleStr := StrSplit(Data.ConfigName, "_")[1]
            CurScreenRuleStr := Format("{}*{}", A_ScreenWidth, A_ScreenHeight)
            ;默认就是这个配置就不用更换了
            if (CurConfigRuleStr == CurScreenRuleStr)
                continue

            ConfigData := ""
            loop Data.ConfigArr.Length {
                ConfigRuleStr := StrSplit(Data.ConfigArr[A_Index].ConfigName, "_")[1]
                if (ConfigRuleStr == CurScreenRuleStr) {
                    ConfigData := Data.ConfigArr.RemoveAt(A_Index)
                    break
                }
            }
            ;匹配上了，交换内容
            if (ConfigData != "") {
                LastConfig := Object()
                LastConfig.ConfigName := Data.ConfigName
                LastConfig.SearchType := Data.SearchType
                LastConfig.SearchColor := Data.SearchColor
                LastConfig.SearchText := Data.SearchText
                LastConfig.SearchImagePath := Data.SearchImagePath
                LastConfig.Similar := Data.Similar
                LastConfig.OCRType := Data.OCRType
                LastConfig.SearchImageType := Data.SearchImageType
                LastConfig.StartPosX := Data.StartPosX
                LastConfig.StartPosY := Data.StartPosY
                LastConfig.EndPosX := Data.EndPosX
                LastConfig.EndPosY := Data.EndPosY
                LastConfig.SearchCount := Data.SearchCount
                LastConfig.SearchInterval := Data.SearchInterval
                LastConfig.MouseActionType := Data.MouseActionType
                LastConfig.Speed := Data.Speed
                LastConfig.ClickCount := Data.ClickCount
                Data.ConfigArr.Push(LastConfig)

                Data.ConfigName := ConfigData.ConfigName
                Data.SearchType := ConfigData.SearchType
                Data.SearchColor := ConfigData.SearchColor
                Data.SearchText := ConfigData.SearchText
                Data.SearchImagePath := ConfigData.SearchImagePath
                Data.Similar := ConfigData.Similar
                Data.OCRType := ConfigData.OCRType
                Data.SearchImageType := ConfigData.SearchImageType
                Data.StartPosX := ConfigData.StartPosX
                Data.StartPosY := ConfigData.StartPosY
                Data.EndPosX := ConfigData.EndPosX
                Data.EndPosY := ConfigData.EndPosY
                Data.SearchCount := ConfigData.SearchCount
                Data.SearchInterval := ConfigData.SearchInterval
                Data.MouseActionType := ConfigData.MouseActionType
                Data.Speed := ConfigData.Speed
                Data.ClickCount := ConfigData.ClickCount

                hasFix := true
            }
        }

        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatCompare(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "Compare"
    loop read, filePath {
        Data := CompatGetData(Symbol, A_LoopReadLine, filePath)
        if (Data == "")
            continue

        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatComparePro(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "Compare+"
    loop read, filePath {
        Data := CompatGetData(Symbol, A_LoopReadLine, filePath)
        if (Data == "")
            continue

        loop Data.MacroArr.Length {
            if (Data.MacroArr[A_Index] != "") {
                Data.MacroArr[A_Index] := CompatMacro(Data.MacroArr[A_Index], &isFix)
                hasFix := hasFix || isFix
            }
        }

        if (Data.DefaultMacro != "") {
            Data.DefaultMacro := CompatMacro(Data.DefaultMacro, &isFix)
            hasFix := hasFix || isFix
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatLoop(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    Symbol := "Loop"
    loop read, filePath {
        Data := CompatGetData(Symbol, A_LoopReadLine, filePath)
        if (Data == "")
            continue

        if (Data.LoopBody != "") {
            Data.LoopBody := CompatMacro(Data.LoopBody, &isFix)
            hasFix := hasFix || isFix
        }

        if (hasFix) {
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}
