#Requires AutoHotkey v2.0

class TaskQueue {
    __New() {
        this.queue := []
    }

    Push(task) {
        this.queue.Push(task)
    }

    Pop() {
        if (this.queue.Length == 0)
            return ""
        return this.queue.RemoveAt(1)
    }

    Size() {
        return this.queue.Length
    }
}

class Future {
    __New(id) {
        this.id := id
        this.done := false
        this.result := ""
    }

    SetResult(result) {
        this.result := result
        this.done := true
    }

    GetResult(timeout := 5000) {
        start := A_TickCount
        while (!this.done) {
            if (A_TickCount - start > timeout)
                throw Error("Future timeout")
            Sleep 10
        }
        return this.result
    }
}

class WorkPool {
    __New() {
        this.workerExe := A_ScriptDir "\Thread\Work1.exe"
        this.maxSize := MySoftData.MutiThreadNum
        this.isDynamic := (this.maxSize == -1)
        this.dynamicMaxLimit := 16
        this.corePoolSize := MySoftData.DynamicCorePoolSize
        this.elasticTimeout := MySoftData.ElasticTimeout * 1000
        this.dynamicMinSize := this.corePoolSize
        
        this.pool := []                 ; idle workerIndex
        this.active := Map()            ; workerIndex -> hwnd
        this.pending := Map()           ; workerIndex -> true
        
        this.queue := TaskQueue()
        this.futures := Map()
        this.futureCreateTime := Map()
        this.futureTimeout := 10000

        this.workerIdleTime := Map()
        this.workerIndex := 0
        this.mainPID := DllCall("GetCurrentProcessId")
        
        this.MessageArr := []   ;消息数组，避免消息重复处理
        this.MessageMap := Map()

        OnMessage(WM_LOAD_WORK, ObjBindMethod(this, "OnWorkerReady"))  ; replaces OnFinishLoad
        OnMessage(WM_RELEASE_WORK, ObjBindMethod(this, "OnRelease"))   ; replaces old OnRelease
        OnMessage(WM_STOP_MACRO, ObjBindMethod(this, "OnStopMacro"))   ;终止其他宏
        OnMessage(WM_TR_MACRO, ObjBindMethod(this, "OnTriggerMacro"))  ;触发宏
        OnMessage(WM_COPYDATA, ObjBindMethod(this, "OnGetCmd"))        ;接收到命令
        
        ; 新增的 callback
        OnMessage(WM_WORK_DONE, ObjBindMethod(this, "OnDone"))         ; 任務完成 callback

        SetTimer(ObjBindMethod(this, "Dispatch"), 10)
        SetTimer(ObjBindMethod(this, "CheckFutures"), 1000)
        
        if (this.isDynamic) {
            this.shrinkTimerFunc := ObjBindMethod(this, "IdleShrinkCheck")
            SetTimer(this.shrinkTimerFunc, 10000)
        }

        ; 預熱
        if (this.isDynamic) {
            loop this.dynamicMinSize {
                this.CreateWorker()
            }
        } else {
            loop this.maxSize {
                this.CreateWorker()
            }
        }
    }

    __Delete() {
        if (this.isDynamic && this.shrinkTimerFunc != "") {
            SetTimer(this.shrinkTimerFunc, 0)
            this.shrinkTimerFunc := ""
        }
        this.Clear()
    }

    ; =========================
    ; 核心：建立 Worker（不再 copy exe）
    ; =========================
    CreateWorker() {
        this.workerIndex++
        idx := this.workerIndex

        this.pending[idx] := true

        Run(Format('"{}" {} {} {}', this.workerExe, MySoftData.MyGui.Hwnd, idx, this.mainPID))
    }

