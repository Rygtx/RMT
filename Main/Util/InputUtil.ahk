#Requires AutoHotkey v2.0

; Worker 环境：跨进程请求主进程弹窗（输入框/按钮条，共享主进程 XAML daemon）
; 发 EVENT 到主进程并阻塞等待回传（Worker 侧 OnEventMessage 收到 IPR/IBR 写入 _workerInputResult）
; 返回：args 数组（IPR: [ok, value]；IBR: [button]）；主进程不可达/超时返回 ""
; Worker 专属全局（rx/workIndex/parentHwnd）用 IsSet 保护：主程序不编译此路径，不触发 UseUnset 警告
; 分支判定（四个输入函数共用）：Worker 由 WorkPool 启动，workIndex 为实际索引（≥1，CreateWorker idx）；
; 主进程 GraphMacroUtil.ahk:4 有占位 workIndex := 0，IsSet(workIndex) 恒真，若只判 IsSet 主进程单线程
; 会误走 WorkerInputRequest（rx/parentHwnd 未定义 → 直接返回 "" → 按钮条不弹/输入无效）。
; 因此 Worker 判定必须附加 workIndex > 0：主进程走本地 XAML 分支，Worker 走跨进程请求分支。
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

    if (IsSet(workIndex) && workIndex > 0) {
        ; Worker：主进程 XAML 输入框（共享 daemon），结果回传后直接设变量
        result := WorkerInputRequest("IP", Label, Content)
        if (IsObject(result) && result.Length >= 2 && result[1] == "1") {
            MySetGlobalVariable([Data.SaveName], [result[2]], false)
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

    if (IsSet(workIndex) && workIndex > 0) {
        ; Worker：主进程按钮条（真值/假值）
        result := WorkerInputRequest("IB", "1")
        if (IsObject(result) && result[1] == "true")
            MySetGlobalVariable([Data.SaveName], [1], false)
        else if (IsObject(result) && result[1] == "false")
            MySetGlobalVariable([Data.SaveName], [0], false)
    } else {
        ; 主程序：本地 XAML 按钮条（真值/假值），每请求独立实例（与 WorkPool isBtn 分支同构）
        ; 动态名解析：InputUtil.ahk 同时被 Worker 编译（Work.ahk→AssetUtil.ahk），
        ; Worker 无 InputBtnXamlGui 类，静态类引用会编译期报错（同 InputBtnXamlGui.ahk 内部模式）
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
        BtnGuiCls := "InputBtnXamlGui"
        BtnGui := %BtnGuiCls%()
        BtnGui.TrueAction := InputBoxTrueAction
        BtnGui.FalseAction := InputBoxFalseAction
        BtnGui.HideAction := InputBoxHideAciton
        BtnGui.ShowGui(1)
        ; XAML 事件经 SetTimer(-1, 0) 派发：Sleep 期间可被中断执行 TrueAction/HideAction（实测确认）
        ; _closed 兜底：XAML 构建失败或窗口被外部关闭时（OnWindowClosing）避免宏线程无限等待
        while (!isHide && !BtnGui._closed) {
            Sleep(200)
        }
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinue(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    if (IsSet(workIndex) && workIndex > 0) {
        ; Worker：主进程按钮条（继续）
        WorkerInputRequest("IB", "2")
    } else {
        ; 主程序：本地 XAML 按钮条（继续），每请求独立实例
        isHide := false
        InputBtnHideAciton() {
            isHide := true
        }
        BtnGuiCls := "InputBtnXamlGui"
        BtnGui := %BtnGuiCls%()
        BtnGui.HideAction := InputBtnHideAciton
        BtnGui.ShowGui(2)
        while (!isHide && !BtnGui._closed) {
            Sleep(200)
        }
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinueAndCencel(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    if (IsSet(workIndex) && workIndex > 0) {
        ; Worker：主进程按钮条（继续/取消），取消时执行终止逻辑
        result := WorkerInputRequest("IB", "3")
        if (IsObject(result) && result[1] == "cancel") {
            if (Data.CancelType == "终止当前宏")
                MyStopMacro(tableItem.Index, index)
            if (Data.CancelType == "终止所有宏")
                MyExcuteRMTCMDAction("RMT指令_宏控制_终止所有宏")
        }
    } else {
        ; 主程序：本地 XAML 按钮条（继续/取消），取消时执行终止逻辑，每请求独立实例
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
        BtnGuiCls := "InputBtnXamlGui"
        BtnGui := %BtnGuiCls%()
        BtnGui.CancelAction := InputBtnCancelAciton
        BtnGui.HideAction := InputBtnHideAciton
        BtnGui.ShowGui(3)
        while (!isHide && !BtnGui._closed) {
            Sleep(200)
        }
    }
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}
