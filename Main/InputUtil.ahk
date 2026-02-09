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
    MyInputStateGui.TrueAction := InputBoxTrueAction
    MyInputStateGui.FalseAction := InputBoxFalseAction
    MyInputStateGui.HideAction := InputBoxHideAciton
    MyInputStateGui.ShowGui()
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

    if (Data.ReadType == "表格行") {
        
    }

}
