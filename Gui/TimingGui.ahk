#Requires AutoHotkey v2.0

; 定时宏编辑器：XAML，颜色跟随通用主题
class TimingGui {
    static instances := Map()
    static _opening := false

    __new() {
        this.ui := 0
        this.closed := true
        this._instanceKey := ""
        this.Data := ""
        this.SerialStr := ""
        this._typeIndex := 1
        this._unitIndex := 2
        this._startText := ""
        this._endText := ""
        this._endEnabled := false
        this._intervalText := "10"
        this._btnStyle := ""
        this._editBtnStyle := ""
        this._pickerGui := ""
    }

    ShowGui(SerialStr) {
        this.SerialStr := SerialStr != "" ? SerialStr : GetCMDSerialStr("Timing")
        this.Data := this.GetTimingData(this.SerialStr)
        this._LoadDataToFields()

        key := "timing"
        if (TimingGui.instances.Has(key)) {
            oldInst := TimingGui.instances[key]
            hwnd := (IsObject(oldInst.ui) && oldInst.ui.HasProp("wpfHwnd")) ? oldInst.ui.wpfHwnd : 0
            if (!oldInst.closed && XAMLHost.CanReuseWindow(hwnd)) {
                oldInst.SerialStr := this.SerialStr
                oldInst.Data := this.Data
                oldInst._LoadDataToFields()
                oldInst._ApplyValuesToUI()
                try WinActivate("ahk_id " hwnd)
                return
            }
            try {
                if (!oldInst.closed && IsObject(oldInst.ui))
                    oldInst.Close()
            }
            TimingGui.instances.Delete(key)
        }

        XAMLHost.EnsureDaemonHealthy()
        if (TimingGui._opening)
            return
        TimingGui._opening := true
        try {
            this._instanceKey := key
            this._BuildAndShow()
            TimingGui.instances[key] := this
        } finally {
            TimingGui._opening := false
        }
    }

    _LoadDataToFields() {
        this._startText := this._FormatStamp(this.Data.StartStamp)
        this._endEnabled := this.Data.HasOwnProp("EndStamp") && this.Data.EndStamp
        this._endText := this._endEnabled
            ? this._FormatStamp(this.Data.EndStamp)
            : this._DefaultEndText()
        this._typeIndex := Integer(this.Data.Type)
        if (this._typeIndex < 1 || this._typeIndex > 3)
            this._typeIndex := 1
        this._intervalText := String(this.Data.HasOwnProp("CustomInterval") ? this.Data.CustomInterval : "10")
        this._unitIndex := Integer(this.Data.HasOwnProp("CustomUnit") ? this.Data.CustomUnit : 2)
        if (this._unitIndex < 1 || this._unitIndex > 6)
            this._unitIndex := 2
    }

    _DefaultEndText() {
        return FormatTime(DateAdd(A_Now, 2, "Hours"), "yyyy-MM-dd HH:mm:ss")
    }

    _FormatStamp(stamp) {
        if (!stamp)
            return FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        return FormatTime(StampToTimeStr(stamp), "yyyy-MM-dd HH:mm:ss")
    }

    _ParseTimeText(text) {
        t := RegExReplace(Trim(String(text)), "[^\d]", "")
        return (StrLen(t) == 14) ? t : ""
    }

