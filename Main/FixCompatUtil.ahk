#Requires AutoHotkey v2.0

CompatGetData(LineStr, FilePath) {
    FoundPos := InStr(LineStr, "=")
    if (FoundPos == 0)
        return ""

    SerialStr := SubStr(LineStr, 1, FoundPos - 1)
    SaveStr := SubStr(LineStr, FoundPos + 1)
    ;部分A_LoopReadLine会因为编码问题错位，校验一下
    CheckStr := IniRead(FilePath, IniSection, SerialStr, "")
    SaveStr := StrLen(CheckStr) > StrLen(SaveStr) ? CheckStr : SaveStr
    Data := JSON.parse(SaveStr, , false)

    if (SaveStr == "")
        return ""
    FirstChar := SubStr(SaveStr, 1, 1)
    LastChar := SubStr(SaveStr, -1, 1)
    if (FirstChar != "{" || LastChar != "}")
        return ""

    return Data
}

CompatMacro(MacroStr, &isFix) {
    CMDArr := SplitMacro(MacroStr)
    isFix := false
    modifyKeyMap := Map("移动Pro", 1, "搜索", 1, "搜索Pro", 1, "运行", 1, "如果", 1, "如果Pro", 1, "输出", 1, "变量", 1,
        "变量提取", 1, "宏操作", 1, "运算", 1, "后台鼠标", 1, "后台按键", 1, "循环", 1)
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

        ;1.1 简化配置命令    形如搜索_Search1234_备注 => 搜索1234_备注
        if (modifyKeyMap.Has(paramArr[1])) {
            isFix := true
            textOnly := RegExReplace(paramArr[2], "\d+")
            numbersOnly := RegExReplace(paramArr[2], "\D+")
            paramArr[1] := paramArr[1] numbersOnly
            paramArr[2] := paramArr.Length == 3 ? paramArr[3] : ""
            paramArr.Pop()
            CMDArr[A_Index] := GetCmdByParams(paramArr)
        }
    }
    MacroStr := GetMacroStrByCmdArr(CMDArr)
    return MacroStr
}

CompatSerial(FilePath, Symbol, NewSymbol) {
    fileContent := FileRead(filePath)
    newContent := RegExReplace(fileContent, Symbol "(\d+)", NewSymbol "$1")
    if (newContent != fileContent) {
        FileDelete(filePath)
        FileAppend(newContent, filePath, "UTF-16")
        return true
    }
    return false
}

