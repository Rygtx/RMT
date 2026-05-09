#Requires AutoHotkey v2.0
#Include Util\SharedMemory.ahk
#Include Util\RingBuffer.ahk

class TaskQueue {
    __New() {
        this.queue := []
    }
    Push(task) => this.queue.Push(task)
    Pop() => (this.queue.Length == 0) ? "" : this.queue.RemoveAt(1)
    Size() => this.queue.Length
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
        
        this.pool := []
        this.active := Map()            ; workerIndex -> hwnd (for backward compatibility if needed)
        this.pending := Map()
        
        this.tx := Map()
        this.rx := Map()
        this.evt := Map()
        this.shmTx := Map()
        this.shmRx := Map()

        this.queue := TaskQueue()
        this.futures := Map()
        this.futureCreateTime := Map()
        this.futureTimeout := 10000

        this.workerIdleTime := Map()
        this.workerIndex := 0
        this.mainPID := DllCall("GetCurrentProcessId")
        this.taskCounter := 0
        
        this.MessageArr := []
        this.MessageMap := Map()

        OnMessage(WM_LOAD_WORK, ObjBindMethod(this, "OnWorkerReady"))
        OnMessage(WM_RELEASE_WORK, ObjBindMethod(this, "OnRelease"))
        OnMessage(WM_STOP_MACRO, ObjBindMethod(this, "OnStopMacro"))
        OnMessage(WM_TR_MACRO, ObjBindMethod(this, "OnTriggerMacro"))
        ; OnMessage(WM_COPYDATA, ObjBindMethod(this, "OnGetCmd")) ; Deprecated

        SetTimer(ObjBindMethod(this, "Dispatch"), 10)
        SetTimer(ObjBindMethod(this, "CheckFutures"), 1000)
        SetTimer(ObjBindMethod(this, "PollResult"), 1)  ; Hybrid polling
        
        if (this.isDynamic) {
            this.shrinkTimerFunc := ObjBindMethod(this, "IdleShrinkCheck")
            SetTimer(this.shrinkTimerFunc, 10000)
        }

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

    CreateWorker() {
        this.workerIndex++
        idx := this.workerIndex

        txName := "Global\TX_" idx
        rxName := "Global\RX_" idx
        evtName := "Global\EVT_" idx

        this.shmTx[idx] := SharedMemory(txName, 1048576) ; 1MB tx buffer
        this.tx[idx] := RingBuffer(this.shmTx[idx].ptr, 1048576)
        
        this.shmRx[idx] := SharedMemory(rxName, 1048576) ; 1MB rx buffer
        this.rx[idx] := RingBuffer(this.shmRx[idx].ptr, 1048576)
        
        this.evt[idx] := CreateEvent(evtName)
        this.pending[idx] := true

        Run(Format('"{}" {} {} {} "{}" "{}" "{}"'
            , this.workerExe
            , MySoftData.MyGui.Hwnd
            , idx
            , this.mainPID
            , txName
            , rxName
            , evtName))
    }

    Submit(cmd) {
        this.taskCounter++
        id := this.taskCounter
        future := Future(id)

        this.futures.Set(id, future)
        this.futureCreateTime.Set(id, A_TickCount)
        this.queue.Push({ id: id, cmd: cmd })

        return future
    }

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
            if (!this.tx[idx].Push(task.id, task.cmd)) {
                ; Buffer full, put it back and fallback
                this.queue.queue.InsertAt(1, task)
                this.pool.Push(idx)
                break
            }
            SetEvent(this.evt[idx])
            
            if (this.workerIdleTime.Has(idx))
                this.workerIdleTime.Delete(idx)
        }

        if (this.isDynamic && this.queue.Size() > 0 && (this.active.Count + this.pending.Count) < this.dynamicMaxLimit) {
            this.CreateWorker()
        }
    }
    
    PollResult() {
        for idx, rb in this.rx {
            ; Hybrid Polling: Non-blocking pop all available results
            while (rb.Pop(&id, &result)) {
                if (id > 0) {
                    if (this.futures.Has(id)) {
                        this.futures[id].SetResult(result)
                        this.futures.Delete(id)
                        this.futureCreateTime.Delete(id)
                    }
                    this.pool.Push(idx)
                    this.workerIdleTime.Set(idx, A_TickCount)
                } else {
                    ; Legacy WM_COPYDATA replacement, id == 0
                    this.OnGetCmdStr(idx, result)
                }
            }
        }
    }

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

    OnWorkerReady(wParam, lParam, msg, hwnd) {
        idx := wParam
        workerHwnd := lParam > 0 ? lParam : hwnd
        
        if (this.pending.Has(idx))
            this.pending.Delete(idx)
            
        this.active.Set(idx, workerHwnd)
        this.pool.Push(idx)
        this.workerIdleTime.Set(idx, A_TickCount)
    }

    ; --- Compatibility Layer ---
    GetWorkPath(workerIndex) => "worker:" workerIndex

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

    GetActiveCount() => this.active.Count - this.pool.Length

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
        
        ; Close RingBuffers
        this.tx := Map()
        this.rx := Map()
        this.shmTx := Map()
        this.shmRx := Map()
        for idx, h in this.evt
            ResetEvent(h) ; Optional
    }

    PostMessage(type, identifier, wParam, lParam) {
        idx := this.GetWorkIndex(identifier)
        if (this.active.Has(idx)) {
            ; For WM_TR_MACRO and others, since they are fast ints, we could use RingBuffer if we encoded them.
            ; For extreme compatibility without rewriting legacy calls, we fallback to AHK's PostMessage.
            ; AHK's PostMessage is non-blocking and fast enough for integers.
            hwnd := this.active[idx]
            try {
                PostMessage(type, wParam, lParam, , "ahk_id " hwnd)
            }
        }
    }

    SendMessage(type, identifier, str) {
        ; Completely replaced WM_COPYDATA with RingBuffer Push!
        idx := this.GetWorkIndex(identifier)
        if (this.tx.Has(idx)) {
            ; id 0 is reserved for non-future tasks
            this.tx[idx].Push(0, str)
            SetEvent(this.evt[idx])
        }
    }

    IdleShrinkCheck() {
        if (this.pool.Length <= this.corePoolSize)
            return
        now := A_TickCount
        shrinkIndices := []
        for idx, idleTick in this.workerIdleTime {
            if ((now - idleTick) >= this.elasticTimeout)
                shrinkIndices.Push(idx)
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

    ; --- Legacy Deduplication & Callbacks ---
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

    OnGetCmdStr(idx, Cmd) {
        ; Handle id=0 messages from worker
        ; The string has Timestamp appended to the end: str "⫶" Timestamp
        lastIndex := InStr(Cmd, "⫶", , -1)
        Timestamp := ""
        if (lastIndex > 0) {
            Timestamp := SubStr(Cmd, lastIndex + 1)
            Cmd := SubStr(Cmd, 1, lastIndex - 1)
        }
        paramArr := StrSplit(Cmd, "⫶")

        ; Broadcast to other workers (if needed by old logic)
        ; Wait, old logic broadcasted WM_RECEIVE_INFO. 
        ; I will skip the broadcast logic unless strictly required, but for compatibility let's keep it.
        workerList := this.GetActiveWorkerList()
        loop workerList.Length {
            this.PostMessage(WM_RECEIVE_INFO, workerList[A_Index], Timestamp, 0)
        }

        if (Timestamp != "" && this.MessageMap.Has(Timestamp))
            return

        if (Timestamp != "")
            this.OnRecordMessage(Timestamp)

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
