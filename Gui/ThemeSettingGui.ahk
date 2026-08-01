#Requires AutoHotkey v2.0

class ThemeSettingGui {
    static instances := Map()
    static _opening := false

    __new() {
        this.ui := 0
        this.closed := false
        this._instanceKey := ""
        this._themeKey := AppThemeUtil.DefaultThemeKey
        this._colors := Map()
        this._applyingTheme := false
    }

    static ShowGui() {
        key := "global"
        if (ThemeSettingGui.instances.Has(key)) {
            oldInst := ThemeSettingGui.instances[key]
            if (!oldInst.closed && IsObject(oldInst.ui) && oldInst.ui.wpfHwnd) {
                try WinActivate("ahk_id " oldInst.ui.wpfHwnd)
                return
            }
            if (!oldInst.closed)
                oldInst.Close()
            ThemeSettingGui.instances.Delete(key)
        }

        if (ThemeSettingGui._opening)
            return
        ThemeSettingGui._opening := true
        try {
            inst := ThemeSettingGui()
            inst._instanceKey := key
            inst._BuildAndShow()
            ThemeSettingGui.instances[key] := inst
        } finally {
            ThemeSettingGui._opening := false
        }
    }

    _BuildAndShow() {
        this.closed := false
        title := GetLang("主题选项")
        titleHeight := "36"

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}")
        main.Rows(titleHeight, "*")

        tb := main.Add("Border").Grid_Row(0).Background("Transparent").Name("DragArea")
        tbInner := tb.Add("Grid")
        tbInner.Add("TextBlock").Text(title).Foreground("{DynamicResource TextMain}").FontSize(12).FontWeight("SemiBold").VerticalAlignment("Center").Margin("15,0,0,0")

        BtnGroup := tbInner.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Right")
        CloseBtnTemplate := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="{DynamicResource CloseBtnRadius}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="border" Property="Background" Value="#E0FF3333"/><Setter Property="Foreground" Value="White"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        closeBtn := BtnGroup.Add("Button").Name("BtnClosePanel").WindowChrome_IsHitTestVisibleInChrome("True").Width(40).Background("Transparent").Foreground("{DynamicResource TextMain}").BorderThickness(0)
        closeBtn.InjectResources(CloseBtnTemplate)
        closeBtn.Add("TextBlock").Text(Chr(0xE8BB)).FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets").FontSize(10).VerticalAlignment("Center").HorizontalAlignment("Center")

        body := main.Add("Border").Grid_Row(1).Background("{DynamicResource ControlBg}")
        scrollViewer := body.Add("ScrollViewer").VerticalScrollBarVisibility("Auto").HorizontalScrollBarVisibility("Disabled")
        panel := scrollViewer.Add("StackPanel").Margin("14, 6, 14, 10")

        ; 颜色值用 Border+TextBlock 显示，避免 WPF TextBox 默认 MinHeight 导致高度调不动
        this._colorUi := {
            labelFg: "{DynamicResource TextMain}", labelFs: 12, labelW: 68,
            boxW: 100, boxH: 24, boxFs: 13,
            previewW: 24, previewH: 24,
            col2Margin: 38
        }

        ; ===== 顶部：主题下拉 =====
        themeGroup := panel.Add("GroupBox").Header(GetLang("主题预设")).Margin("0,0,0,0")
        themeInner := themeGroup.Add("StackPanel").Margin("12, 8")
        themeRow := themeInner.Add("StackPanel").Orientation("Horizontal").Margin("0,2,0,0")
        themeRow.Add("TextBlock").Text(GetLang("选择主题") "：")
            .Foreground(this._colorUi.labelFg).FontSize(this._colorUi.labelFs)
            .VerticalAlignment("Center").Width(this._colorUi.labelW)
        themeCombo := themeRow.Add("ComboBox").Name("ThemeCombo").Width(180).Height(28).Margin("6,0,0,0")
        for item in AppThemeUtil.Presets
            themeCombo.Add("ComboBoxItem").Content(GetLang(item.Name))
        themeCombo.Add("ComboBoxItem").Content(GetLang("自定义"))

