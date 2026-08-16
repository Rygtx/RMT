#Requires AutoHotkey v2.0

; =====================================================================
; 移动编辑器 —— XAML 迁移版（独立实现）
; 公开接口保持：ShowGui(cmd) / SureBtnAction / OwnerHwnd / ParentTile
; =====================================================================

class MouseMoveGui {
    __new() {
        this.ParentTile := ""
        this.ui := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this._closed := true
        this.PosAction := () => this.RefreshMousePos()
    }

    ShowGui(cmd) {
        global MySoftData
        if (IsObject(this.ui) && !this._closed)
            this._CloseWindow()
        this._BuildAndShow()
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
        }
        this.Init(cmd)
        this.ToggleFunc(true)
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

    _BuildAndShow() {
        global MySoftData
        this._closed := false
        title := this.ParentTile GetLang("移动编辑器")
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
        body := main.Add("Grid").Grid_Row(1).Margin("10,8")
        body.Rows("34", "30", "26", "36", "36", "24", "34", "*")
        body.Cols("90", "100", "90", "130")

        ; 行0：快捷方式 + 执行指令
        row0 := body.Add("StackPanel").Grid_Row(0).Grid_ColumnSpan(4).Orientation("Horizontal").VerticalAlignment("Center")
        row0.Add("TextBlock").Text(GetLang("快捷方式：")).VerticalAlignment("Center")
        row0.Add("TextBox").Width(60).Height(24).MinHeight(24).Margin("4,0,0,0").Text("!l").IsReadOnly("True")
        row0.Add("Button").Name("BtnExecute").Content(GetLang("执行指令")).Height(26).MinHeight(26).Margin("14,0,0,0")

        ; 行1：F1 + 定位取色器
        row1 := body.Add("StackPanel").Grid_Row(1).Grid_ColumnSpan(4).Orientation("Horizontal").VerticalAlignment("Center")
        row1.Add("TextBlock").Text(GetLang("F1:选取当前坐标")).VerticalAlignment("Center")
        row1.Add("Button").Name("BtnTargeter").Content(GetLang("定位取色器")).Width(100).Height(26).MinHeight(26).Margin("14,0,0,0")
        row1.Add("Button").Name("BtnTargeterHelp").Content("?").Width(30).Height(26).MinHeight(26).Margin("4,0,0,0")

        ; 行2：鼠标位置
        body.Add("TextBlock").Grid_Row(2).Grid_ColumnSpan(4).Name("MousePosCon").Text(GetLang("当前鼠标位置:0,0")).VerticalAlignment("Center")

        ; 行3：坐标位置X/Y
        body.Add("TextBlock").Grid_Row(3).Grid_Column(0).Text(GetLang("坐标位置X:")).VerticalAlignment("Center")
        body.Add("TextBox").Grid_Row(3).Grid_Column(1).Name("PosXCon").Height(26).MinHeight(26).VerticalContentAlignment("Center")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
        body.Add("TextBlock").Grid_Row(3).Grid_Column(2).Text(GetLang("坐标位置Y:")).VerticalAlignment("Center")
        body.Add("TextBox").Grid_Row(3).Grid_Column(3).Name("PosYCon").Height(26).MinHeight(26).VerticalContentAlignment("Center")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")

        ; 行4：移动速度 + 移动方式
        body.Add("TextBlock").Grid_Row(4).Grid_Column(0).Text(GetLang("移动速度：")).VerticalAlignment("Center")
        body.Add("TextBox").Grid_Row(4).Grid_Column(1).Name("SpeedCon").Height(26).MinHeight(26).VerticalContentAlignment("Center").Text("90")
            .Background("{DynamicResource InputBg}").Foreground("{DynamicResource InputText}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
        body.Add("TextBlock").Grid_Row(4).Grid_Column(2).Text(GetLang("移动方式：")).VerticalAlignment("Center")
        mm := body.Add("ComboBox").Grid_Row(4).Grid_Column(3).Name("MouseMoveModeCombo").Height(26).MinHeight(26)
        for m in GetLangArr(["绝对移动", "相对移动", "游戏视角"])
            mm.Add("ComboBoxItem").Content(m)

        ; 行5：提示
        body.Add("TextBlock").Grid_Row(5).Grid_ColumnSpan(4).Text(GetLang("移动速度0~100，100为瞬移")).VerticalAlignment("Center")

        ; 行6：当前指令
        body.Add("TextBlock").Grid_Row(6).Grid_ColumnSpan(4).Name("CommandStrCon").Text(GetLang("当前指令：移动")).VerticalAlignment("Center")

        ; 行7：确定
        btnRow := body.Add("StackPanel").Grid_Row(7).Grid_ColumnSpan(4).Orientation("Horizontal").HorizontalAlignment("Center").VerticalAlignment("Center")
        btnRow.Add("Button").Name("BtnOk").Content(GetLang("确定")).Width(100).Height(36).MinHeight(36)

        ; === 创建 XAMLHost ===
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", this.OwnerHwnd)
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"', 'Title="' this._EscapeXml(title) '" Width="500" Height="300" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; === 事件 ===
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))
        this.ui.OnEvent("BtnExecute", "Click", ObjBindMethod(this, "TriggerMacro"))
        this.ui.OnEvent("PosXCon", "TextChanged", ObjBindMethod(this, "OnChangeEditValue"))
        this.ui.OnEvent("PosYCon", "TextChanged", ObjBindMethod(this, "OnChangeEditValue"))
        this.ui.OnEvent("SpeedCon", "TextChanged", ObjBindMethod(this, "OnChangeEditValue"))
        this.ui.OnEvent("MouseMoveModeCombo", "SelectionChanged", ObjBindMethod(this, "OnChangeEditValue"))
        this.ui.OnEvent("BtnTargeter", "Click", ObjBindMethod(this, "OnClickTargeterBtn"))
        this.ui.OnEvent("BtnTargeterHelp", "Click", ObjBindMethod(this, "OnClickTargeterHelpBtn"))
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
        try this.ToggleFunc(false)
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
        if (IsObject(this.ui)) {
            try this.ui.Update("Window", "Close", "")
        }
        try this.ToggleFunc(false)
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
        }
        this.ui := ""
        this._closed := true
    }

    _MoveMode() {
        v := IsObject(this.ui) ? this.ui.Query("MouseMoveModeCombo>SelectedIndex") : ""
        return IsNumber(v) ? Integer(v) : 0
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        PosX := cmdArr.Length >= 2 ? cmdArr[2] : 0
        PosY := cmdArr.Length >= 3 ? cmdArr[3] : 0
        Speed := cmdArr.Length >= 4 ? cmdArr[4] : 90
        MoveMode := 0
        if (cmdArr.Length >= 5)
            MoveMode := Integer(cmdArr[5])

        this.ui.Update("PosXCon", "Text", PosX)
        this.ui.Update("PosYCon", "Text", PosY)
        this.ui.Update("SpeedCon", "Text", Speed)
        this.ui.Update("MouseMoveModeCombo", "SelectedIndex", String(MoveMode))
        this.OnMoveModeChange()
        this.UpdateCommandStr()
    }

    CheckIfValid() {
        if (!IsNumber(this.ui.Query("PosXCon"))) {
            MsgBox(GetLang("坐标X请输入数字"))
            return false
        }
        if (!IsNumber(this.ui.Query("PosYCon"))) {
            MsgBox(GetLang("坐标Y请输入数字"))
            return false
        }
        if (!IsInteger(this.ui.Query("SpeedCon"))) {
            MsgBox(GetLang("移动速度请输入整数"))
            return false
        }
        return true
    }

    UpdateCommandStr() {
        if (!IsObject(this.ui))
            return
        MoveMode := this._MoveMode()
        CommandStr := GetLang("移动")
        CommandStr .= "_" this.ui.Query("PosXCon")
        CommandStr .= "_" this.ui.Query("PosYCon")
        CommandStr .= "_" this.ui.Query("SpeedCon")
        if (MoveMode != 0)
            CommandStr .= "_" MoveMode
        this.ui.Update("CommandStrCon", "Text", CommandStr)
    }

    ToggleFunc(state) {
        if (state) {
            try SetTimer this.PosAction, 100
            try Hotkey("!l", (*) => this.TriggerMacro(), "On")
            try Hotkey("F1", (*) => this.SureCoord(), "On")
        }
        else {
            try SetTimer this.PosAction, 0
            try Hotkey("!l", (*) => this.TriggerMacro(), "Off")
            try Hotkey("F1", (*) => this.SureCoord(), "Off")
        }
    }

    RefreshMousePos() {
        static posLabel := ""
        if (posLabel == "")
            posLabel := GetLang("当前鼠标位置:")
        if (!IsObject(this.ui))
            return
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY
        this.ui.Update("MousePosCon", "Text", posLabel mouseX "," mouseY)
    }

    OnChangeEditValue(state := "", ctrl := "", event := "") {
        if (!IsObject(this.ui))
            return
        this.OnMoveModeChange()
        this.UpdateCommandStr()
    }

    OnMoveModeChange() {
        if (!IsObject(this.ui))
            return
        MoveMode := this._MoveMode()
        if (MoveMode == 2) {
            this.ui.Update("SpeedCon", "Text", "100")
            this.ui.Update("SpeedCon", "IsEnabled", "False")
        }
        else {
            this.ui.Update("SpeedCon", "IsEnabled", "True")
        }
    }

    OnSureTarget(PosX, PosY, Color) {
        if (IsObject(this.ui)) {
            this.ui.Update("PosXCon", "Text", PosX)
            this.ui.Update("PosYCon", "Text", PosY)
            this.UpdateCommandStr()
        }
    }

    OnClickTargeterBtn(state := "", ctrl := "", event := "") {
        MyTargetGui.SureAction := this.OnSureTarget.Bind(this)
        MyTargetGui.ShowGui()
    }

    OnClickTargeterHelpBtn(state := "", ctrl := "", event := "") {
        str := Format("{}`n{}`n{}", "1.左键拖拽改变位置", "2.上下左右方向键微调位置", "3.左键双击或回车键关闭取色器，同时确定点位信息")
        MsgBox(str, GetLang("定位取色器操作说明"))
    }

    OnClickSureBtn(state, ctrl, event) {
        if (!this.CheckIfValid())
            return
        this.UpdateCommandStr()
        CommandStr := this.ui.Query("CommandStrCon")
        action := this.SureBtnAction
        this._CloseWindow()
        if (action != "")
            action(CommandStr)
    }

    TriggerMacro(state := "", ctrl := "", event := "") {
        if (!this.CheckIfValid())
            return
        this.UpdateCommandStr()
        OnTriggerSepcialItemMacro(this.ui.Query("CommandStrCon"))
    }

    SureCoord() {
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY
        if (IsObject(this.ui)) {
            this.ui.Update("PosXCon", "Text", mouseX)
            this.ui.Update("PosYCon", "Text", mouseY)
            this.UpdateCommandStr()
        }
    }
}