    ; =========================
    ; 核心：提交任務（外部用）
    ; =========================
    Submit(cmd) {
        if (!this.HasProp("taskCounter"))
            this.taskCounter := 0
        this.taskCounter++
        id := this.taskCounter

        future := Future(id)

        this.futures.Set(id, future)
        this.futureCreateTime.Set(id, A_TickCount)
        this.queue.Push({ id: id, cmd: cmd })

        return future
    }

    ; =========================
    ; 核心：調度器
    ; =========================
    Dispatch() {
        while (this.queue.Size() > 0 && this.pool.Length > 0) {
            idx := this.pool.Pop()

            if (!this.IsAlive(idx)) {
                this.active.Delete(idx)
                if (this.workerIdleTime.Has(idx))
                    this.workerIdleTime.Delete(idx)
                this.CreateWorker()
                continue
            }

            task := this.queue.Pop()
            this.SendTask(idx, task)
            
            if (this.workerIdleTime.Has(idx))
                this.workerIdleTime.Delete(idx)
        }

        ; 動態擴展 (如果任務過多且還沒到達上限)
        if (this.isDynamic && this.queue.Size() > 0 && (this.active.Count + this.pending.Count) < this.dynamicMaxLimit) {
            this.CreateWorker()
        }
    }
    
    ; =========================
    ; 核心：檢查超時 Future
    ; =========================
    CheckFutures() {
        now := A_TickCount
        toDelete := []
        for id, createTime in this.futureCreateTime {
            if ((now - createTime) >= this.futureTimeout) {
                if (this.futures.Has(id)) {
                    this.futures[id].SetResult("timeout")
                    this.futures.Delete(id)
                }
                toDelete.Push(id)
            }
        }
        for id in toDelete {
            this.futureCreateTime.Delete(id)
        }
    }

    IsAlive(idx) {
        return this.active.Has(idx) && WinExist("ahk_id " this.active[idx])
    }

    ; =========================
    ; 核心：發送任務 (WM_COPYDATA)
    ; =========================
    SendTask(workerIndex, task) {
        hwnd := this.active[workerIndex]
        data := task.id "⫶" task.cmd

        CopyDataStruct := Buffer(3 * A_PtrSize)
        size := (StrLen(data) + 1) * 2
        NumPut("Ptr", size, "Ptr", StrPtr(data), CopyDataStruct, A_PtrSize)
        try {
            SendMessage(WM_COPYDATA, 0, CopyDataStruct, , "ahk_id " hwnd)
        }
    }

    ; =========================
    ; worker 完成 (透過 TaskQueue 送的)
    ; =========================
    OnDone(wParam, lParam, msg, hwnd) {
        id := wParam
        result := lParam

        if (this.futures.Has(id)) {
            this.futures[id].SetResult(result)
            this.futures.Delete(id)
            this.futureCreateTime.Delete(id)
        }

        ; Extract worker index from hwnd
        idx := this.GetWorkerIndexByHwnd(hwnd)
        if (idx > 0) {
            this.pool.Push(idx)
            this.workerIdleTime.Set(idx, A_TickCount)
        }
    }

    GetWorkerIndexByHwnd(targetHwnd) {
        for idx, hwnd in this.active {
            if (hwnd == targetHwnd)
                return idx
        }
        return 0
    }

    ; =========================
    ; worker 準備就緒 (取代舊版 OnFinishLoad)
    ; =========================
    OnWorkerReady(wParam, lParam, msg, hwnd) {
        idx := wParam
        workerHwnd := lParam > 0 ? lParam : hwnd
        
        if (this.pending.Has(idx))
            this.pending.Delete(idx)
            
        this.active.Set(idx, workerHwnd)
        this.pool.Push(idx)
        this.workerIdleTime.Set(idx, A_TickCount)
    }

    ; =========================
    ; Compatibility Layer (兼容舊系統)
    ; =========================
    GetWorkPath(workerIndex) {
        return "worker:" workerIndex
    }

    GetWorkIndex(fakePath) {
        if (IsInteger(fakePath))
            return fakePath
        return Integer(StrReplace(fakePath, "worker:"))
    }

