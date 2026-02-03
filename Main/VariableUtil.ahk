#Requires AutoHotkey v2.0

SetGlobalData(macroStr, visitMap) {
    if (macroStr == "")
        return
    VariableMap := MySoftData.GlobalVariMap
    cmdArr := SplitMacro(macroStr)
    loop cmdArr.Length {
        paramArr := StrSplit(cmdArr[A_Index], "_")
        paramArr[1] := GetCmdStr(paramArr[1])
        if (visitMap.Has(paramArr[1]))
            continue
        SetCMDSerialData(cmdArr[A_Index])
        IsExVariable := InStr(paramArr[1], "变量提取")
        IsVariable := InStr(paramArr[1], "变量") && !IsExVariable
        IsTextOps := InStr(paramArr[1], "文本处理")
        IsOpera := InStr(paramArr[1], "运算")
        IsSearchPro := InStr(paramArr[1], "搜索Pro")
        IsSearch := InStr(paramArr[1], "搜索") && !IsSearchPro
        IsLoop := InStr(paramArr[1], "循环")
        IsIfPro := InStr(paramArr[1], "如果Pro")
        IsIf := InStr(paramArr[1], "如果") && !IsIfPro
        IsArray := InStr(paramArr[1], "数组")
        IsVarRelate := IsVariable || IsExVariable || IsTextOps || IsIf || IsOpera || IsSearch || IsSearchPro
            || IsLoop || IsIfPro || IsArray
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
        else if (IsTextOps) {
            if (Data.SaveType == "变量")
                VariableMap[Data.SaveName] := true
            if (Data.SaveType == "数组")
                MySoftData.GlobalArrMap[Data.SaveName] := true
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
            VariableMap[GetLang("循环次数")] := true
        }
        else if (IsArray) {
            SetArrayDataNewArr(Data)
            SetArrayDataNewVar(Data)
        }

        if (IsIf || IsSearch || IsSearchPro) {
            SetGlobalData(Data.TrueMacro, visitMap)
            SetGlobalData(Data.FalseMacro, visitMap)
        }
        else if (IsLoop) {
            SetGlobalData(Data.LoopBody, visitMap)
        }
        else if (IsIfPro) {
            for index, value in Data.MacroArr {
                SetGlobalData(value, visitMap)
            }
            SetGlobalData(Data.DefaultMacro, visitMap)
        }
    }
}

GetGuiVarArr() {
    ResultArr := []
    ResultMap := Map()
    SpecialKeyArr := [GetLang("循环次数"), GetLang("宏循环次数"), GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]

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
    SpecialKeyArr1 := [GetLang("循环次数"), GetLang("宏循环次数"), GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]
    SpecialKeyArr2 := [GetLang("当前鼠标坐标X"), GetLang("当前鼠标坐标Y")]
    SpecialKeyArr3 := [GetLang("循环次数"), GetLang("宏循环次数")]
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
