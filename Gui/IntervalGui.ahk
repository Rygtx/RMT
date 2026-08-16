#Requires AutoHotkey v2.0

; =====================================================================
; 间隔编辑器 —— XAML 迁移版（独立实现）
; 公开接口保持：ShowGui(cmd) / SureBtnAction / OwnerHwnd / ParentTile
; =====================================================================

class IntervalGui {
    __new() {
        this.ParentTile := ""
        this.ui := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this._closed := true
        this._batch := []
        this._batching := false
    }

    ShowGui(cmd) {
        global MySoftData
        if (IsObject(this.ui) && !this._closed)
            this._CloseWindow()
        this._BuildAndShow()
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
        }
        this._batching := true
        try this.Init(cmd)
        finally {
            this._flushBatch()
        }
    }

    Hwnd() {
        return (IsObject(this.ui) && this.ui.HasProp("wpfHwnd")) ? this.ui.wpfHwnd : 0
    }

    _EscapeXml(s) {
        s := StrReplace(s, "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }

    ; batching 中入队，_flushBatch 一次性 BatchUpdate（合并 Init 的多次 Update 为一次 IPC）
    _ComboPush(comboName, propertyName, value) {
        if (this._batching)
            this._batch.Push({ControlName: comboName, PropertyName: propertyName, Value: value})
        else
            this.ui.Update(comboName, propertyName, value)
    }

    _flushBatch() {
        this._batching := false
        if (IsObject(this.ui) && this._batch.Length > 0) {
            this.ui.BatchUpdate(this._batch)
            this._batch := []
        }
    }

    _BuildAndShow() {
        global MySoftData
        this._closed := false
        title := this.ParentTile GetLang("间隔编辑器")
        this._title := title
        titleHeight := "30"

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}").TextElement_FontSize("12")
        main.Rows(titleHeight, "*")

        ; === 标题栏 ===
        tb := main.Add("Border").Grid_Row(0).Background("{DynamicResource TitleBarColor}").Name("DragArea")
        tbInner := tb.Add("Grid")
        tbInner.Add("TextBlock").Text(title).Foreground("{DynamicResource TitleBarForeground}").FontSize(12).FontWeight("SemiBold").VerticalAlignment("Center").Margin("12,0,0,0")
        BtnGroup := tbInner.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Right")
        closeBtn := BtnGroup.Add("Button").Name("BtnClosePanel").WindowChrome_IsHitTestVisibleInChrome("True").Width(40).Background("Transparent").Foreground("{DynamicResource TitleBarForeground}").BorderThickness(0)
        closeBtn.Add("TextBlock").Text(Chr(0xE8BB)).FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets").FontSize(10).VerticalAlignment("Center").HorizontalAlignment("Center")

        ; === 内容 ===
        body := main.Add("Grid").Grid_Row(1).Margin("24,14")
        body.Rows("34", "34", "34", "*")
        row1 := body.Add("StackPanel").Grid_Row(0).Orientation("Horizontal").VerticalAlignment("Center")
        row1.Add("TextBlock").Text(GetLang("类型：")).Width(92).VerticalAlignment("Center")
        combo := row1.Add("ComboBox").Name("TypeCombo").Width(150).Height(26).MinHeight(26).Margin("4,0,0,0").SelectedIndex("0")
        combo.Add("ComboBoxItem").Content(GetLang("固定")).Tag("1")
        combo.Add("ComboBoxItem").Content(GetLang("随机")).Tag("2")

        row2 := body.Add("StackPanel").Grid_Row(1).Orientation("Horizontal").VerticalAlignment("Center")
        row2.Add("TextBlock").Text(GetLang("时间(毫秒)：")).Width(92).VerticalAlignment("Center")
        row2.Add("ComboBox").Name("TimeVarCon1").Width(150).Height(26).MinHeight(26).Margin("4,0,0,0").IsEditable("True")

        row3 := body.Add("StackPanel").Name("TimeRow2").Grid_Row(2).Orientation("Horizontal").VerticalAlignment("Center")
        row3.Add("TextBlock").Text(GetLang("时间(毫秒)：")).Width(92).VerticalAlignment("Center")
        row3.Add("ComboBox").Name("TimeVarCon2").Width(150).Height(26).MinHeight(26).Margin("4,0,0,0").IsEditable("True")

        btnRow := body.Add("StackPanel").Grid_Row(3).Orientation("Horizontal").HorizontalAlignment("Center").VerticalAlignment("Center")
        btnRow.Add("Button").Name("BtnOk").Content(GetLang("确定")).Width(100).Height(36).MinHeight(36)

        ; === 创建 XAMLHost ===
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", this.OwnerHwnd)
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"', 'Title="' this._EscapeXml(title) '" Width="340" Height="192" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; === 事件 ===
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))
        this.ui.OnEvent("TypeCombo", "SelectionChanged", ObjBindMethod(this, "OnTypeChange"))
        this.ui.OnEvent("BtnOk", "Click", ObjBindMethod(this, "OnClickSureBtn"))

        this.ui.Show()

        gotHwnd := false
        loop 40 {
            if (this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
                gotHwnd := true
                if (this.OwnerHwnd != "")
                    try this.ui.Update("Window", "NativeOwner", String(this.OwnerHwnd))
                try WinActivate("ahk_id " this.ui.wpfHwnd)
                try SetTimer((*) => this.ui.Update("Window", "Opacity", "1"), -10)
                break
            }
            Sleep(50)
        }
        if (!gotHwnd)
            this._closed := true
    }

    OnWindowLoad(state, ctrl, event) {
        try {
            themeName := MainSoftData.HasProp("Theme") ? MainSoftData.Theme : "RMT_Light"
            ApplyXamlTheme(this.ui, themeName)
        } catch {
        } finally {
        }
    }

    OnWindowClosing(state, ctrl, event) {
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
        }
        this.ui := ""
        this._closed := true
    }

    OnCancelClick(state, ctrl, event) {
        this._CloseWindow()
    }

    _CloseWindow() {
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
        }
        if (IsObject(this.ui)) {
            try this.ui.Update("Window", "Close", "")
        }
        this.ui := ""
        this._closed := true
    }

    ; 设置可编辑 ComboBox 候选项 + 当前文本
    _SetCombo(comboName, items, text) {
        if (!IsObject(this.ui))
            return
        this._ComboPush(comboName, "ClearItems", "")
        for it in items {
            if (it == "")
                continue
            this._ComboPush(comboName, "AddItem", it)
        }
        this._ComboPush(comboName, "Text", text)
    }

    _TypeValue() {
        v := IsObject(this.ui) ? this.ui.Query("TypeCombo") : ""
        return IsNumber(v) ? Integer(v) : 1
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        DLVarArr := GetGuiVarArr()
        if (cmdArr.Length <= 1) {
            this.ui.Update("TypeCombo", "SelectedIndex", "0")
            this._SetCombo("TimeVarCon1", DLVarArr, "500")
            this._SetCombo("TimeVarCon2", DLVarArr, "1000")
        }
        else {
            TimeArr := StrSplit(cmdArr[2], "~")
            if (TimeArr.Length <= 1) {
                this.ui.Update("TypeCombo", "SelectedIndex", "0")
                this._SetCombo("TimeVarCon1", DLVarArr, cmdArr[2])
                this._SetCombo("TimeVarCon2", DLVarArr, "1000")
            }
            else {
                this.ui.Update("TypeCombo", "SelectedIndex", "1")
                this._SetCombo("TimeVarCon1", DLVarArr, TimeArr[1])
                this._SetCombo("TimeVarCon2", DLVarArr, TimeArr[2])
            }
        }
        this.OnTypeChange()
    }

    OnTypeChange(state := "", ctrl := "", event := "") {
        showTime2 := this._TypeValue() == 2
        if (IsObject(this.ui))
            this.ui.Update("TimeRow2", "Visibility", showTime2 ? "Visible" : "Collapsed")
    }

    OnClickSureBtn(state, ctrl, event) {
        if (this.SureBtnAction == "")
            return

        timeText := this.ui.Query("TimeVarCon1")
        if (IsNumber(timeText)) {
            if (IsFloat(timeText) || timeText < 0) {
                MsgBox(GetLang("请输入大于0的整数"))
                return
            }
        }

        if (this._TypeValue() == 2) {
            timeText := this.ui.Query("TimeVarCon2")
            if (IsNumber(timeText)) {
                if (IsFloat(timeText) || timeText < 0) {
                    MsgBox(GetLang("请输入大于0的整数"))
                    return
                }
            }

            if (IsNumber(this.ui.Query("TimeVarCon1")) && IsNumber(this.ui.Query("TimeVarCon2"))) {
                if (this.ui.Query("TimeVarCon1") >= this.ui.Query("TimeVarCon2")) {
                    MsgBox(GetLang("上面的时间需要小于下面的时间"))
                    return
                }
            }
        }

        action := this.SureBtnAction
        action(this.GetCmdStr())
        this._CloseWindow()
    }

    GetCmdStr() {
        if (this._TypeValue() == 1) {
            return Format("{}_{}", GetLang("间隔"), this.ui.Query("TimeVarCon1"))
        }
        return Format("{}_{}~{}", GetLang("间隔"), this.ui.Query("TimeVarCon1"), this.ui.Query("TimeVarCon2"))
    }
}