    CheckHasFreeWorker() {
        if (this.isDynamic) {
            if (this.pool.Length >= 1)
                return true
            return (this.active.Count + this.pending.Count) < this.dynamicMaxLimit
        }
        return this.pool.Length >= 1
    }

    CheckEnableMutiThread() {
        if (this.isDynamic)
            return true
        return this.maxSize >= 1
    }

    GetActiveCount() {
        return this.active.Count - this.pool.Length
    }

    Get() {
        idx := 0
        while (this.pool.Length >= 1) {
            idx := this.pool.Pop()
            if (this.IsAlive(idx))
                break
            else {
                this.active.Delete(idx)
                if (this.workerIdleTime.Has(idx))
                    this.workerIdleTime.Delete(idx)
                idx := 0
            }
        }

        if (idx > 0) {
            if (this.workerIdleTime.Has(idx))
                this.workerIdleTime.Delete(idx)
            if (this.isDynamic && this.pool.Length == 0 && (this.active.Count + this.pending.Count) < this.dynamicMaxLimit)
                this.CreateWorker()
            return this.GetWorkPath(idx)
        } else if (this.isDynamic && (this.active.Count + this.pending.Count) < this.dynamicMaxLimit) {
            this.CreateWorker()
        }
        return ""
    }

    GetActiveWorkerList() {
        list := []
        for idx, hwnd in this.active {
            list.Push(this.GetWorkPath(idx))
        }
        return list
    }

    Clear() {
        for idx, hwnd in this.active {
            this.PostMessage(WM_CLEAR_WORK, idx, 0, 0)
        }
        this.pool := []
        this.active := Map()
        this.pending := Map()
        this.workerIdleTime := Map()
        this.futures := Map()
        this.futureCreateTime := Map()
        this.queue := TaskQueue()
        this.workerIndex := 0
    }

    PostMessage(type, identifier, wParam, lParam) {
        idx := this.GetWorkIndex(identifier)
        if (this.active.Has(idx)) {
            hwnd := this.active[idx]
            try {
                PostMessage(type, wParam, lParam, , "ahk_id " hwnd)
            }
        }
    }

    SendMessage(type, identifier, str) {
        idx := this.GetWorkIndex(identifier)
        if (!this.active.Has(idx))
            return
            
        hwnd := this.active[idx]
        CopyDataStruct := Buffer(3 * A_PtrSize)
        SizeInBytes := (StrLen(str) + 1) * 2
        NumPut("Ptr", SizeInBytes, "Ptr", StrPtr(str), CopyDataStruct, A_PtrSize)
        try {
            SendMessage(type, 0, CopyDataStruct, , "ahk_id " hwnd)
        }
    }

    IdleShrinkCheck() {
        if (this.pool.Length <= this.corePoolSize)
            return
        now := A_TickCount
        shrinkIndices := []
        
        for idx, idleTick in this.workerIdleTime {
            if ((now - idleTick) >= this.elasticTimeout) {
                shrinkIndices.Push(idx)
            }
        }
        maxShrink := this.pool.Length - this.corePoolSize
        if (shrinkIndices.Length == 0 || maxShrink <= 0)
            return
            
        loop Min(shrinkIndices.Length, maxShrink) {
            targetIndex := shrinkIndices[A_Index]
            this.PostMessage(WM_CLEAR_WORK, targetIndex, 0, 0)
            this.active.Delete(targetIndex)
            if (this.workerIdleTime.Has(targetIndex))
                this.workerIdleTime.Delete(targetIndex)
                
            poolIndex := 0
            loop this.pool.Length {
                if (this.pool[A_Index] == targetIndex) {
                    poolIndex := A_Index
                    break
                }
            }
            if (poolIndex > 0)
                this.pool.RemoveAt(poolIndex)
        }
    }

