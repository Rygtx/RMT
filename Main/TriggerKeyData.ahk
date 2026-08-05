#Requires AutoHotkey v2.0

class TriggerKeyData {
    __New(Key) {
        this.Key := Key
        this.OriDownArr := []  ;按下触发
        this.OriLoosenArr := []    ;松开触发
        this.OriLoosenStopArr := []    ;松止
        this.OriTogArr := []   ;开关
        this.OriHoldArr := []  ;按长按
        this.OriDblClickArr := []  ;双击触发
        this.HoldActionMap := Map()

        this.DownArr := []
        this.LoosenArr := []
        this.LoosenStopArr := []
        this.TogArr := []
        this.HoldArr := []
        this.DblClickArr := []

        this.LastKeyDownTime := 0  ;上次按下时间（用于双击检测）
        this.DblClickInterval := 300  ;双击间隔时间（毫秒）

        ; 缓存相关字段（性能优化）
        this.cacheTime := 0          ;上次更新缓存的时间戳
        this.cacheValidDuration := 200  ;缓存有效期（毫秒），窗口切换通常不会频繁发生

        this.InitState()
    }

    InitState() {
    }

    AddData(info) {
        static PropNames := ["OriDownArr", "OriLoosenArr", "OriLoosenStopArr", "OriTogArr", "OriHoldArr", "OriDblClickArr"]
        this.%PropNames[info.GetTriggerType()]%.Push(info)
    }

    UpdataArr(forceUpdate := false) {
        now := A_TickCount

        ; 缓存检查：如果缓存有效且不是强制更新，跳过重建
        if (!forceUpdate && (now - this.cacheTime) < this.cacheValidDuration)
            return

        this.DownArr := []
        this.LoosenArr := []
        this.LoosenStopArr := []
        this.TogArr := []
        this.HoldArr := []
        this.DblClickArr := []

        MyMouseInfo.UpdateInfo()
        this.UpdateArrByFront(this.OriDownArr, this.DownArr)
        this.UpdateArrByFront(this.OriLoosenArr, this.LoosenArr)
        this.UpdateArrByFront(this.OriLoosenStopArr, this.LoosenStopArr)
        this.UpdateArrByFront(this.OriTogArr, this.TogArr)
        this.UpdateArrByFront(this.OriHoldArr, this.HoldArr)
        this.UpdateArrByFront(this.OriDblClickArr, this.DblClickArr)

        ;更新双击间隔时间为所有双击宏中的最小值
        if (this.DblClickArr.Length > 0) {
            minInterval := 300
            for index, value in this.DblClickArr {
                interval := value.GetDblClickInterval()
                if (interval < minInterval)
                    minInterval := interval
            }
            this.DblClickInterval := minInterval
        }

        ; 更新缓存时间戳
        this.cacheTime := now
    }

    UpdateArrByFront(OriArr, ResArr) {
        tableItem := MySoftData.TableInfo[1]
        for index, value in OriArr {
            infoStr := value.GetFrontStr()
            realInfoStr := GetParamsWinInfoStr(infoStr)
            if (realInfoStr == "")
                continue

            if (MyMouseInfo.CheckIfMatch(infoStr, false))
                ResArr.Push(value)
        }

        ; 如果没有找到任何符合条件的窗口
        if (ResArr.Length == 0) {
            for index, value in OriArr {
                infoStr := value.GetFrontStr()
                realInfoStr := GetParamsWinInfoStr(infoStr)
                if (realInfoStr == "")
                    ResArr.Push(value)
            }
        }
    }

    OnTriggerKeyDown() {
        this.UpdataArr()

        ;双击检测逻辑
        currentTime := A_TickCount
        isDblClick := (currentTime - this.LastKeyDownTime) <= this.DblClickInterval && this.LastKeyDownTime != 0
        this.LastKeyDownTime := currentTime

        for index, value in this.DownArr {
            if (index == 1 && SubStr(value.GetTK(), 1, 1) != "~")
                LoosenModifyKey(value.GetTK())

            value.Action()
        }

        for index, value in this.LoosenStopArr {
            value.Action()
        }

        for index, value in this.TogArr {
            value.Action()
        }

        ;如果检测到双击，则触发双击宏
        if (isDblClick) {
            for index, value in this.DblClickArr {
                value.Action()
            }
        }

        this.SetHoldTimeChecker()
    }

    OnTriggerKeyUp() {
        this.UpdataArr()

        for index, value in this.LoosenArr {
            value.Action()
        }

        for index, value in this.LoosenStopArr {
            value.CancelAction()
        }

        this.DelHoldTimeChecker()
    }

    ; 强制刷新缓存（在配置重载、窗口切换等关键事件时调用）
    ForceRefreshCache() {
        this.cacheTime := 0  ; 使缓存失效
    }

    SetHoldTimeChecker() {
        for _, value in this.HoldArr {
            isWork := value.GetWorkState()
            if (isWork)
                continue
            if (this.HoldActionMap.Has(value))
                continue
            holdTime := value.GetHoldTime()
            action := this.HoldTimeAction.Bind(this, value)
            SetTimer(action, -holdTime)
            this.HoldActionMap.Set(value, action)
        }
    }

    DelHoldTimeChecker() {
        for key, value in this.HoldActionMap {
            SetTimer(value, 0)
        }
        this.HoldActionMap := Map()
    }

