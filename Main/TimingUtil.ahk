#Requires AutoHotkey v2.0

global MyTimingScheduler := ""

TimingCheck() {
    if ((tableIndex := GetTimingTableIndex()) == "")
        return

    tableItem := MySoftData.TableInfo[tableIndex]
    HandleOnSoftStart(tableItem)
    
    global MyTimingScheduler
    if (IsObject(MyTimingScheduler))
        MyTimingScheduler.Stop()
    
    MyTimingScheduler := TimingScheduler(tableIndex)
    MyTimingScheduler.Start()
}

class TimingScheduler {

    __New(tableIndex) {
        this.tableIndex := tableIndex
        this.heap := MinHeap()
        this.timerFunc := ObjBindMethod(this, "OnTimer")
        this.running := false
    }

    Start() {
        this.running := true
        this.Rebuild()
    }

    Stop() {
        this.running := false
        SetTimer(this.timerFunc, 0)
        this.heap.Clear()
    }

    Rebuild() {
        if (!this.running)
            return

        SetTimer(this.timerFunc, 0)
        this.heap.Clear()

        tableItem := MySoftData.TableInfo[this.tableIndex]

        SetTimingNextTime(tableItem)

        for index, _ in tableItem.ModeArr {

            if (!TimingCheckItemIfValid(tableItem, index))
                continue

            Data := GetMacroCMDData(tableItem.TimingSerialArr[index])
            if (Data == "" || Data.NextTriggerTime == "")
                continue

            this.heap.Push({
                time: Data.NextTriggerTime,
                index: index
            })
        }

        this.ScheduleNext()
    }

    ScheduleNext() {
        if (!this.running || this.heap.IsEmpty())
            return

        next := this.heap.Peek()
        CurTime := FormatTime(A_Now, "yyyyMMddHHmmss")

        delay := DateDiff(next.time, CurTime, "Seconds") * 1000
        if (delay < 1)
            delay := 1

        SetTimer(this.timerFunc, -delay)
    }

    OnTimer() {
        if (!this.running)
            return

        tableItem := MySoftData.TableInfo[this.tableIndex]
        CurTime := FormatTime(A_Now, "yyyyMMddHHmmss")

        while (!this.heap.IsEmpty() && this.heap.Peek().time <= CurTime) {

            item := this.heap.Pop()
            index := item.index

            Data := GetMacroCMDData(tableItem.TimingSerialArr[index])
            if (Data == "" || Data.NextTriggerTime == "")
                continue

            shouldTrigger := true

            if ((frontInfo := GetItemFrontInfo(tableItem, index)) != "") {
                if (!MyMouseInfo.CheckIfMatch(frontInfo, true))
                    shouldTrigger := false
            }

            Data.NextTriggerTime := CalculateNextTriggerTime(Data, Data.NextTriggerTime)

            if (Data.EndTime != "" && Data.NextTriggerTime >= Data.EndTime)
                Data.NextTriggerTime := ""

            if (shouldTrigger)
                TriggerMacroHandler(this.tableIndex, index)

            if (Data.NextTriggerTime != "")
                this.heap.Push({
                    time: Data.NextTriggerTime,
                    index: index
                })
        }

        this.ScheduleNext()
    }
}

class MinHeap {

    __New() {
        this.heap := []
    }

    Push(item) {
        this.heap.Push(item)
        this._Up(this.heap.Length)
    }

    Pop() {
        if (this.heap.Length = 0)
            return ""

        if (this.heap.Length = 1)
            return this.heap.Pop()

        top := this.heap[1]
        this.heap[1] := this.heap.Pop()
        this._Down(1)
        return top
    }

    Peek() {
        return this.heap.Length ? this.heap[1] : ""
    }

    IsEmpty() {
        return this.heap.Length = 0
    }

    Clear() {
        this.heap := []
    }

    _Up(i) {
        while (i > 1) {
            p := i // 2
            if (this.heap[i].time < this.heap[p].time)
                this._Swap(i, p), i := p
            else
                break
        }
    }

    _Down(i) {
        len := this.heap.Length
        while (i * 2 <= len) {
            c := i * 2
            if (c + 1 <= len && this.heap[c + 1].time < this.heap[c].time)
                c++

            if (this.heap[c].time < this.heap[i].time)
                this._Swap(i, c), i := c
            else
                break
        }
    }

    _Swap(a, b) {
        tmp := this.heap[a]
        this.heap[a] := this.heap[b]
        this.heap[b] := tmp
    }
}

SetTimingNextTime(tableItem) {
    CurTime := FormatTime(A_Now, "yyyyMMddHHmmss")

    for index, _ in tableItem.ModeArr {

        if (!TimingCheckItemIfValid(tableItem, index))
            continue

        Data := GetMacroCMDData(tableItem.TimingSerialArr[index])
        if (Data == "" || ObjOwnPropCount(Data) == 0)
            continue

        if (Data.EndTime != "" && CurTime >= Data.EndTime) {
            Data.NextTriggerTime := ""
            continue
        }

        Data.NextTriggerTime := CalculateNextTriggerTime(Data, CurTime)
    }
}

CalculateNextTriggerTime(Data, BaseTime := "") {

    if (BaseTime == "")
        BaseTime := FormatTime(A_Now, "yyyyMMddHHmmss")

    span := DateDiff(BaseTime, Data.StartTime, "Minutes")

    if (Data.Type = 1)
        return span < 0 ? Data.StartTime : ""

    if (Data.Type = 2 || Data.Type = 3 || Data.Type = 4 || Data.Type = 7) {

        interval := GetTimingInterval(Data)

        if (span < 0)
            return Data.StartTime

        count := Floor(span / interval)

        return FormatTime(DateAdd(Data.StartTime, (count + 1) * interval, "Minutes"), "yyyyMMddHHmmss")
    }

    if (Data.Type = 5) {

        if (span < 0)
            return Data.StartTime

        target := SubStr(BaseTime, 1, 6) SubStr(Data.StartTime, 7)

        if (BaseTime < target)
            return target

        year := SubStr(BaseTime, 1, 4)
        month := SubStr(BaseTime, 5, 2)

        newMonth := month + 1
        newYear := year

        if (newMonth > 12)
            newMonth := 1, newYear++

        return Format("{:04}{:02}", newYear, newMonth)
            . SubStr(Data.StartTime, 7)
    }

    return ""
}

GetTimingInterval(Data) {
    static IntervalMap := Map(2, 60, 3, 1440, 4, 10080)
    return IntervalMap.Has(Data.Type) ? IntervalMap[Data.Type] : (Data.HasOwnProp("CustomInterval") ? Data.CustomInterval : 60)
}

TimingCheckItemIfValid(tableItem, index) {
    return !GetItemFoldForbidState(tableItem, index)
        && !tableItem.ForbidArr[index]
        && tableItem.MacroArr.Length >= index
        && tableItem.MacroArr[index] != ""
}

HandleOnSoftStart(tableItem) {
    if (MySoftData.IsReload)
        return

    for index, _ in tableItem.ModeArr {
        if (!TimingCheckItemIfValid(tableItem, index))
            continue

        Data := GetMacroCMDData(tableItem.TimingSerialArr[index])
        if (Data != "" && Data.Type == 6)
            TriggerMacroHandler(tableItem.Index, index)
    }
}