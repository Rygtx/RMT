; 图形宏（MacroGraphStartNode / MacroGraphNode）遍历与多分支并行调度
; 主进程在 RMTUtil.ahk 中赋值为 WorkPool()；Worker 进程不使用本地 WorkPool
global MyWorkPool := ""
global workIndex := 0    ; 主进程占位；Worker 中由 HandleWorkOpenArg 赋实际 idx

GraphMacroExecLog(tag, tableItem, index, cmdStr := "", nodeSerial := "", extra := "") {
    global workIndex
    who := MySoftData.isWorker ? Format("W{1}", workIndex) : "Master"
    cmdShort := cmdStr != "" ? GetCmdStr(cmdStr) : ""
    detail := Format("执行者={1} tab={2} item={3}", who, tableItem.Index, index)
    if (nodeSerial != "")
        detail .= Format(" node={1}", nodeSerial)
    if (cmdShort != "")
        detail .= Format(" cmd={1}", cmdShort)
    if (extra != "")
        detail .= " " extra
    GraphPoolLog(tag, detail)
}

GraphPoolLogPath() {
    return MySoftData.isWorker ? A_ScriptDir "\..\Log\GraphPool.log" : A_ScriptDir "\Log\GraphPool.log"
}

; 图形宏线程池调试日志（Master 行附带 Worker 池统计：闲置/忙碌/启动中/队列）
GraphPoolLog(tag, detail := "") {
    global MyWorkPool, workIndex
    if (MySoftData.isWorker)
        head := Format("[{}] [W{}] {}", A_Now, workIndex, tag)
    else {
        stats := (MyWorkPool != "" && IsObject(MyWorkPool)) ? MyWorkPool.GetPoolStatsStr() : "pool=未初始化"
        head := Format("[{}] [Master] {} ({})", A_Now, tag, stats)
    }
    line := detail != "" ? head " " detail "`n" : head "`n"
    try {
        logDir := MySoftData.isWorker ? A_ScriptDir "\..\Log" : A_ScriptDir "\Log"
        if !DirExist(logDir)
            DirCreate(logDir)
        FileAppend(line, GraphPoolLogPath(), "UTF-8")
    }
}

IsGraphStartSerial(serialStr) {
    if (serialStr == "")
        return false
    SplitSerialTextAndNumbers(serialStr, &t, &n)
    return t == GetLangKey("图形开始节点") && n != ""
}

IsGraphNodeSerial(serialStr) {
    if (serialStr == "")
        return false
    SplitSerialTextAndNumbers(serialStr, &t, &n)
    return t == GetLangKey("图形节点") && n != ""
}

ShouldUseGraphWorkers() {
    global MyWorkPool
    if (MySoftData.isWorker)
        return true
    return MyWorkPool != "" && (MyWorkPool.isDynamic || MyWorkPool.maxSize >= 1)
}

; Worker 多分支图形宏：分支1在本 Worker 执行，其余分支由 Master 分配；结束状态由 FinishGraphMacroItem 统一处理
ShouldSkipWorkerFinishMacro(tableItem, macro, index) {
    if (!MySoftData.isWorker || !ShouldUseGraphWorkers() || !IsGraphStartSerial(macro))
        return false
    startData := GetMacroCMDData(macro)
    if (!IsObject(startData))
        return false
    nodeArr := (startData.HasOwnProp("NodeArr") && IsObject(startData.NodeArr)) ? startData.NodeArr : []
    return CollectGraphBranchSerials(nodeArr).Length > 1
}

IncGraphBranchCount(tableItem, index) {
    if (tableItem.GraphBranchCountArr.Length < index)
        return
    tableItem.GraphBranchCountArr[index]++
}

ShouldSkipGraphNextDispatch(cmdStr) {
    if (cmdStr == "")
        return false
    paramArr := StrSplit(GetCmdStr(cmdStr), "_")
    cmdKey := RTrim(paramArr[1], "0123456789")
    skipTypes := [GetLang("如果"), GetLang("如果Pro"), GetLang("搜索"), GetLang("搜索Pro"), GetLang("循环")]
    for t in skipTypes {
        if (cmdKey == t)
            return true
    }
    return false
}

CollectGraphBranchSerials(serialArr) {
    out := []
    if (!IsObject(serialArr))
        return out
    for s in serialArr {
        if (s != "" && IsGraphNodeSerial(s))
            out.Push(s)
    }
    return out
}

