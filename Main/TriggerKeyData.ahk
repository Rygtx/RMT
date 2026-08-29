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
        this.NeedReleaseBeforeRetrigger := false  ; 连续触发关闭时：需先松开才能再次触发
        this.RepeatTimer := ""  ; 鼠标键按住自动重复计时器（模拟键盘的自动重复）

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

    ; 是否是无松开事件的按键（滚轮 WheelUp/WheelDown/WheelLeft/WheelRight、亮度键等，见 OnlyDownKeyMap）：
    ; 这类按键（含组合键中带这类按键）没有「松开」事件，
    ; 而「连续触发」关闭时需要先松开触发键才能再次触发——
    ; 若对这类按键套用该限制，滚动一次后后续滚动会被永久拦截，因此不受此选项影响。
    IsOnlyDownKey() {
        if (InStr(this.Key, "wheel") || InStr(this.Key, "bright_"))
            return true
        if (!IsObject(MySoftData))
            return false
        for k in MySoftData.OnlyDownKeyMap {
            if (InStr(this.Key, StrLower(k)))
                return true
        }
        return false
    }

    ; 是否为鼠标键（LButton/RButton/MButton/XButton1/XButton2，含组合键中带这类按键）：
    ; 鼠标键按住时不会像键盘键那样产生系统「自动重复」，
    ; 因此在「连续触发」开启时需要手动模拟自动重复，才能实现按住持续触发（与空格等键盘键一致）。
    IsRepeatMouseKey() {
        static Keys := Map("lbutton", 1, "rbutton", 1, "mbutton", 1, "xbutton1", 1, "xbutton2", 1)
        if (Keys.Has(this.Key))
            return true
        for k in Keys {
            if (InStr(this.Key, k))
                return true
        }
        return false
    }

    OnTriggerKeyDown() {
        ; 输入弹窗显示期间，暂时禁用 Enter 触发键（避免回车时误触发宏）
        if (this.Key == "enter" && MySoftData.InputPopUpShowing)
            return

        this.UpdataArr()

        ;双击检测逻辑
        currentTime := A_TickCount
        isDblClick := (currentTime - this.LastKeyDownTime) <= this.DblClickInterval && this.LastKeyDownTime != 0
        this.LastKeyDownTime := currentTime

        ; 滚轮等无松开事件的按键：不受「连续触发」影响（没有松开键，无法"先松开再触发"）
        isOnlyDownKey := this.IsOnlyDownKey()

        ; 连续触发关闭时：按下/开关/长按需先松开触发键才能再次触发
        blockRetrigger := !isOnlyDownKey && !MainSoftData.ContinuousTrigger && this.NeedReleaseBeforeRetrigger

        for index, value in this.DownArr {
            if (blockRetrigger)
                continue
            if (index == 1 && MainSoftData.AutoLoosenModifier && SubStr(value.GetTK(), 1, 1) != "~")
                LoosenModifyKey(value.GetTK())
            value.Action()
        }

        for index, value in this.LoosenStopArr {
            value.Action()
        }

        for index, value in this.TogArr {
            if (blockRetrigger)
                continue
            if (index == 1 && MainSoftData.AutoLoosenModifier && SubStr(value.GetTK(), 1, 1) != "~")
                LoosenModifyKey(value.GetTK())
            value.Action()
        }

        ;如果检测到双击，则触发双击宏
        if (isDblClick) {
            for index, value in this.DblClickArr {
                value.Action()
            }
        }

        if (!blockRetrigger)
            this.SetHoldTimeChecker()

        if (!isOnlyDownKey && !MainSoftData.ContinuousTrigger
            && (this.DownArr.Length > 0 || this.TogArr.Length > 0 || this.HoldArr.Length > 0))
            this.NeedReleaseBeforeRetrigger := true

        ; 鼠标键按住自动重复（连续触发开启时）
        this.UpdateRepeatTimer()
    }

    OnTriggerKeyUp() {
        ; 输入弹窗显示期间，暂时禁用 Enter 触发键（松开事件同样拦截）
        if (this.Key == "enter" && MySoftData.InputPopUpShowing)
            return

        this.UpdataArr()
        this.NeedReleaseBeforeRetrigger := false
        this.StopRepeatTimer()

        for index, value in this.LoosenArr {
            value.Action()
        }

        for index, value in this.LoosenStopArr {
            value.CancelAction()
        }

        this.DelHoldTimeChecker()
    }

    ; ========== 鼠标键按住自动重复 ==========
    ; 键盘键按住会由系统产生自动重复（每个重复都触发一次热键），所以「连续触发」开启时按住能持续触发；
    ; 鼠标键没有系统自动重复，这里用计时器模拟，使按住鼠标键与按住空格等键盘键行为一致。

    ; 按需启停自动重复计时器
    UpdateRepeatTimer() {
        canRepeat := MainSoftData.ContinuousTrigger && this.IsRepeatMouseKey()
            && (this.DownArr.Length > 0 || this.TogArr.Length > 0 || this.HoldArr.Length > 0)
        if (canRepeat) {
            if (this.RepeatTimer == "") {
                this.RepeatTimer := this.RepeatTimerAction.Bind(this)
                SetTimer(this.RepeatTimer, MySoftData.ContinueIntervale)
            }
        }
        else {
            this.StopRepeatTimer()
        }
    }

    StopRepeatTimer() {
        if (this.RepeatTimer != "") {
            SetTimer(this.RepeatTimer, 0)
            this.RepeatTimer := ""
        }
    }

    RepeatTimerAction() {
        ; 按键已松开 → 停止自动重复
        if (!this.IsRepeatKeyHeld()) {
            this.StopRepeatTimer()
            return
        }
        ; 有宏仍在运行 → 本轮跳过，避免重入 / 重复触发
        if (this.HasRunningMacro())
            return
        ; 再次触发「按下/开关/长按」类动作（不重复检测双击，不触发松止）
        this.FireRepeatActions()
    }

    IsRepeatKeyHeld() {
        return AreKeysPressed(this.Key)
    }

    ; 该触发键下是否有宏正在运行
    HasRunningMacro() {
        for _, info in this.DownArr {
            if (this.IsInfoRunning(info))
                return true
        }
        for _, info in this.TogArr {
            if (this.IsInfoRunning(info))
                return true
        }
        for _, info in this.HoldArr {
            if (this.IsInfoRunning(info))
                return true
        }
        return false
    }

    IsInfoRunning(info) {
        if (info.macroType == 1) {
            ; ColorStateArr == 1 表示运行中（主进程与 Worker 两条路径都会置位）
            tableItem := MySoftData.TableInfo[info.tableIndex]
            return tableItem.ColorStateArr.Length >= info.itemIndex && tableItem.ColorStateArr[info.itemIndex] == 1
        }
        return info.GetWorkState()
    }

    FireRepeatActions() {
        for index, value in this.DownArr {
            if (index == 1 && MainSoftData.AutoLoosenModifier && SubStr(value.GetTK(), 1, 1) != "~")
                LoosenModifyKey(value.GetTK())
            value.Action()
        }
        for index, value in this.TogArr {
            if (index == 1 && MainSoftData.AutoLoosenModifier && SubStr(value.GetTK(), 1, 1) != "~")
                LoosenModifyKey(value.GetTK())
            value.Action()
        }
        ; 与按键按下行为一致：为长按宏重新排队
        this.SetHoldTimeChecker()
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

        if (AreKeysPressed(keyCombo)) {
            if (MainSoftData.AutoLoosenModifier && SubStr(info.GetTK(), 1, 1) != "~")
                LoosenModifyKey(info.GetTK())
            info.Action()
            if (!this.IsOnlyDownKey() && !MainSoftData.ContinuousTrigger)
                this.NeedReleaseBeforeRetrigger := true
        }
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
