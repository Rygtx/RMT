#Requires AutoHotkey v2.0

class CMDTipSettingGui {
    static instances := Map()
    static _opening := false
    static WidthSliderMax := 800
    static HeightSliderMax := 600

    __new() {
        this.ui := 0
        this.closed := false
        this._instanceKey := ""
        this._posX := 0
        this._posY := 0
        this._width := GetDefaultCMDTipWidth()
        this._height := 300
        this._fontSize := 12
        this._transparency := 50
        this._syncing := false
        this._hotkeysOn := false
        this._posAction := ObjBindMethod(this, "RefreshMousePos")
        this._f1Action := ObjBindMethod(this, "OnF1SetPos")
    }

    static ShowGui() {
        key := "global"

        if (CMDTipSettingGui.instances.Has(key)) {
            oldInst := CMDTipSettingGui.instances[key]
            hwnd := (IsObject(oldInst.ui) && oldInst.ui.HasProp("wpfHwnd")) ? oldInst.ui.wpfHwnd : 0
            if (!oldInst.closed && XAMLHost.CanReuseWindow(hwnd)) {
                try WinActivate("ahk_id " hwnd)
                return
            }
            try {
                if (!oldInst.closed && IsObject(oldInst.ui))
                    oldInst.Close()
            }
            CMDTipSettingGui.instances.Delete(key)
        }

        XAMLHost.EnsureDaemonHealthy()
        if (CMDTipSettingGui._opening)
            return
        CMDTipSettingGui._opening := true

        try {
            inst := CMDTipSettingGui()
            inst._instanceKey := key
            inst._BuildAndShow()
            CMDTipSettingGui.instances[key] := inst
        } finally {
            CMDTipSettingGui._opening := false
        }
    }

    _BuildAndShow() {
        this.closed := false

        title := GetLang("指令显示")
        titleHeight := "36"

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}")
        main.Rows(titleHeight, "*")

        ; 标题栏
        tb := main.Add("Border").Grid_Row(0).Background("{DynamicResource TitleBarColor}").Name("DragArea")
        tbInner := tb.Add("Grid")
        tbInner.Add("TextBlock").Text(title).Foreground("{DynamicResource TitleBarForeground}").FontSize(12).FontWeight("SemiBold").VerticalAlignment("Center").Margin("15,0,0,0")

        BtnGroup := tbInner.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Right")

        CloseBtnTemplate := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="{DynamicResource CloseBtnRadius}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="border" Property="Background" Value="#E0FF3333"/><Setter Property="Foreground" Value="White"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'

        closeBtn := BtnGroup.Add("Button").Name("BtnClosePanel").WindowChrome_IsHitTestVisibleInChrome("True").Width(40).Background("Transparent").Foreground("{DynamicResource TitleBarForeground}").BorderThickness(0)
        closeBtn.InjectResources(CloseBtnTemplate)
        closeBtn.Add("TextBlock").Text(Chr(0xE8BB)).FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets").FontSize(10).VerticalAlignment("Center").HorizontalAlignment("Center")

        ; 内容区
        body := main.Add("Border").Grid_Row(1).Background("{DynamicResource BgColor}")
        scrollViewer := body.Add("ScrollViewer").VerticalScrollBarVisibility("Auto").HorizontalScrollBarVisibility("Disabled")
        panel := scrollViewer.Add("StackPanel").Margin("30, 6, 30, 12")

        labelStyle := { fg: "{DynamicResource TextMain}", fs: 13, w: 90 }

        ; 实时鼠标坐标 + F1 填入位置
        rowMouse := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,0,0,0")
        rowMouse.Add("TextBlock").Name("MousePosCon")
            .Text(GetLang("屏幕坐标：0,0"))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(200)
        rowMouse.Add("TextBlock").Text(GetLang("F1:选取当前坐标"))
            .Foreground("{DynamicResource TextSub}").FontSize(12)
            .VerticalAlignment("Center").Margin("12,0,0,0")

