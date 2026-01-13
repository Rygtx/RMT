#Requires AutoHotkey v2.0

GetMacroStrGlobalVar(macroStr, VariableMap, visitMap) {
    if (macroStr == "")
        return
    cmdArr := SplitMacro(macroStr)
    loop cmdArr.Length {
        paramArr := StrSplit(cmdArr[A_Index], "_")
        paramArr[1] := StrReplace(paramArr[1], "🚫", "")
        if (visitMap.Has(paramArr[1]))
            continue
        SetCMDSerial(cmdArr[A_Index])
        IsExVariable := InStr(paramArr[1], "变量提取")
        IsVariable := InStr(paramArr[1], "变量") && !IsExVariable
        IsTextProcess := InStr(paramArr[1], "文本处理")
        IsOpera := InStr(paramArr[1], "运算")
        IsSearchPro := InStr(paramArr[1], "搜索Pro")
        IsSearch := InStr(paramArr[1], "搜索") && !IsSearchPro
        IsLoop := InStr(paramArr[1], "循环")
        IsIfPro := InStr(paramArr[1], "如果Pro")
        IsIf := InStr(paramArr[1], "如果") && !IsIfPro
        IsVarRelate := IsVariable || IsExVariable || IsTextProcess || IsIf || IsOpera || IsSearch || IsSearchPro
            || IsLoop || IsIfPro
        if (!IsVarRelate)
            continue
        visitMap[paramArr[1]] := true
        Cmd := RegExReplace(paramArr[1], "\d+")
        Data := GetMacroCMDData(paramArr[1])

        if (IsVariable || IsExVariable) {
            loop Data.ToggleArr.Length {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsTextProcess) {
            loop Data.ToggleArr.Length {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsIf) {
            if (Data.SaveToggle) {
                VariableMap[Data.SaveName] := true
            }
        }
        else if (IsOpera) {
            loop Data.ToggleArr.Length {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.UpdateNameArr[A_Index]] := true
            }
        }
        else if (IsSearch || IsSearchPro) {
            if (Data.ResultToggle) {
                VariableMap[Data.ResultSaveName] := true
            }

            if (Data.CoordToogle) {
                VariableMap[Data.CoordXName] := true
                VariableMap[Data.CoordYName] := true
            }
        }
        else if (IsLoop) {
            VariableMap[GetLang("指令循环次数")] := true
        }

        if (IsIf || IsSearch || IsSearchPro) {
            GetMacroStrGlobalVar(Data.TrueMacro, VariableMap, visitMap)
            GetMacroStrGlobalVar(Data.FalseMacro, VariableMap, visitMap)
        }
        else if (IsLoop) {
            GetMacroStrGlobalVar(Data.LoopBody, VariableMap, visitMap)
        }
        else if (IsIfPro) {
            for index, value in Data.MacroArr {
                GetMacroStrGlobalVar(value, VariableMap, visitMap)
            }
            GetMacroStrGlobalVar(Data.DefaultMacro, VariableMap, visitMap)
        }
    }
}

GetGuiVariableObjArr(VariableObjArr) {
    ResultArr := []
    ResultMap := Map()
    SpecialKeyArr := [GetLang("指令循环次数"), GetLang("宏循环次数"), GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]

    ; 将VariableObjArr中的变量添加到映射中
    for Value in VariableObjArr {
        ResultMap[Value] := true
    }

    ; 添加全局变量（如果不存在）
    for Key in MySoftData.GlobalVariMap {
        if !ResultMap.Has(Key) {
            ResultMap[Key] := true
        }
    }

    ;为了让特殊变量出现在末尾，先删除
    for curKey in SpecialKeyArr {
        if ResultMap.Has(curKey) {
            ResultMap.Delete(curKey)
        }
    }

    ; 将映射的键收集到数组中
    for Key in ResultMap {
        ResultArr.Push(Key)
    }

    ResultArr.Push(SpecialKeyArr*)
    return ResultArr
}

;mode 1:移除所有  2：移除坐标变量 3:移除循环计数变量
RemoveInVariable(VarArr, Mode := 1) {
    SpecialKeyArr1 := [GetLang("指令循环次数"), GetLang("宏循环次数"), GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]
    SpecialKeyArr2 := [GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]
    SpecialKeyArr3 := [GetLang("指令循环次数"), GetLang("宏循环次数")]
    SpecialMap := Map(1, SpecialKeyArr1, 2, SpecialKeyArr2, 3, SpecialKeyArr3)
    SpecialKeyArr := SpecialMap[Mode]

    ; 创建一个新数组来存储结果
    result := []

    ; 第一个循环：遍历原始数组的每个值
    for value in VarArr {
        found := false

        ; 第二个循环：检查这个值是否在特殊值数组中
        for specialValue in SpecialKeyArr {
            if value = specialValue {
                found := true
                break  ; 找到匹配项，跳出内层循环
            }
        }

        ; 如果没有找到匹配项，则添加到结果数组
        if (!found) {
            result.Push(value)
        }
    }

    return result
}