CompatPath(FilePath, Data) {
    SplitPath FilePath, &name, &dir, &ext, &name_no_ext, &drive
    SplitPath dir, &name, &dir, &ext, &SettingName, &drive
    if (!ObjHasOwnProp(Data, "SearchImagePath") || Data.SearchImagePath == "")
        return false

    StartPos := InStr(Data.SearchImagePath, "Setting", 1)
    SubPath := SubStr(Data.SearchImagePath, StartPos)
    NewPath1 := A_WorkingDir "\" SubPath    ;调整盘符

    FileNameArr := StrSplit(NewPath1, "\")
    NewPath2 := ""
    for index, value in FileNameArr {
        if (value == "Setting" && index + 2 <= FileNameArr.Length && FileNameArr[index + 2] == "Images") {
            FileNameArr[index + 1] := SettingName
        }
        NewPath2 .= value "\"
    }

    NewPath := RTrim(NewPath2, "\")     ;修改成对应配置下
    if (FileExist(NewPath)) {
        Data.SearchImagePath := NewPath
        return true
    }
    return false
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

CompatSearch(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Search", "搜索")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue
        curFix := CompatPath(filePath, Data)

        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            curFix := curFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            curFix := curFix || isFix
        }

        if (curFix) {
            hasFix := true
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
    hasFix := CompatSerial(filePath, "Search", "搜索Pro")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := CompatPath(filePath, Data)
        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ConfigName")) {
            Data.ConfigName := "默认"
            Data.ConfigArr := []
            curFix := true
        }

        ;自动选择对应的窗口规则配置如果有的话
        if (Data.ConfigArr.Length != 0) {
            curFix := CompatSearchProConfig(Data) || curFix
        }

        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            curFix := curFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            curFix := curFix || isFix
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatMMPro(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "MMPro", "移动Pro")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := false
        ;1.0.8F7到新版本兼容, 新增鼠标类型
        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ActionType")) {
            Data.ActionType := 1
            curFix := true
        }

        ;1.0.9F4 新增窗口分辨率映射不同的配置
        ;如果有了，那就说明是新版本，不需要兼容处理
        if (!ObjHasOwnProp(Data, "ConfigName")) {
            Data.ConfigName := "默认"
            Data.ConfigArr := []
            curFix := true
        }

        ;自动选择对应的窗口规则配置如果有的话
        if (!Data.ConfigArr.Length == 0) {
            curFix := CompatMMProConfig(Data) || curFix
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatOutput(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Output", "输出")
    return hasFix
}

CompatRun(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Run", "运行")
    return hasFix
}

CompatLoop(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    hasFix := CompatSerial(filePath, "Loop", "循环")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := false
        if (Data.LoopBody != "") {
            Data.LoopBody := CompatMacro(Data.LoopBody, &isFix)
            curFix := curFix || isFix
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatSubMacro(FilePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix

    hasFix := CompatSerial(filePath, "SubMacro", "宏操作")
    loop read, FilePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := false
        ;宏插入可以指定次数
        if (!ObjHasOwnProp(Data, "InsertCount")) {
            curFix := true
            Data.InsertCount := 1
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, FilePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatVariable(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Variable", "变量")
    return hasFix
}

CompatExVariable(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "ExVariable", "变量提取")
    return hasFix
}

CompatCompare(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Compare", "如果")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue
        curFix := false
        if (Data.TrueMacro != "") {
            Data.TrueMacro := CompatMacro(Data.TrueMacro, &isFix)
            curFix := curFix || isFix
        }

        if (Data.FalseMacro != "") {
            Data.FalseMacro := CompatMacro(Data.FalseMacro, &isFix)
            curFix := curFix || isFix
        }

        if (curFix) {
            hasFix := true
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

    hasFix := CompatSerial(filePath, "ComparePro", "如果Pro")
    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := false
        loop Data.MacroArr.Length {
            if (Data.MacroArr[A_Index] != "") {
                Data.MacroArr[A_Index] := CompatMacro(Data.MacroArr[A_Index], &isFix)
                curFix := curFix || isFix
            }
        }

        if (Data.DefaultMacro != "") {
            Data.DefaultMacro := CompatMacro(Data.DefaultMacro, &isFix)
            curFix := curFix || isFix
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }
    return hasFix
}

CompatOperation(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "Operation", "运算")

    loop read, filePath {
        Data := CompatGetData(A_LoopReadLine, filePath)
        if (Data == "")
            continue

        curFix := false

        ; 确保ExpressionArr字段存在
        if (!ObjHasOwnProp(Data, "ExpressionArr")) {
            Data.ExpressionArr := ["", "", "", ""]
            curFix := true
        }

        ; 迁移旧数据：如果ExpressionArr为空但OperationArr有内容，则将OperationArr复制到ExpressionArr
        loop 4 {
            if (Data.ExpressionArr.Has(A_Index) && Data.ExpressionArr[A_Index] == ""
                && Data.OperationArr.Has(A_Index) && Data.OperationArr[A_Index] != "") {
                Data.ExpressionArr[A_Index] := Data.OperationArr[A_Index]
                curFix := true
            }
        }

        ; 校准旧格式变量名到新格式{变量名}
        ; 旧格式：num1, var_name 等
        ; 新格式：{num1}, {var_name}
        loop 4 {
            if (Data.ExpressionArr.Has(A_Index) && Data.ExpressionArr[A_Index] != "") {
                oldExpr := Data.ExpressionArr[A_Index]
                newExpr := this.ConvertOldVariableFormat(oldExpr)
                if (newExpr != oldExpr) {
                    Data.ExpressionArr[A_Index] := newExpr
                    curFix := true
                }
            }
        }

        if (curFix) {
            hasFix := true
            saveStr := JSON.stringify(Data, 0)
            IniWrite(saveStr, filePath, IniSection, Data.SerialStr)
        }
    }

    return hasFix
}

; 将旧格式变量名转换为新格式{变量名}
ConvertOldVariableFormat(expr) {
    ; 匹配独立的变量名（非数字、包含字母/中文/下划线的标识符）
    ; 不匹配已经包裹在{}中的变量
    ; 不匹配作为数字一部分的变量名
    result := expr

    ; 使用正则查找旧格式变量名（不包含运算符、括号、数字前缀等）
    ; 匹配规则：以字母或中文开头，包含字母、数字、下划线、中文
    pos := 1
    loop {
        ; 匹配：运算符或括号后面跟着的变量名
        match := RegExMatch(result, "([\+\-\*/%\^\(\)])([a-zA-Z一-龥_][a-zA-Z0-9一-龥_]*)", &m, pos)
        if (!match) {
            ; 尝试匹配开头的变量名
            match := RegExMatch(result, "^([a-zA-Z一-龥_][a-zA-Z0-9一-龥_]*)", &m)
            if (!match)
                break
        }

        ; m[1] 是分隔符（运算符或括号），m[2] 是变量名
        ; m[0] 是整个匹配内容（分隔符+变量名）
        if (match > 0) {
            ; 如果匹配的是完整字符串（没有分隔符），则替换整个
            if (RegExMatch(m[0], "^[\+\-\*/%\^\(\)]$")) {
                ; 只有分隔符，跳过
                pos := match + StrLen(m[0])
                continue
            }

            ; 查找变量名部分
            varName := m[2]
            if (varName != "") {
                ; 替换为{变量名}格式
                if (InStr(m[0], "+") || InStr(m[0], "-") || InStr(m[0], "*") || InStr(m[0], "/")
                    || InStr(m[0], "%") || InStr(m[0], "^") || InStr(m[0], "(") || InStr(m[0], ")")) {
                    ; 有分隔符的情况
                    newPattern := m[1] "{" varName "}"
                    result := StrReplace(result, m[0], newPattern, , 1, &replaceCount)
                    pos := match + StrLen(newPattern)
                } else {
                    ; 开头的情况（无分隔符）
                    result := StrReplace(result, varName, "{" varName "}", , 1, &replaceCount)
                    pos := match + StrLen("{" varName "}")
                }
            } else {
                pos := match + StrLen(m[0])
            }
        } else {
            break
        }
    }

    return result
}

CompatBGMouse(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "BGMouse", "后台鼠标")
    return hasFix
}

CompatBGKey(filePath) {
    hasFix := false
    if (!FileExist(FilePath))
        return hasFix
    hasFix := CompatSerial(filePath, "BGKey", "后台按键")
    return hasFix
}

CompatSearchProConfig(Data) {
    isFix := false
    CurConfigRuleStr := StrSplit(Data.ConfigName, "_")[1]
    CurScreenRuleStr := Format("{}*{}", A_ScreenWidth, A_ScreenHeight)
    ;默认就是这个配置就不用更换了
    if (CurConfigRuleStr == CurScreenRuleStr)
        return isFix

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

        isFix := true
    }
    return isFix
}

CompatMMProConfig(Data) {
    isFix := false
    CurConfigRuleStr := StrSplit(Data.ConfigName, "_")[1]
    CurScreenRuleStr := Format("{}*{}", A_ScreenWidth, A_ScreenHeight)
    ;默认就是这个配置就不用更换了
    if (CurConfigRuleStr == CurScreenRuleStr)
        return isFix

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

        isFix := true
    }
    return isFix
}