        ; 右侧数值框与「显示宽度/高度」对齐：label(90)+slider边距(8)+slider(180)+边距(8)=286
        ; 左侧 X：label(90)+输入(60)=150 → Y 标签前间距 = 286-90-150 = 46
        valBoxW := 60
        yLabelGap := 46

        ; 显示位置 X / Y（文本输入）
        rowPos := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,10,0,0")
        rowPos.Add("TextBlock").Text(GetLang("显示位置X："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
        rowPos.Add("TextBox").Name("PosXCon")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
        rowPos.Add("TextBlock").Text(GetLang("显示位置Y："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
            .Margin(yLabelGap ",0,0,0")
        rowPos.Add("TextBox").Name("PosYCon")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
            .Margin("2,0,0,0")

        ; 显示宽度：滑块最大 800，文本框可输入更大值
        rowW := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,10,0,0")
        rowW.Add("TextBlock").Text(GetLang("显示宽度："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
        rowW.Add("Slider").Name("WidthCon")
            .Width(180).Height(28).Margin("8,0,8,0")
            .Minimum(80).Maximum(CMDTipSettingGui.WidthSliderMax).Value(GetDefaultCMDTipWidth())
            .IsSnapToTickEnabled("True").TickFrequency("5")
            .Tag("Throttle:50")
        rowW.Add("TextBox").Name("WidthValText")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
            .Margin("2,0,0,0")

        ; 显示高度：滑块最大 600，文本框可输入更大值
        rowH := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,10,0,0")
        rowH.Add("TextBlock").Text(GetLang("显示高度："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
        rowH.Add("Slider").Name("HeightCon")
            .Width(180).Height(28).Margin("8,0,8,0")
            .Minimum(40).Maximum(CMDTipSettingGui.HeightSliderMax).Value(300)
            .IsSnapToTickEnabled("True").TickFrequency("5")
            .Tag("Throttle:50")
        rowH.Add("TextBox").Name("HeightValText")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
            .Margin("2,0,0,0")

        ; 字体大小（输入框与宽高一致）
        rowF := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,10,0,0")
        rowF.Add("TextBlock").Text(GetLang("字体大小："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
        rowF.Add("Slider").Name("FontSizeCon")
            .Width(180).Height(28).Margin("8,0,8,0")
            .Minimum(8).Maximum(36).Value(12)
            .IsSnapToTickEnabled("True").TickFrequency("1")
            .Tag("Throttle:50")
        rowF.Add("TextBox").Name("FontSizeValText")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
            .Margin("2,0,0,0")

        ; 背景透明度（输入框与宽高一致）
        rowT := panel.Add("StackPanel").Orientation("Horizontal").Margin("0,10,0,0")
        rowT.Add("TextBlock").Text(GetLang("背景透明度："))
            .Foreground(labelStyle.fg).FontSize(labelStyle.fs)
            .VerticalAlignment("Center").Width(labelStyle.w)
        rowT.Add("Slider").Name("TransparencyCon")
            .Width(180).Height(28).Margin("8,0,8,0")
            .Minimum(0).Maximum(100).Value(50)
            .IsSnapToTickEnabled("True").TickFrequency("1")
            .Tag("Throttle:50")
        rowT.Add("TextBox").Name("TransparencyValText")
            .Width(valBoxW).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0")
            .TextAlignment("Center").FontSize(11)
            .Foreground("{DynamicResource InputText}")
            .Background("{DynamicResource InputBg}")
            .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
            .Margin("2,0,0,0")

        tip2 := panel.Add("TextBlock").Text(GetLang("透明度(0~100)：0不透明，100完全透明"))
            .Foreground("{DynamicResource TextSub}").FontSize(11).Margin("0,8,0,0")

        ; 底部按钮
        PrimaryBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionHoverBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'

        btnRow := panel.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Center").Margin("0,14,0,6")
        revertBtn := btnRow.Add("Button").Name("BtnRevert").Content(GetLang("恢复默认"))
            .Background("{DynamicResource ActionBg}").Foreground("{DynamicResource ActionText}").FontWeight("Bold")
            .BorderBrush("{DynamicResource ActionStroke}").BorderThickness("1")
            .FontSize(13).Cursor("Hand").Width(80).Height(32).Margin("0,0,16,0")
        revertBtn.InjectResources(PrimaryBtnStyle)
        okBtn := btnRow.Add("Button").Name("BtnConfirm").Content(GetLang("确定"))
            .Background("{DynamicResource ActionBg}").Foreground("{DynamicResource ActionText}").FontWeight("Bold")
            .BorderBrush("{DynamicResource ActionStroke}").BorderThickness("1")
            .FontSize(13).Cursor("Hand").Width(80).Height(32)
        okBtn.InjectResources(PrimaryBtnStyle)

        ; 编译 XAML
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", "")
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"', 'Title="' title '" ShowInTaskbar="False" Width="420" Height="330" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'CornerRadius="{DynamicResource WindowRadius}"', 'CornerRadius="{DynamicResource PanelRadius}"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '<CornerRadius x:Key="PanelRadius">8</CornerRadius>')

        ; 事件绑定
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))

        this.ui.Track("PosXCon")
        this.ui.Track("PosYCon")
        this.ui.Track("WidthCon")
        this.ui.Track("HeightCon")
        this.ui.Track("FontSizeCon")
        this.ui.Track("TransparencyCon")
        this.ui.Track("WidthValText")
        this.ui.Track("HeightValText")
        this.ui.Track("FontSizeValText")
        this.ui.Track("TransparencyValText")

        this.ui.OnEvent("PosXCon", "TextChanged", ObjBindMethod(this, "OnPosXTextChanged"))
        this.ui.OnEvent("PosYCon", "TextChanged", ObjBindMethod(this, "OnPosYTextChanged"))
        this.ui.OnEvent("WidthCon", "ValueChanged", ObjBindMethod(this, "OnWidthChanged"))
        this.ui.OnEvent("HeightCon", "ValueChanged", ObjBindMethod(this, "OnHeightChanged"))
        this.ui.OnEvent("FontSizeCon", "ValueChanged", ObjBindMethod(this, "OnFontSizeChanged"))
        this.ui.OnEvent("TransparencyCon", "ValueChanged", ObjBindMethod(this, "OnTransparencyChanged"))
        this.ui.OnEvent("WidthValText", "TextChanged", ObjBindMethod(this, "OnWidthTextChanged"))
        this.ui.OnEvent("HeightValText", "TextChanged", ObjBindMethod(this, "OnHeightTextChanged"))
        this.ui.OnEvent("FontSizeValText", "TextChanged", ObjBindMethod(this, "OnFontSizeTextChanged"))
        this.ui.OnEvent("TransparencyValText", "TextChanged", ObjBindMethod(this, "OnTransparencyTextChanged"))

        this.ui.OnEvent("BtnRevert", "Click", ObjBindMethod(this, "OnRevertClick"))
        this.ui.OnEvent("BtnConfirm", "Click", ObjBindMethod(this, "OnConfirmClick"))

        this.LoadInitValues()
        this.ApplyValuesToUI()
        this.ui.Show()
        this.ToggleFunc(true)

        loop 20 {
            if (this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
                try WinActivate("ahk_id " this.ui.wpfHwnd)
                break
            }
            Sleep(50)
        }
    }

    ToggleFunc(state) {
        if (state) {
            SetTimer(this._posAction, 100)
            try Hotkey("F1", this._f1Action, "On")
            this._hotkeysOn := true
        } else {
            SetTimer(this._posAction, 0)
            if (this._hotkeysOn) {
                try Hotkey("F1", this._f1Action, "Off")
                this._hotkeysOn := false
            }
        }
    }

    RefreshMousePos() {
        if (this.closed || !IsObject(this.ui))
            return
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        try this.ui.Update("MousePosCon", "Text", Format("{}{},{}", GetLang("屏幕坐标："), mouseX, mouseY))
    }

    OnF1SetPos(*) {
        if (this.closed || !IsObject(this.ui))
            return
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        this._posX := mouseX
        this._posY := mouseY
        this._syncing := true
        try {
            this.ui.Update("PosXCon", "Text", String(mouseX))
            this.ui.Update("PosYCon", "Text", String(mouseY))
        } finally {
            this._syncing := false
        }
    }

    OnWindowClosing(state, ctrl, event) {
        this.ToggleFunc(false)
        this.closed := true
        CMDTipSettingGui._opening := false
        if (this._instanceKey != "" && CMDTipSettingGui.instances.Has(this._instanceKey))
            CMDTipSettingGui.instances.Delete(this._instanceKey)
        this.ui := ""
        try {
            if (!XAMLHost.IsDaemonAlive())
                XAMLHost.ResetDaemon()
        }
    }

    OnWindowLoad(state, ctrl, event) {
        try {
            themeName := MainSoftData.HasProp("Theme") ? MainSoftData.Theme : "RMT_Light"
            ApplyXamlTheme(this.ui, themeName)
            this.ApplyValuesToUI()
        } finally {
            this.ui.Update("Window", "Opacity", "1")
        }
    }

    LoadInitValues() {
        this._posX := Integer(MainSoftData.CMDPosX)
        this._posY := Integer(MainSoftData.CMDPosY)
        this._width := Max(80, Integer(MainSoftData.CMDWidth))
        this._height := Max(40, Integer(MainSoftData.CMDHeight))
        this._fontSize := Max(8, Min(36, Integer(MainSoftData.CMDFontSize)))
        this._transparency := Max(0, Min(100, Integer(MainSoftData.CMDTransparency)))
    }

    ApplyValuesToUI() {
        if (!IsObject(this.ui))
            return
        this._syncing := true
        try {
            this.ui.Update("PosXCon", "Text", String(this._posX))
            this.ui.Update("PosYCon", "Text", String(this._posY))
            ; 滑块只到默认上限；文本框显示真实值（可大于上限）
            this.ui.Update("WidthCon", "Value", String(Min(this._width, CMDTipSettingGui.WidthSliderMax)))
            this.ui.Update("HeightCon", "Value", String(Min(this._height, CMDTipSettingGui.HeightSliderMax)))
            this.ui.Update("WidthValText", "Text", String(this._width))
            this.ui.Update("HeightValText", "Text", String(this._height))
            this.ui.Update("FontSizeCon", "Value", String(this._fontSize))
            this.ui.Update("FontSizeValText", "Text", String(this._fontSize))
            this.ui.Update("TransparencyCon", "Value", String(this._transparency))
            this.ui.Update("TransparencyValText", "Text", String(this._transparency))
        } finally {
            this._syncing := false
        }
    }

    _ParseInt(valStr) {
        if (valStr == "" || !IsNumber(valStr))
            return ""
        return Integer(Round(Number(valStr)))
    }

    OnPosXTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("PosXCon") ? state["PosXCon"] : "")
        if (val == "")
            return
        this._posX := val
    }

    OnPosYTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("PosYCon") ? state["PosYCon"] : "")
        if (val == "")
            return
        this._posY := val
    }

    OnWidthChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("WidthCon") ? state["WidthCon"] : "")
        if (val == "")
            return
        this._width := val
        this._syncing := true
        try this.ui.Update("WidthValText", "Text", String(this._width))
        finally this._syncing := false
    }

    OnHeightChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("HeightCon") ? state["HeightCon"] : "")
        if (val == "")
            return
        this._height := val
        this._syncing := true
        try this.ui.Update("HeightValText", "Text", String(this._height))
        finally this._syncing := false
    }

    OnFontSizeChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("FontSizeCon") ? state["FontSizeCon"] : "")
        if (val == "")
            return
        this._fontSize := val
        this._syncing := true
        try this.ui.Update("FontSizeValText", "Text", String(this._fontSize))
        finally this._syncing := false
    }

    OnTransparencyChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("TransparencyCon") ? state["TransparencyCon"] : "")
        if (val == "")
            return
        this._transparency := val
        this._syncing := true
        try this.ui.Update("TransparencyValText", "Text", String(this._transparency))
        finally this._syncing := false
    }

    OnWidthTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("WidthValText") ? state["WidthValText"] : "")
        if (val == "")
            return
        val := Max(80, val)
        if (val == this._width)
            return
        this._width := val
        this._syncing := true
        try this.ui.Update("WidthCon", "Value", String(Min(val, CMDTipSettingGui.WidthSliderMax)))
        finally this._syncing := false
    }

    OnHeightTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("HeightValText") ? state["HeightValText"] : "")
        if (val == "")
            return
        val := Max(40, val)
        if (val == this._height)
            return
        this._height := val
        this._syncing := true
        try this.ui.Update("HeightCon", "Value", String(Min(val, CMDTipSettingGui.HeightSliderMax)))
        finally this._syncing := false
    }

    OnFontSizeTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("FontSizeValText") ? state["FontSizeValText"] : "")
        if (val == "")
            return
        val := Max(8, Min(36, val))
        if (val != this._fontSize) {
            this._fontSize := val
            this._syncing := true
            try this.ui.Update("FontSizeCon", "Value", String(val))
            finally this._syncing := false
        }
    }

    OnTransparencyTextChanged(state, ctrl, event) {
        if (this._syncing)
            return
        val := this._ParseInt(state.Has("TransparencyValText") ? state["TransparencyValText"] : "")
        if (val == "")
            return
        val := Max(0, Min(100, val))
        if (val != this._transparency) {
            this._transparency := val
            this._syncing := true
            try this.ui.Update("TransparencyCon", "Value", String(val))
            finally this._syncing := false
        }
    }

    OnRevertClick(state, ctrl, event) {
        ; 默认：宽按 DPI 缩放，高 300，X = 屏幕宽 - 显示宽
        this._width := GetDefaultCMDTipWidth()
        this._height := 300
        this._posX := A_ScreenWidth - this._width
        this._posY := 0
        this._fontSize := 12
        this._transparency := 50
        this.ApplyValuesToUI()
    }

    OnConfirmClick(state, ctrl, event) {
        this.SaveData()
        this.ui.Update("Window", "Close", "")
    }

    OnCancelClick(state, ctrl, event) {
        this.ui.Update("Window", "Close", "")
    }

    Close() {
        this.ToggleFunc(false)
        this.closed := true
        if IsObject(this.ui) {
            try this.ui.Update("Window", "Close", "")
            this.ui := ""
        }
    }

    SaveData() {
        global IniFile, IniSection

        MainSoftData.CMDPosX := this._posX
        MainSoftData.CMDPosY := this._posY
        MainSoftData.CMDWidth := this._width
        MainSoftData.CMDHeight := this._height
        MainSoftData.CMDFontSize := this._fontSize
        MainSoftData.CMDTransparency := this._transparency

        IniWrite(MainSoftData.CMDPosX, IniFile, IniSection, "CMDPosX")
        IniWrite(MainSoftData.CMDPosY, IniFile, IniSection, "CMDPosY")
        IniWrite(MainSoftData.CMDWidth, IniFile, IniSection, "CMDWidth")
        IniWrite(MainSoftData.CMDHeight, IniFile, IniSection, "CMDHeight")
        IniWrite(MainSoftData.CMDFontSize, IniFile, IniSection, "CMDFontSize")
        IniWrite(MainSoftData.CMDTransparency, IniFile, IniSection, "CMDTransparency")

        if (IsSet(MyCMDTipGui) && IsObject(MyCMDTipGui))
            MyCMDTipGui.ApplySettings()
    }
}