        ; ===== 下方：可滚动颜色组（分组与行布局由 ColorDefs 自动生成，便于后续扩展）=====
        groups := AppThemeUtil.GetGroupNames()
        for gi, groupName in groups {
            groupBox := panel.Add("GroupBox").Header(GetLang(groupName)).Margin(gi == 1 ? "0,10,0,0" : "0,8,0,0")
            inner := groupBox.Add("StackPanel").Margin("12, 6")
            rowKeys := this._GetGroupRowKeys(groupName)
            for ri, keys in rowKeys {
                row := inner.Add("StackPanel").Orientation("Horizontal").Margin(ri == 1 ? "0,4,0,0" : "0,6,0,0")
                this._AddColorItem(row, this._FindColorDef(keys[1]), 0)
                if (keys.Length >= 2)
                    this._AddColorItem(row, this._FindColorDef(keys[2]), this._colorUi.col2Margin)
            }
        }

        PrimaryBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.85"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        btnRow := panel.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Center").Margin("0,18,0,10")
        okBtn := btnRow.Add("Button").Name("BtnConfirm").Content(GetLang("确定")).Background("{DynamicResource Accent}").Foreground("White").FontWeight("Bold").BorderThickness(0).FontSize(13).Cursor("Hand").Width(80).Height(32)
        okBtn.InjectResources(PrimaryBtnStyle)

        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", "")
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"', 'Title="' title '" ShowInTaskbar="False" Width="520" Height="520" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'CornerRadius="{DynamicResource WindowRadius}"', 'CornerRadius="{DynamicResource PanelRadius}"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '<CornerRadius x:Key="PanelRadius">8</CornerRadius>')

        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))
        this.ui.Track("ThemeCombo")
        this.ui.OnEvent("ThemeCombo", "SelectionChanged", ObjBindMethod(this, "OnThemeSelectionChanged"))
        this.ui.OnEvent("BtnConfirm", "Click", ObjBindMethod(this, "OnConfirmClick"))

        for def in AppThemeUtil.ColorDefs
            this.ui.OnEvent(def.Key "_Preview", "MouseLeftButtonDown", ObjBindMethod(this, "OnPickColor", def.Key, def.Label))

        ; Show 前入队配置，LoadedHwnd 时立即刷入，避免先闪默认值
        this.LoadInitValues()
        this.ApplyValuesToUI()
        this.ui.Show()

        loop 20 {
            if (this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
                try WinActivate("ahk_id " this.ui.wpfHwnd)
                break
            }
            Sleep(50)
        }
    }

    ; 按 ColorDefs 顺序收集该组 Key，两两一行（新增颜色项无需改此处）
    _GetGroupRowKeys(groupName) {
        keys := []
        for def in AppThemeUtil.ColorDefs {
            if (def.Group == groupName)
                keys.Push(def.Key)
        }
        rows := []
        i := 1
        while (i <= keys.Length) {
            if (i + 1 <= keys.Length) {
                rows.Push([keys[i], keys[i + 1]])
                i += 2
            } else {
                rows.Push([keys[i]])
                i += 1
            }
        }
        return rows
    }

    _FindColorDef(key) {
        for def in AppThemeUtil.ColorDefs {
            if (def.Key == key)
                return def
        }
        return {Key: key, Group: "", Label: key}
    }

    _AddColorItem(row, def, leftMargin) {
        ui := this._colorUi
        item := row.Add("StackPanel").Orientation("Horizontal").Margin(leftMargin "," 0 ",0,0")
            .VerticalAlignment("Center")
        item.Add("TextBlock").Text(GetLang(def.Label) "：")
            .Foreground(ui.labelFg).FontSize(ui.labelFs)
            .VerticalAlignment("Center").Width(ui.labelW)
        ; 只读色值展示：Border + TextBlock，高度可控
        box := item.Add("Border").Width(ui.boxW).Height(ui.boxH).CornerRadius("3")
            .Background("{DynamicResource ControlBg}")
            .BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1")
            .VerticalAlignment("Center")
        box.Add("TextBlock").Name(def.Key "_Text")
            .Text("#FF000000").FontSize(ui.boxFs)
            .Foreground("{DynamicResource TextSub}")
            .HorizontalAlignment("Center").VerticalAlignment("Center")
        item.Add("Border").Name(def.Key "_Preview")
            .Width(ui.previewW).Height(ui.previewH).CornerRadius("3").Margin("6,0,0,0")
            .BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1")
            .Background("#FF000000").Cursor("Hand").VerticalAlignment("Center")
    }

    LoadInitValues() {
        this._themeKey := MainSoftData.HasProp("AppTheme") ? MainSoftData.AppTheme : AppThemeUtil.DefaultThemeKey
        if (this._themeKey == "" || !AppThemeUtil.IsPresetKey(this._themeKey))
            this._themeKey := AppThemeUtil.DefaultThemeKey
        ; CloneColorMap 会以暖阳补齐缺失 Key，兼容版本升级后的自定义主题
        if (IsObject(MainSoftData.ThemeColors))
            this._colors := AppThemeUtil.CloneColorMap(MainSoftData.ThemeColors)
        else
            this._colors := AppThemeUtil.NewColorMapFromPreset(AppThemeUtil.FindPreset(this._themeKey))
    }

    ApplyValuesToUI() {
        this._applyingTheme := true
        try {
            themeIdx := AppThemeUtil.Presets.Length  ; 自定义
            for i, item in AppThemeUtil.Presets {
                if (item.Key == this._themeKey) {
                    themeIdx := i - 1
                    break
                }
            }
            this.ui.Update("ThemeCombo", "SelectedIndex", String(themeIdx))
            this.RefreshColorRows()
        } finally {
            this._applyingTheme := false
        }
    }

    RefreshColorRows() {
        for def in AppThemeUtil.ColorDefs {
            color := AppThemeUtil.ResolveColor(this._colors, def.Key)
            this.ui.Update(def.Key "_Preview", "Background", color)
            this.ui.Update(def.Key "_Text", "Text", color)
        }
    }

    OnThemeSelectionChanged(state, ctrl, event) {
        if (this._applyingTheme)
            return
        selText := state.Has("ThemeCombo") ? state["ThemeCombo"] : ""
        if (selText == "" || selText == GetLang("自定义")) {
            this._themeKey := "Custom"
            return
        }
        preset := AppThemeUtil.FindPresetByName(selText)
        if (!IsObject(preset))
            return
        this._themeKey := preset.Key
        this._colors := AppThemeUtil.NewColorMapFromPreset(preset)
        this.RefreshColorRows()
    }

    OnPickColor(colorKey, labelKey, state, ctrl, event) {
        cur := AppThemeUtil.ResolveColor(this._colors, colorKey)
        result := XColorPicker.Show({
            Title: GetLang(labelKey),
            DefaultColor: cur,
            Owner: this.ui.wpfHwnd,
            Modal: true
        })
        if (result.Status != "OK")
            return
        this._colors[colorKey] := result.Color
        this.ui.Update(colorKey "_Preview", "Background", result.Color)
        this.ui.Update(colorKey "_Text", "Text", result.Color)
        this._themeKey := "Custom"
        this._applyingTheme := true
        try this.ui.Update("ThemeCombo", "SelectedIndex", String(AppThemeUtil.Presets.Length))
        finally this._applyingTheme := false
    }

    OnConfirmClick(state, ctrl, event) {
        this.SaveData()
        this.ui.Update("Window", "Close", "")
    }

    OnCancelClick(state, ctrl, event) {
        this.ui.Update("Window", "Close", "")
    }

    SaveData() {
        if (this._themeKey == "" || !AppThemeUtil.IsPresetKey(this._themeKey))
            this._themeKey := AppThemeUtil.DefaultThemeKey
        MainSoftData.AppTheme := this._themeKey
        ; 补齐缺失项后再落盘，保证后续新增 ColorDefs 写入暖阳默认色
        MainSoftData.ThemeColors := AppThemeUtil.CloneColorMap(this._colors)
        AppThemeUtil.ApplyToRuntime(MainSoftData.ThemeColors)
        AppThemeUtil.SaveToIni()
        ; 浮窗 / 指令显示已打开时刷新样式
        if (IsSet(MyUIMacroGui) && IsObject(MyUIMacroGui))
            MyUIMacroGui.RefreshPanels()
        if (IsSet(MyCMDTipGui) && IsObject(MyCMDTipGui))
            MyCMDTipGui.ApplyThemeColors()
    }

    OnWindowClosing(state, ctrl, event) {
        this.closed := true
        ThemeSettingGui._opening := false
        if (this._instanceKey != "" && ThemeSettingGui.instances.Has(this._instanceKey))
            ThemeSettingGui.instances.Delete(this._instanceKey)
        this.ui := ""
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

    Close() {
        this.closed := true
        if IsObject(this.ui) {
            try this.ui.Update("Window", "Close", "")
            this.ui := ""
        }
    }
}