; Worker 内同步通知 Master 分配分支（避免 PostMessage 竞态导致 FINISH 先于 Submit）
RequestGraphBranchWorker(tableItem, index, nodeSerial, skipInc := false) {
    if (MySoftData.isWorker) {
        global MyRequestGraphBranch
        MyRequestGraphBranch(tableItem.Index, index, nodeSerial, skipInc)
        return
    }
    global MyWorkPool
    if (!ShouldUseGraphWorkers()) {
        WalkGraphNode(tableItem, nodeSerial, index)
        return
    }
    if (!skipInc)
        IncGraphBranchCount(tableItem, index)
    cmd := JSON.stringify(["TR_GRAPH", tableItem.Index, index, nodeSerial])
    GraphPoolLog("分支分配", Format("tab={1} item={2} node={3} 来源=Master/DispatchGraphBranches", tableItem.Index, index, nodeSerial))
    MyWorkPool.SubmitGraphBranch(cmd, tableItem.Index, index)
}

; 多后继：Worker 批量提交第 2..N 条 TR_GRAPH，本 Worker 执行第 1 条
; fromStart=true：设置 GraphBranchCount 并标记发起 Worker；否则只递增子分支数
DispatchGraphBranches(tableItem, index, serialArr, fromStart := false) {
    branches := CollectGraphBranchSerials(serialArr)
    if (branches.Length == 0)
        return
    if (branches.Length == 1) {
        WalkGraphNode(tableItem, branches[1], index)
        return
    }
    if (!ShouldUseGraphWorkers()) {
        for b in branches
            WalkGraphNode(tableItem, b, index)
        return
    }
    if (MySoftData.isWorker) {
        GraphPoolLog("Worker图形分支", Format("tab={1} item={2} 分支数={3} 本Worker=[{4}] fromStart={5}"
            , tableItem.Index, index, branches.Length, branches[1], fromStart ? 1 : 0))
        subsidiary := []
        loop branches.Length - 1
            subsidiary.Push(branches[A_Index + 1])
        global MySubmitGraphBranches
        MySubmitGraphBranches(tableItem.Index, index, fromStart ? branches.Length : 0, subsidiary)
        WalkGraphNode(tableItem, branches[1], index)
        return
    }
    loop branches.Length - 1
        RequestGraphBranchWorker(tableItem, index, branches[A_Index + 1])
    WalkGraphNode(tableItem, branches[1], index)
}

WalkGraphNode(tableItem, nodeSerial, index) {
    GraphMacroExecLog("进入节点", tableItem, index, "", nodeSerial)
    if (tableItem.KilledArr[index]) {
        GraphMacroExecLog("跳过节点", tableItem, index, "", nodeSerial, "原因=已终止")
        return
    }
    if (!IsGraphNodeSerial(nodeSerial)) {
        GraphMacroExecLog("跳过节点", tableItem, index, "", nodeSerial, "原因=非图形节点")
        return
    }
    nodeData := GetMacroCMDData(nodeSerial)
    if (!IsObject(nodeData)) {
        GraphMacroExecLog("跳过节点", tableItem, index, "", nodeSerial, "原因=无节点数据")
        return
    }

    curCmd := nodeData.HasOwnProp("CurCMD") ? nodeData.CurCMD : ""
    if (curCmd != "") {
        GraphMacroExecLog("节点指令", tableItem, index, curCmd, nodeSerial)
        ExecuteMacroCmdOnce(tableItem, curCmd, index, nodeSerial)
        if (tableItem.KilledArr[index])
            return
        if (tableItem.VariableMapArr[index]["分支-跳出"]) {
            tableItem.VariableMapArr[index]["分支-跳出"] := false
            return
        }
        if (tableItem.VariableMapArr[index]["循环-跳出"])
            return
    }

    if (ShouldSkipGraphNextDispatch(curCmd))
        return
    nexts := (nodeData.HasOwnProp("NextNodeArr") && IsObject(nodeData.NextNodeArr)) ? nodeData.NextNodeArr : []
    DispatchGraphBranches(tableItem, index, nexts, false)
}

OnTriggerGraphMacro(tableItem, startSerial, index) {
    startData := GetMacroCMDData(startSerial)
    if (!IsObject(startData))
        return
    nodeArr := (startData.HasOwnProp("NodeArr") && IsObject(startData.NodeArr)) ? startData.NodeArr : []
    DispatchGraphBranches(tableItem, index, nodeArr, true)
}

; 主进程占位；Worker 中由 WrokGlobalUtil 覆盖为 WorkSubmitGraphBranches
SubmitGraphBranchesHandler(tableIndex, itemIndex, branchCount, nodeSerialArr, *) {
}

; 主进程占位（实际由 WorkPool.SubmitGraphBranch 处理）；Worker 中由 WrokGlobalUtil 覆盖为 WorkRequestGraphBranch
RequestGraphBranchHandler(tableIndex, itemIndex, nodeSerial, *) {
}