    _BuildAndShow() {
        this.closed := false
        title := GetLang("定时编辑器")
        titleHeight := "36"
        winW := 420
        winH := 240
        this._btnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionHoverBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        this._editBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource EditHoverBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource EditHoverStroke}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}")
        main.Rows(titleHeight, "*")

        tb := main.Add("Border").Grid_Row(0).Background("{DynamicResource TitleBarColor}").Name("DragArea")
        tbInner := tb.Add("Grid")
        tbInner.Add("TextBlock").Text(title).Foreground("{DynamicResource TitleBarForeground}").FontSize(12).FontWeight("SemiBold").VerticalAlignment("Center").Margin("15,0,0,0")
        BtnGroup := tbInner.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Right")
        CloseBtnTemplate := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="{DynamicResource CloseBtnRadius}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="border" Property="Background" Value="#E0FF3333"/><Setter Property="Foreground" Value="White"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        closeBtn := BtnGroup.Add("Button").Name("BtnClosePanel").WindowChrome_IsHitTestVisibleInChrome("True").Width(40).Background("Transparent").Foreground("{DynamicResource TitleBarForeground}").BorderThickness(0)
        closeBtn.InjectResources(CloseBtnTemplate)
        closeBtn.Add("TextBlock").Text(Chr(0xE8BB)).FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets").FontSize(10).VerticalAlignment("Center").HorizontalAlignment("Center")

        body := main.Add("StackPanel").Grid_Row(1).Margin("18,8,18,8")

        timeBoxW := "150"
        labelW := "72"
        chkW := "22"

        ; 表单同网格居中：开始/结束/定时类型/每次间隔 label 左缘对齐
        formBlock := body.Add("Grid").HorizontalAlignment("Center").Margin("0,0,0,0")
        formBlock.Rows("Auto", "Auto", "Auto", "Auto")
        formBlock.Cols(chkW, labelW, "Auto", "Auto", "Auto")

        ; 开始时间（勾选列隐藏占位）
        formBlock.Add("CheckBox").Visibility("Hidden").VerticalAlignment("Center")
            .Grid_Row(0).Grid_Column(0).Margin("0,0,0,8")
        formBlock.Add("TextBlock").Text(GetLang("开始时间：")).Foreground("{DynamicResource TextMain}").FontSize(13)
            .VerticalAlignment("Center").Margin("0,0,4,8").Grid_Row(0).Grid_Column(1)
        this._AddTextBox(formBlock, "StartTimeCon", "", timeBoxW, true, true)
            .Grid_Row(0).Grid_Column(2).Margin("0,0,0,8")
        startCalBtn := formBlock.Add("Button").Name("BtnStartCal")
            .Width(28).Height(26).MinHeight(26).Margin("6,0,0,8").Cursor("Hand")
            .VerticalAlignment("Center").Grid_Row(0).Grid_Column(3)
            .Background("{DynamicResource EditBg}").Foreground("{DynamicResource EditText}")
            .BorderBrush("{DynamicResource EditStroke}").BorderThickness("1")
        startCalBtn.InjectResources(this._editBtnStyle)
        startCalBtn.Add("TextBlock").Text(Chr(0xE787)).FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
            .FontSize(12).HorizontalAlignment("Center").VerticalAlignment("Center")
        formBlock.Add("Border").Width(28).Height(1).Margin("6,0,0,8")
            .Grid_Row(0).Grid_Column(4)

        ; 结束时间
        endChk := formBlock.Add("CheckBox").Name("EndEnableCon").Content("")
            .VerticalAlignment("Center").HorizontalAlignment("Left")
            .Grid_Row(1).Grid_Column(0).Margin("0,0,0,8")
            .Foreground("{DynamicResource TextMain}")
        formBlock.Add("TextBlock").Name("EndLabelCon").Text(GetLang("结束时间："))
            .Foreground("{DynamicResource TextMain}").FontSize(13)
            .VerticalAlignment("Center").Margin("0,0,4,8").Grid_Row(1).Grid_Column(1)
        this._AddTextBox(formBlock, "EndTimeCon", "", timeBoxW, true, true)
            .Grid_Row(1).Grid_Column(2).Margin("0,0,0,8")
        endCalBtn := formBlock.Add("Button").Name("BtnEndCal")
            .Width(28).Height(26).MinHeight(26).Margin("6,0,0,8").Cursor("Hand")
            .VerticalAlignment("Center").Grid_Row(1).Grid_Column(3)
            .Background("{DynamicResource EditBg}").Foreground("{DynamicResource EditText}")
            .BorderBrush("{DynamicResource EditStroke}").BorderThickness("1")
        endCalBtn.InjectResources(this._editBtnStyle)
        endCalBtn.Add("TextBlock").Name("BtnEndCalIcon").Text(Chr(0xE787))
            .FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
            .FontSize(12).HorizontalAlignment("Center").VerticalAlignment("Center")
        helpBtn := formBlock.Add("Button").Name("BtnEndHelp").Content("?")
            .Width(28).Height(26).MinHeight(26).Margin("6,0,0,8").Cursor("Hand").FontSize(13)
            .VerticalAlignment("Center").Grid_Row(1).Grid_Column(4)
            .Background("{DynamicResource EditBg}").Foreground("{DynamicResource EditText}")
            .BorderBrush("{DynamicResource EditStroke}").BorderThickness("1")
        helpBtn.InjectResources(this._editBtnStyle)

        ; 定时类型（独立一行，label 与开始时间对齐）
        formBlock.Add("CheckBox").Visibility("Hidden").VerticalAlignment("Center")
            .Grid_Row(2).Grid_Column(0).Margin("0,0,0,8")
        formBlock.Add("TextBlock").Text(GetLang("定时类型：")).Foreground("{DynamicResource TextMain}").FontSize(13)
            .VerticalAlignment("Center").Margin("0,0,4,8").Grid_Row(2).Grid_Column(1)
        typeNames := GetLangArr(["单次", "软件启动时", "自定义"])
        typeCmb := formBlock.Add("ComboBox").Name("TypeCon").Width(timeBoxW).Height(26).MinHeight(26)
            .Grid_Row(2).Grid_Column(2).Margin("0,0,0,8").VerticalAlignment("Center")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
        for n in typeNames
            typeCmb.Add("ComboBoxItem").Content(n)

        ; 每次间隔（独立一行；非自定义时灰显仍显示）
        intervalRow := formBlock.Add("Grid").Name("IntervalRow")
            .Grid_Row(3).Grid_Column(0).Grid_ColumnSpan(5)
        intervalRow.Cols(chkW, labelW, "Auto", "Auto")
        intervalRow.Add("CheckBox").Visibility("Hidden").VerticalAlignment("Center").Grid_Column(0)
        intervalRow.Add("TextBlock").Name("IntervalLabel").Text(GetLang("每次间隔："))
            .Foreground("{DynamicResource TextMain}").FontSize(13)
            .VerticalAlignment("Center").Margin("0,0,4,0").Grid_Column(1)
        this._AddTextBox(intervalRow, "IntervalCon", "10", "70").Grid_Column(2)
        unitNames := GetLangArr(["秒", "分钟", "小时", "天", "周", "月"])
        unitCmb := intervalRow.Add("ComboBox").Name("UnitCon").Width(72).Height(26).MinHeight(26)
            .Grid_Column(3).Margin("6,0,0,0").VerticalAlignment("Center")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
        for n in unitNames
            unitCmb.Add("ComboBoxItem").Content(n)

        btnRow := body.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Center").Margin("0,18,0,0")
        okBtn := btnRow.Add("Button").Name("BtnConfirm").Content(GetLang("确定"))
            .Background("{DynamicResource ActionBg}").Foreground("{DynamicResource ActionText}").FontWeight("Bold")
            .BorderBrush("{DynamicResource ActionStroke}").BorderThickness("1")
            .FontSize(13).Cursor("Hand").Width(90).Height(32)
        okBtn.InjectResources(this._btnStyle)

        pos := GetCenterPosOnActiveMonitor(winW, winH)
        dipX := PhysToDip(pos.x)
        dipY := PhysToDip(pos.y)
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", "")
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"',
            Format('Title="{}" ShowInTaskbar="False" Width="{}" Height="{}" Left="{}" Top="{}" Opacity="0"',
                title, winW, winH, dipX, dipY))
        this.ui.xaml := StrReplace(this.ui.xaml, 'WindowStartupLocation="CenterScreen"', 'WindowStartupLocation="Manual"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'CornerRadius="{DynamicResource WindowRadius}"', 'CornerRadius="{DynamicResource PanelRadius}"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '<CornerRadius x:Key="PanelRadius">8</CornerRadius>')

        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCloseClick"))
        this.ui.OnEvent("BtnConfirm", "Click", ObjBindMethod(this, "OnSureBtnClick"))
        this.ui.OnEvent("BtnStartCal", "Click", ObjBindMethod(this, "OnStartCalClick"))
        this.ui.OnEvent("BtnEndCal", "Click", ObjBindMethod(this, "OnEndCalClick"))
        this.ui.OnEvent("BtnEndHelp", "Click", ObjBindMethod(this, "OnEndHelpClick"))
        this.ui.Track("StartTimeCon")
        this.ui.Track("EndTimeCon")
        this.ui.Track("EndEnableCon")
        this.ui.Track("TypeCon")
        this.ui.Track("IntervalCon")
        this.ui.Track("UnitCon")
        this.ui.OnEvent("TypeCon", "SelectionChanged", ObjBindMethod(this, "OnChangeType"))
        this.ui.OnEvent("TypeCon", "DropDownClosed", ObjBindMethod(this, "OnChangeType"))
        this.ui.OnEvent("EndEnableCon", "Checked", ObjBindMethod(this, "OnEndEnableChanged"))
        this.ui.OnEvent("EndEnableCon", "Unchecked", ObjBindMethod(this, "OnEndEnableChanged"))

        this.ui.Show()
        loop 40 {
            if (this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
                this._ApplyValuesToUI()
                try this.ui.Update("Window", "Opacity", "1")
                try WinActivate("ahk_id " this.ui.wpfHwnd)
                break
            }
            Sleep(50)
        }
    }

    _AddTextBox(parent, name, text, width, readOnly := false, centerText := false) {
        tb := parent.Add("TextBox").Name(name).Text(text).Height(26).MinHeight(26)
            .FontSize(12).FontFamily(MainSoftData.FontType)
            .VerticalAlignment("Center").VerticalContentAlignment("Center")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1").Padding("6,0")
        if (width != "*")
            tb.Width(width)
        if (readOnly)
            tb.IsReadOnly("True")
        if (centerText)
            tb.TextAlignment("Center")
        return tb
    }

    OnWindowLoad(state, ctrl, event) {
        try {
            themeName := MainSoftData.HasProp("Theme") ? MainSoftData.Theme : "RMT_Light"
            ApplyXamlTheme(this.ui, themeName)
            this._ApplyValuesToUI()
        } finally {
            this.ui.Update("Window", "Opacity", "1")
        }
    }

    OnWindowClosing(state, ctrl, event) {
        this._ClosePicker()
        this.closed := true
        TimingGui._opening := false
        if (this._instanceKey != "" && TimingGui.instances.Has(this._instanceKey))
            TimingGui.instances.Delete(this._instanceKey)
        this.ui := ""
        try {
            if (!XAMLHost.IsDaemonAlive())
                XAMLHost.ResetDaemon()
        }
    }

    OnCloseClick(state := unset, ctrl := unset, event := unset) {
        this.Close()
    }

    Close() {
        this._ClosePicker()
        this.closed := true
        if IsObject(this.ui) {
            try this.ui.Update("Window", "Close", "")
            this.ui := ""
        }
    }

    _ClosePicker() {
        if (IsObject(this._pickerGui)) {
            try this._pickerGui.Destroy()
            this._pickerGui := ""
        }
    }

    _ApplyValuesToUI() {
        if (!IsObject(this.ui) || this.closed)
            return
        try this.ui.Update("StartTimeCon", "Text", this._startText)
        try this.ui.Update("EndTimeCon", "Text", this._endText)
        try this.ui.Update("EndEnableCon", "IsChecked", this._endEnabled ? "True" : "False")
        try this.ui.Update("TypeCon", "SelectedIndex", this._typeIndex - 1)
        try this.ui.Update("IntervalCon", "Text", this._intervalText)
        try this.ui.Update("UnitCon", "SelectedIndex", this._unitIndex - 1)
        this._RefreshIntervalVisibility()
        this._RefreshEndEnabled()
    }

    OnChangeType(state := unset, ctrl := unset, event := unset) {
        if (IsSet(state) && IsObject(state) && state.Has("TypeCon") && state["TypeCon"] != "") {
            names := GetLangArr(["单次", "软件启动时", "自定义"])
            loop names.Length {
                if (state["TypeCon"] == names[A_Index]) {
                    this._typeIndex := A_Index
                    break
                }
            }
        } else if (IsObject(this.ui)) {
            idx := this.ui.Query("TypeCon>SelectedIndex")
            if (idx != "" && IsNumber(idx))
                this._typeIndex := Integer(idx) + 1
        }
        this._RefreshIntervalVisibility()
    }

    OnEndEnableChanged(state := unset, ctrl := unset, event := unset) {
        enabled := this._endEnabled
        if (IsSet(state) && IsObject(state) && state.Has("EndEnableCon"))
            enabled := (state["EndEnableCon"] = "True" || state["EndEnableCon"] = "true" || state["EndEnableCon"] = "1")
        else if (IsObject(this.ui)) {
            v := this.ui.Query("EndEnableCon")
            enabled := (v = "True" || v = "true" || v = "1")
        }
        this._endEnabled := enabled
        if (enabled && Trim(this._endText) == "") {
            this._endText := this._DefaultEndText()
            try this.ui.Update("EndTimeCon", "Text", this._endText)
        }
        this._RefreshEndEnabled()
    }

    _RefreshIntervalVisibility() {
        if (!IsObject(this.ui))
            return
        ; 始终显示；仅自定义时可编辑，其余类型灰显
        try this.ui.Update("IntervalRow", "Visibility", "Visible")
        if (this._typeIndex == 3) {
            try this.ui.Update("IntervalLabel", "Foreground", "{DynamicResource TextMain}")
            try this.ui.Update("IntervalLabel", "Opacity", "1")
            try this.ui.Update("IntervalCon", "IsEnabled", "True")
            try this.ui.Update("IntervalCon", "Opacity", "1")
            try this.ui.Update("IntervalCon", "Foreground", "{DynamicResource InputText}")
            try this.ui.Update("UnitCon", "IsEnabled", "True")
            try this.ui.Update("UnitCon", "Opacity", "1")
            try this.ui.Update("UnitCon", "Foreground", "{DynamicResource InputText}")
        } else {
            try this.ui.Update("IntervalLabel", "Foreground", "{DynamicResource TextSub}")
            try this.ui.Update("IntervalLabel", "Opacity", "0.55")
            try this.ui.Update("IntervalCon", "IsEnabled", "False")
            try this.ui.Update("IntervalCon", "Opacity", "0.45")
            try this.ui.Update("IntervalCon", "Foreground", "{DynamicResource TextSub}")
            try this.ui.Update("UnitCon", "IsEnabled", "False")
            try this.ui.Update("UnitCon", "Opacity", "0.45")
            try this.ui.Update("UnitCon", "Foreground", "{DynamicResource TextSub}")
        }
    }

    _RefreshEndEnabled() {
        if (!IsObject(this.ui))
            return
        ; 自定义模板无 IsEnabled 灰显样式，需同步 Opacity / Foreground；问号始终可点
        if (this._endEnabled) {
            try this.ui.Update("EndLabelCon", "Foreground", "{DynamicResource TextMain}")
            try this.ui.Update("EndLabelCon", "Opacity", "1")
            try this.ui.Update("EndTimeCon", "IsEnabled", "True")
            try this.ui.Update("EndTimeCon", "Opacity", "1")
            try this.ui.Update("EndTimeCon", "Foreground", "{DynamicResource InputText}")
            try this.ui.Update("BtnEndCal", "IsEnabled", "True")
            try this.ui.Update("BtnEndCal", "Opacity", "1")
            try this.ui.Update("BtnEndCalIcon", "Opacity", "1")
        } else {
            try this.ui.Update("EndLabelCon", "Foreground", "{DynamicResource TextSub}")
            try this.ui.Update("EndLabelCon", "Opacity", "0.55")
            try this.ui.Update("EndTimeCon", "IsEnabled", "False")
            try this.ui.Update("EndTimeCon", "Opacity", "0.45")
            try this.ui.Update("EndTimeCon", "Foreground", "{DynamicResource TextSub}")
            try this.ui.Update("BtnEndCal", "IsEnabled", "False")
            try this.ui.Update("BtnEndCal", "Opacity", "0.45")
            try this.ui.Update("BtnEndCalIcon", "Opacity", "0.45")
        }
        try this.ui.Update("BtnEndHelp", "IsEnabled", "True")
        try this.ui.Update("BtnEndHelp", "Opacity", "1")
    }

    OnStartCalClick(state := unset, ctrl := unset, event := unset) {
        this._ReadUIState(IsSet(state) ? state : unset)
        this._ShowDateTimePicker("start", this._startText)
    }

    OnEndCalClick(state := unset, ctrl := unset, event := unset) {
        this._ReadUIState(IsSet(state) ? state : unset)
        if (!this._endEnabled)
            return
        seed := this._endText != "" ? this._endText : this._DefaultEndText()
        this._ShowDateTimePicker("end", seed)
    }

    OnEndHelpClick(state := unset, ctrl := unset, event := unset) {
        ; 无 Icon，避免系统提示音；内容两行显示
        MsgBox(GetLang("勾选后，到达结束时间将不再触发此定时宏；") "`n" GetLang("若宏正在运行也会被停止。"), GetLang("结束时间："))
    }

    _ShowDateTimePicker(which, currentText) {
        this._ClosePicker()
        owner := 0
        if (IsObject(this.ui) && this.ui.HasProp("wpfHwnd"))
            owner := this.ui.wpfHwnd

        picker := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", GetLang("选择时间"))
        picker.SetFont("S10", MainSoftData.FontType)
        if (owner)
            picker.Opt("+Owner" owner)

        picker.Add("Text", "x12 y14", GetLang("时间："))
        dt := picker.Add("DateTime", "x60 y10 w220", "yyyy-MM-dd HH:mm:ss")
        raw := this._ParseTimeText(currentText)
        if (raw != "")
            try dt.Value := raw

        okBtn := picker.Add("Button", "x70 y50 w80 h30 Default", GetLang("确定"))
        cancelBtn := picker.Add("Button", "x170 y50 w80 h30", GetLang("取消"))
        this._pickerGui := picker

        okBtn.OnEvent("Click", (*) => this._OnPickerSure(which, dt, picker))
        cancelBtn.OnEvent("Click", (*) => this._OnPickerCancel(picker))
        picker.OnEvent("Close", (*) => this._OnPickerCancel(picker))

        pos := GetCenterPosOnActiveMonitor(300, 100)
        picker.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 300, 100))
    }

    _OnPickerSure(which, dt, picker) {
        text := FormatTime(dt.Value, "yyyy-MM-dd HH:mm:ss")
        if (which == "start") {
            this._startText := text
            try this.ui.Update("StartTimeCon", "Text", text)
        } else {
            this._endText := text
            this._endEnabled := true
            try this.ui.Update("EndTimeCon", "Text", text)
            try this.ui.Update("EndEnableCon", "IsChecked", "True")
            this._RefreshEndEnabled()
        }
        this._pickerGui := ""
        try picker.Destroy()
    }

    _OnPickerCancel(picker) {
        if (this._pickerGui == picker)
            this._pickerGui := ""
        try picker.Destroy()
    }

    _ReadUIState(state := unset) {
        if (IsSet(state) && IsObject(state)) {
            if (state.Has("StartTimeCon"))
                this._startText := state["StartTimeCon"]
            if (state.Has("EndTimeCon"))
                this._endText := state["EndTimeCon"]
            if (state.Has("IntervalCon"))
                this._intervalText := state["IntervalCon"]
            if (state.Has("EndEnableCon"))
                this._endEnabled := (state["EndEnableCon"] = "True" || state["EndEnableCon"] = "true" || state["EndEnableCon"] = "1")
            if (state.Has("TypeCon") && state["TypeCon"] != "") {
                names := GetLangArr(["单次", "软件启动时", "自定义"])
                loop names.Length {
                    if (state["TypeCon"] == names[A_Index]) {
                        this._typeIndex := A_Index
                        break
                    }
                }
            }
            if (state.Has("UnitCon") && state["UnitCon"] != "") {
                units := GetLangArr(["秒", "分钟", "小时", "天", "周", "月"])
                loop units.Length {
                    if (state["UnitCon"] == units[A_Index]) {
                        this._unitIndex := A_Index
                        break
                    }
                }
            }
        }
        if (IsObject(this.ui)) {
            v := this.ui.Query("StartTimeCon")
            if (v != "")
                this._startText := v
            v := this.ui.Query("EndTimeCon")
            this._endText := v
            v := this.ui.Query("IntervalCon")
            if (v != "")
                this._intervalText := v
            v := this.ui.Query("EndEnableCon")
            if (v != "")
                this._endEnabled := (v = "True" || v = "true" || v = "1")
            idx := this.ui.Query("TypeCon>SelectedIndex")
            if (idx != "" && IsNumber(idx))
                this._typeIndex := Integer(idx) + 1
            idx := this.ui.Query("UnitCon>SelectedIndex")
            if (idx != "" && IsNumber(idx))
                this._unitIndex := Integer(idx) + 1
        }
    }

    CheckIfValid() {
        startRaw := this._ParseTimeText(this._startText)
        if (startRaw == "") {
            MsgBox(GetLang("请输入正确的开始时间（yyyy-MM-dd HH:mm:ss）"))
            return false
        }
        if (this._endEnabled) {
            endRaw := this._ParseTimeText(this._endText)
            if (endRaw == "") {
                MsgBox(GetLang("请输入正确的结束时间（yyyy-MM-dd HH:mm:ss）"))
                return false
            }
            if (endRaw <= startRaw) {
                MsgBox(GetLang("勾选结束时间后，结束时间必须大于开始时间！！！"))
                return false
            }
        }
        if (this._typeIndex == 3) {
            if (!IsNumber(this._intervalText) || this._intervalText + 0 <= 0) {
                MsgBox(GetLang("每次间隔需要输入大于零的数字！！！"))
                return false
            }
            if (InStr(String(this._intervalText), ".")) {
                MsgBox(GetLang("每次间隔时间只能是整数！！"))
                return false
            }
        }
        return true
    }

    OnSureBtnClick(state := unset, ctrl := unset, event := unset) {
        this._ReadUIState(IsSet(state) ? state : unset)
        if (!this.CheckIfValid())
            return
        this.SaveTimingData()
        this.Close()
    }

    SaveTimingData() {
        Data := this.Data
        startRaw := this._ParseTimeText(this._startText)
        endRaw := ""
        if (this._endEnabled)
            endRaw := this._ParseTimeText(this._endText)
        Data.StartStamp := TimeStrToStamp(startRaw)
        Data.EndStamp := endRaw == "" ? 0 : TimeStrToStamp(endRaw)
        Data.Type := this._typeIndex
        Data.CustomInterval := this._intervalText
        Data.CustomUnit := this._unitIndex

        minimal := {}
        minimal.StartStamp := Data.StartStamp
        minimal.Type := Data.Type
        if (Data.EndStamp)
            minimal.EndStamp := Data.EndStamp
        if (Data.Type == 3) {
            minimal.CustomInterval := Data.CustomInterval
            minimal.CustomUnit := Data.CustomUnit
        }

        saveStr := JSON.stringify(minimal, 0)
        IniWrite(saveStr, TimingFile, IniSection, Data.SerialStr)
        if (MySoftData.DataCacheMap.Has(Data.SerialStr))
            MySoftData.DataCacheMap.Delete(Data.SerialStr)
    }

    GetTimingData(SerialStr) {
        saveStr := IniRead(TimingFile, IniSection, SerialStr, "")
        if (!saveStr) {
            data := TimingData()
            data.SerialStr := SerialStr
            return data
        }
        data := JSON.parse(saveStr, , false)
        data.SerialStr := SerialStr
        if (data.HasOwnProp("StartTime") && !data.HasOwnProp("StartStamp")) {
            data.StartStamp := TimeStrToStamp(data.StartTime)
            if (data.HasOwnProp("EndTime") && data.EndTime != "")
                data.EndStamp := TimeStrToStamp(data.EndTime)
        }
        return data
    }
}
