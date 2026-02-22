#Requires AutoHotkey v2.0

TimingCheck() {
    if ((tableIndex := GetTimingTableIndex()) == "")
        return

    tableItem := MySoftData.TableInfo[tableIndex]
    SetTimingNextTime(tableItem)
    HandleOnSoftStart(tableItem)

    if (A_Sec == 0)
        InitTimingChecker()
    else
        SetTimer(InitTimingChecker, (-(60 - A_Sec)) * 1000)
}

SetTimingNextTime(tableItem) {
    CurTime := FormatTime(A_Now, "yyyyMMddHHmm")
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
        BaseTime := FormatTime(A_Now, "yyyyMMddHHmm")

    span := DateDiff(BaseTime, Data.StartTime, "Minutes")

    if (Data.Type == 1) ; Once
        return span < 0 ? Data.StartTime : ""

    if (Data.Type == 2 || Data.Type == 3 || Data.Type == 4 || Data.Type == 7) {
        interval := GetTimingInterval(Data)
        if (span < 0)
            return Data.StartTime
        
        count := (Integer)(span / interval)
        return FormatTime(DateAdd(Data.StartTime, (count + 1) * interval, "Minutes"), "yyyyMMddHHmm")
    }

    if (Data.Type == 5) { ; Monthly
        if (span < 0)
            return Data.StartTime

        ; Target time this month
        target := SubStr(BaseTime, 1, 6) SubStr(Data.StartTime, 7)
        if (BaseTime < target)
            return target

        ; Goal: Move to the same day/time in the next month
        year := SubStr(BaseTime, 1, 4)
        month := SubStr(BaseTime, 5, 2)
        
        newMonth := month + 1
        newYear := year
        if (newMonth > 12) {
            newMonth := 1
            newYear += 1
        }
        return Format("{:04}{:02}", newYear, newMonth) SubStr(Data.StartTime, 7)
    }
    return ""
}

InitTimingChecker() {
    TimingChecker()
    SetTimer(TimingChecker, 60000)
}

TimingChecker() {
    if ((tableIndex := GetTimingTableIndex()) == "")
        return

    tableItem := MySoftData.TableInfo[tableIndex]
    CurTime := FormatTime(A_Now, "yyyyMMddHHmm")

    for index, _ in tableItem.ModeArr {
        if (!TimingCheckItemIfValid(tableItem, index))
            continue

        Data := GetMacroCMDData(tableItem.TimingSerialArr[index])
        if (Data == "" || ObjOwnPropCount(Data) == 0 || Data.NextTriggerTime == "" || CurTime < Data.NextTriggerTime)
            continue

        if ((frontInfo := GetItemFrontInfo(tableItem, index)) != "") {
            if (!MyMouseInfo.CheckIfMatch(frontInfo, true))
                continue
        }

        Data.NextTriggerTime := CalculateNextTriggerTime(Data, Data.NextTriggerTime)
        if (Data.EndTime != "" && Data.NextTriggerTime >= Data.EndTime)
            Data.NextTriggerTime := ""

        TriggerMacroHandler(tableIndex, index)
    }
}

GetTimingInterval(Data) {
    static IntervalMap := Map(2, 60, 3, 1440, 4, 10080)
    return IntervalMap.Has(Data.Type) ? IntervalMap[Data.Type] : (Data.HasOwnProp("CustomInterval") ? Data.CustomInterval : 60)
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

TimingCheckItemIfValid(tableItem, index) {
    return !GetItemFoldForbidState(tableItem, index) 
        && !tableItem.ForbidArr[index] 
        && tableItem.MacroArr.Length >= index 
        && tableItem.MacroArr[index] != ""
}