    HoldTimeAction(info) {
        keyCombo := LTrim(info.GetTK(), "~")
        if (this.HoldActionMap.Has(info))
            this.HoldActionMap.Delete(info)

        ; 手柄键长按检测：将友好名（如 JoyBack）转为 AHK 原始键名（如 Joy7）
        if (RegExMatch(keyCombo, "Joy") && MySoftData && IsObject(MySoftData)) {
            joyMap := MySoftData.GetJoyToAhkMap()
            if (joyMap.Has(keyCombo))
                keyCombo := joyMap[keyCombo]
        }

        if (AreKeysPressed(keyCombo))
            info.Action()
    }
}

class TriggerKeyInfo {
    __New() {
        this.macroType := 1     ; 1:按键/字串等 item  2:菜单宏 fold  3:界面宏 fold
        this.tableIndex := 1    ;table索引
        this.itemIndex := 1     ;item索引
        this.foldIndex := 1     ;折叠框索引

        this.forbidTrigger := false
    }

    ; 菜单宏 / 界面宏均为 Fold 级触发键
    IsFoldMacro() {
        return this.macroType == 2 || this.macroType == 3
    }

    GetFrontStr() {
        tableItem := MySoftData.TableInfo[this.tableIndex]
        if (this.macroType == 1)
            return GetItemFrontInfo(tableItem, this.itemIndex)
        if (this.IsFoldMacro())
            return tableItem.FoldInfo.FrontInfoArr[this.foldIndex]
        return ""
    }

    GetTK() {
        tableItem := MySoftData.TableInfo[this.tableIndex]
        if (this.macroType == 1)
            return tableItem.TKArr[this.itemIndex]
        if (this.IsFoldMacro())
            return tableItem.FoldInfo.TKArr[this.foldIndex]
        return ""
    }

    GetTriggerType() {      ;触发类型   "按下", "松开", "松止", "开关", "长按"
        tableItem := MySoftData.TableInfo[this.tableIndex]
        if (this.macroType == 1)
            return tableItem.TriggerTypeArr[this.itemIndex]
        if (this.macroType == 2)
            return tableItem.FoldInfo.TKTypeArr[this.foldIndex]
        ; 界面宏固定按「按下」切换面板（与 BindUIPanelHotKey 约定一致）
        if (this.macroType == 3)
            return 1
        return 1
    }

    GetHoldTime() {
        tableItem := MySoftData.TableInfo[this.tableIndex]
        if (this.macroType == 1)
            return tableItem.HoldTimeArr[this.itemIndex]
        if (this.macroType == 2)
            return tableItem.FoldInfo.HoldTimeArr[this.foldIndex]
        return 500
    }

    GetDblClickInterval() {
        return this.GetHoldTime()
    }

    GetWorkState() {
        tableItem := MySoftData.TableInfo[this.tableIndex]
        if (this.macroType == 1)
            return tableItem.IsWorkIndexArr[this.itemIndex]
        if (this.macroType == 2)
            return MainSoftData.CurMenuWheelIndex == this.foldIndex
        if (this.macroType == 3) {
            ; 有任意该模块面板可见则视为工作中（长按等逻辑用）
            if (!IsSet(MyUIMacroGui) || !IsObject(MyUIMacroGui))
                return false
            for key, panelInfo in MyUIMacroGui.PanelMap {
                if (panelInfo.foldIndex == this.foldIndex && panelInfo.visible)
                    return true
            }
            return false
        }
        return false
    }

    Action() {
        if (this.forbidTrigger)
            return
        tableItem := MySoftData.TableInfo[this.tableIndex]
        triggerType := this.GetTriggerType()
        if (this.macroType == 1) {
            if (triggerType == 4) {
                ; 占用标记或 usePool 中仍有该宏的 Worker，都视为运行中 → 停止（避免脏标记导致误启动）
                isRunning := tableItem.IsWorkIndexArr[this.itemIndex]
                if (!isRunning && WorkPoolEnabled() && MyWorkPool.HasItemWork(this.tableIndex, this.itemIndex))
                    isRunning := true
                if (isRunning) {
                    MyStopMacro(this.tableIndex, this.itemIndex)
                    return
                }
                OnToggleTriggerMacro(this.tableIndex, this.itemIndex)
            }
            else
                TriggerMacroHandler(this.tableIndex, this.itemIndex)
        }
        else if (this.macroType == 2) {
            if (triggerType == 3)
                this.forbidTrigger := true
            OpenMenuWheel(this.foldIndex, triggerType == 4)
        }
        else if (this.macroType == 3) {
            ; 界面宏：切换悬浮面板，绝不能误开菜单轮盘
            if (IsSet(MyUIMacroGui) && IsObject(MyUIMacroGui))
                MyUIMacroGui.TogglePanel(this.foldIndex)
        }
    }

    CancelAction() {
        tableItem := MySoftData.TableInfo[this.tableIndex]
        triggerType := this.GetTriggerType()
        if (this.macroType == 1) {
            if (triggerType == 3) {
                WorkerIndex := tableItem.IsWorkIndexArr[this.itemIndex]
                if (WorkerIndex != 0) {
                    MyStopMacro(this.tableIndex, this.itemIndex)
                    tableItem.IsWorkIndexArr[this.itemIndex] := 0
                    return
                }
                KillTableItemMacro(tableItem, this.itemIndex)
            }
        }
        else if (this.macroType == 2) {
            if (triggerType == 3)
                this.forbidTrigger := false
            if (triggerType != 4)
                CloseMenuWheel()
        }
        ; macroType 3：按下切换，松开无需额外处理
    }
}