    ; =========================
    ; 舊有系統回調與去重邏輯
    ; =========================
    OnRelease(wParam, lParam, msg, hwnd) {
        tableIndex := wParam
        itemIndex := lParam
        tableItem := MySoftData.TableInfo[tableIndex]
        workerIndex := tableItem.IsWorkIndexArr[itemIndex]
        
        this.pool.Push(workerIndex)
        this.workerIdleTime.Set(workerIndex, A_TickCount)
        tableItem.IsWorkIndexArr[itemIndex] := false
    }

    OnStopMacro(wParam, lParam, msg, hwnd) {
        tableIndex := wParam
        itemIndex := lParam
        tableItem := MySoftData.TableInfo[tableIndex]
        WorkerIndex := tableItem.IsWorkIndexArr[itemIndex]
        if (WorkerIndex != 0) {
            this.PostMessage(WM_STOP_MACRO, WorkerIndex, tableIndex, itemIndex)
            return
        }
        KillTableItemMacro(tableItem, itemIndex)
    }

    OnTriggerMacro(wParam, lParam, msg, hwnd) {
        TriggerMacroHandler(wParam, lParam)
    }

    OnRecordMessage(Timestamp) {
        if (this.MessageMap.Has(Timestamp))
            return

        this.MessageMap.Set(Timestamp, 1)
        this.MessageArr.Push(Timestamp)
        if (this.MessageArr.Length >= 125) {
            delTimestamp := this.MessageArr.RemoveAt(1)
            this.MessageMap.Delete(delTimestamp)
        }
    }

    OnGetCmd(wParam, lParam, msg, hwnd) {
        StringAddress := NumGet(lParam, 2 * A_PtrSize, "Ptr")
        Cmd := StrGet(StringAddress)
        paramArr := StrSplit(Cmd, "⫶")

        workerList := this.GetActiveWorkerList()
        loop workerList.Length {
            this.PostMessage(WM_RECEIVE_INFO, workerList[A_Index], wParam, 0)
        }

        if (this.MessageMap.Has(wParam))
            return

        this.OnRecordMessage(wParam)

        switch paramArr[1] {
            case "SetVari":
                GetNameAndValueByParamArr(&NameArr, &ValueArr, paramArr)
                SetGlobalVariable(NameArr, ValueArr, false)
            case "DelVari":
                NameArr := paramArr.Clone()
                NameArr.RemoveAt(1)
                DelGlobalVariable(NameArr)
            case "Report":
                CMDReport(SubStr(Cmd, 8))
            case "RMT指令":
                ExcuteRMTCMDAction(Cmd)
            case "ItemState":
                SetTableItemState(paramArr[2], Integer(paramArr[3]), Integer(paramArr[4]))
            case "PauseState":
                SetItemPauseState(paramArr[2], Integer(paramArr[3]), Integer(paramArr[4]))
            case "MsgBox":
                paramArr := StrSplit(Cmd, "⫶", , 2)
                MsgBoxContent(paramArr[2])
            case "ToolTip":
                ToolTipContent(paramArr[2])
            case "MacroCount":
                MacroCount(paramArr[2])
            case "Joy":
                ViGJoySetState(paramArr[2], paramArr[3], paramArr[4])
            case "SetArray":
                SetGlobalArray(paramArr[2], GetArray(paramArr[3]))
            case "CloneArray":
                CloneGlobalArray(GetArray(paramArr[2]), paramArr[3])
            case "DeleteArray":
                DeleteGlobalArray(paramArr[2])
            case "ModifyArray":
                ModifyGlobalArray(paramArr[2], paramArr[3], paramArr[4], paramArr[5], paramArr[6])
            case "InsertArray":
                InsertGlobalArray(paramArr[2], paramArr[3], paramArr[4], paramArr[5], paramArr[6])
            case "RemoveAtArray":
                RemoveAtGlobalArray(paramArr[2], paramArr[3], paramArr[4])
        }
    }
}
