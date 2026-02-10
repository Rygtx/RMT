#Requires AutoHotkey v2.0

InputPopUp(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_暂停所有宏")

    isHide := false
    InputBoxSureAction(Content) {
        MySetGlobalVariable([Data.SaveName], [Content], Data.IsIgnoreExist)
    }
    InputBoxHideAction() {
        isHide := true
    }
    Label := GetLang("变量名：") Data.SaveName
    Content := ""
    if (MySoftData.VariableMap.Has(Data.SaveName))
        Content := MySoftData.VariableMap[Data.SaveName]

    MyInputGui.SureAction := InputBoxSureAction
    MyInputGui.HideAction := InputBoxHideAction
    MyInputGui.ShowGui(Label, Content)
    while (!isHide) {
        Sleep(200)
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_恢复所有宏")
}

InputStateValue(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_暂停所有宏")

    isHide := false
    InputBoxTrueAction() {
        MySetGlobalVariable([Data.SaveName], [1], Data.IsIgnoreExist)
    }
    InputBoxFalseAction() {
        MySetGlobalVariable([Data.SaveName], [0], Data.IsIgnoreExist)
    }
    InputBoxHideAciton() {
        isHide := true
    }
    MyInputBtnGui.TrueAction := InputBoxTrueAction
    MyInputBtnGui.FalseAction := InputBoxFalseAction
    MyInputBtnGui.HideAction := InputBoxHideAciton
    MyInputBtnGui.ShowGui(1)
    while (!isHide) {
        Sleep(200)
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_恢复所有宏")
}

InputTextFile(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return
    if (!FileExist(Data.FilePath)) {
        MsgBox(GetLang("{}文件不存在"), Data.FilePath)
        return
    }

    if (Data.ReadType == "读取全部内容") {
        Content := FileRead(Data.FilePath, Data.Encoding)
        MySetGlobalVariable([Data.SaveName], [Content], Data.IsIgnoreExist)
    }
    else if (Data.ReadType == "指定行") {
        Content := ""
        FileEncoding(Data.Encoding)
        loop read, Data.FilePath {
            if (A_Index = Data.FileRow) {
                Content := A_LoopReadLine
                break
            }
        }
        MySetGlobalVariable([Data.SaveName], [Content], Data.IsIgnoreExist)
    }
    else if (Data.ReadType == "逐行读取") {
        ResArr := []
        FileEncoding(Data.Encoding)
        loop read, Data.FilePath {
            if (A_Index < Data.FileRow)
                continue
            ResArr.Push(A_LoopReadLine)
        }
        MySetGlobalArray(Data.SaveName, ResArr)
    }
}

InputExcel(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return
    if (!FileExist(Data.FilePath)) {
        MsgBox(GetLang("{}文件不存在"), Data.FilePath)
        return
    }

    HasRow := TryGetVariableValue(&Row, tableItem, index, Data.Row, true)
    HasCol := TryGetVariableValue(&Col, tableItem, index, Data.Col, true)
    if (!HasRow || !HasCol)
        return

    if (Data.ReadType == "单元格") {
        IsOk := ExcelCellToRead(Data.FilePath, Data.NameOrSerial, Row, Col, &ResArr)
        if (IsOk)
            MySetGlobalVariable([Data.SaveName], [ResArr], Data.IsIgnoreExist)
    }
    else if (Data.ReadType == "表格行") {
        IsOk := ExcelRowToRead(Data.FilePath, Data.NameOrSerial, Row, Col, &ResArr)
        if (IsOk)
            MySetGlobalArray(Data.SaveName, ResArr)
    }
    else if (Data.ReadType == "表格列") {
        IsOk := ExcelColToRead(Data.FilePath, Data.NameOrSerial, Row, Col, &ResArr)
        if (IsOk)
            MySetGlobalArray(Data.SaveName, ResArr)
    }
    else if (Data.ReadType == "指定区域-行") {
        HasEndRow := TryGetVariableValue(&EndRow, tableItem, index, Data.EndRow, true)
        HasEndCol := TryGetVariableValue(&EndCol, tableItem, index, Data.EndCol, true)
        if (!HasEndRow || !HasEndCol)
            return
        IsOk := ExcelRangeRowToRead(Data.FilePath, Data.NameOrSerial, Row, Col, EndRow, EndCol, &ResArr)
        if (IsOk)
            MySetGlobalArray(Data.SaveName, ResArr)
    }
    else if (Data.ReadType == "指定区域-列") {
        HasEndRow := TryGetVariableValue(&EndRow, tableItem, index, Data.EndRow, true)
        HasEndCol := TryGetVariableValue(&EndCol, tableItem, index, Data.EndCol, true)
        if (!HasEndRow || !HasEndCol)
            return
        IsOk := ExcelRangeColToRead(Data.FilePath, Data.NameOrSerial, Row, Col, EndRow, EndCol, &ResArr)
        if (IsOk)
            MySetGlobalArray(Data.SaveName, ResArr)
    }

}

InputContinue(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_暂停所有宏")

    isHide := false
    InputBtnHideAciton() {
        isHide := true
    }
    MyInputBtnGui.HideAction := InputBtnHideAciton
    MyInputBtnGui.ShowGui(2)
    while (!isHide) {
        Sleep(200)
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_恢复所有宏")
}

InputContinueAndCencel(Data, tableItem, index) {
    if (Data.IsIgnoreExist && MySoftData.ArrayMap.Has(Data.SaveName))
        return

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_暂停所有宏")

    isHide := false
    InputBtnCancelAciton() {
        if (Data.CancelType == "终止当前宏")
            MySubMacroStopAction(tableItem.Index, index)
        if (Data.CancelType == "终止所有宏")
            MyExcuteRMTCMDAction("RMT指令_终止所有宏")
    }
    InputBtnHideAciton() {
        isHide := true
    }
    MyInputBtnGui.CancelAction := InputBtnCancelAciton
    MyInputBtnGui.HideAction := InputBtnHideAciton
    MyInputBtnGui.ShowGui(3)
    while (!isHide) {
        Sleep(200)
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_恢复所有宏")
}
