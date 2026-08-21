#Requires AutoHotkey v2.0

; Worker 环境：跨进程请求主进程弹窗（输入框/按钮条，共享主进程 XAML daemon）
; 发 EVENT 到主进程并阻塞等待回传（Worker 侧 OnEventMessage 收到 IPR/IBR 写入 _workerInputResult）
; 返回：args 数组（IPR: [ok, value]；IBR: [button]）；主进程不可达/超时返回 ""
; Worker 专属全局（rx/workIndex/parentHwnd）用 IsSet 保护：主程序不编译此路径，不触发 UseUnset 警告
WorkerInputRequest(opcode, args*) {
    global rx, workIndex, parentHwnd, _workerInputResult
    if (!IsSet(rx) || !IsSet(parentHwnd))
        return ""
    cmd := EncodeCommand(opcode, args*)
    payload := EncodeBatch(cmd)
    rx.Push(MsgType.EVENT, 0, payload)
    PostMessage(WM_WORKER_TO_MASTER, workIndex, 0, , "ahk_id " parentHwnd)
    _workerInputResult := ""
    ; 输入指令是用户交互型：一直等待主进程回传；防主进程异常卡死 Worker，设长超时兜底
    deadline := A_TickCount + 300000
    loop {
        Sleep(100)
        if (IsObject(_workerInputResult))
            break
        if (A_TickCount > deadline)
            return ""
    }
    r := _workerInputResult
    _workerInputResult := ""
    return r
}

InputPopUp(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    Label := GetLang("变量名：") Data.SaveName
    Content := ""
    if (MySoftData.VariableMap.Has(Data.SaveName))
        Content := MySoftData.VariableMap[Data.SaveName]

    if (IsSet(workIndex)) {
        ; Worker：主进程 XAML 输入框（共享 daemon），结果回传后直接设变量
        ; 日志按 Worker 索引分文件（多 Worker 并发写同一文件会锁冲突）
        worker_input_dbg := "C:\Users\yun\Desktop\rmt\_verify\worker_recv_" workIndex ".txt"
        result := WorkerInputRequest("IP", Label, Content)
        try FileAppend "IP result=" (IsObject(result) ? "[" (result.Length >= 1 ? result[1] : "") "|" (result.Length >= 2 ? result[2] : "") "]" : "EMPTY") "`n", worker_input_dbg
        if (IsObject(result) && result.Length >= 2 && result[1] == "1") {
            try FileAppend "IP saving SaveName=" Data.SaveName "`n", worker_input_dbg
            MySetGlobalVariable([Data.SaveName], [result[2]], false)
            try FileAppend "IP saved done`n", worker_input_dbg
        }
    } else {
        ; 主程序：本地 XAML 输入框
        isHide := false
        InputBoxSureAction(Content) {
            MySetGlobalVariable([Data.SaveName], [Content], false)
        }
        InputBoxHideAction() {
            isHide := true
        }
        MyInputGui.SureAction := InputBoxSureAction
        MyInputGui.HideAction := InputBoxHideAction
        MyInputGui.ShowGui(Label, Content)
        while (!isHide) {
            Sleep(200)
        }
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputStateValue(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    if (IsSet(workIndex)) {
        ; Worker：主进程按钮条（真值/假值）
        result := WorkerInputRequest("IB", "1")
        if (IsObject(result) && result[1] == "true")
            MySetGlobalVariable([Data.SaveName], [1], false)
        else if (IsObject(result) && result[1] == "false")
            MySetGlobalVariable([Data.SaveName], [0], false)
    } else {
        isHide := false
        InputBoxTrueAction() {
            MySetGlobalVariable([Data.SaveName], [1], false)
        }
        InputBoxFalseAction() {
            MySetGlobalVariable([Data.SaveName], [0], false)
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
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinue(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    if (IsSet(workIndex)) {
        ; Worker：主进程按钮条（继续）
        WorkerInputRequest("IB", "2")
    } else {
        isHide := false
        InputBtnHideAciton() {
            isHide := true
        }
        MyInputBtnGui.HideAction := InputBtnHideAciton
        MyInputBtnGui.ShowGui(2)
        while (!isHide) {
            Sleep(200)
        }
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinueAndCencel(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    if (IsSet(workIndex)) {
        ; Worker：主进程按钮条（继续/取消），取消时执行终止逻辑
        result := WorkerInputRequest("IB", "3")
        if (IsObject(result) && result[1] == "cancel") {
            if (Data.CancelType == "终止当前宏")
                MyStopMacro(tableItem.Index, index)
            if (Data.CancelType == "终止所有宏")
                MyExcuteRMTCMDAction("RMT指令_宏控制_终止所有宏")
        }
    } else {
        isHide := false
        InputBtnCancelAciton() {
            if (Data.CancelType == "终止当前宏")
                MyStopMacro(tableItem.Index, index)
            if (Data.CancelType == "终止所有宏")
                MyExcuteRMTCMDAction("RMT指令_宏控制_终止所有宏")
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
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}
