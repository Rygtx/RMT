#Requires AutoHotkey v2.0

; =====================================================================
; RMT指令编辑器 —— XAML 迁移版（独立实现）
; 公开接口保持：ShowGui(cmd) / SureBtnAction / OwnerHwnd / ParentTile
; =====================================================================

class RMTCMDGui {
    __new() {
        this.ParentTile := ""
        this.ui := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this._closed := true
        this._batch := []
        this._batching := false
        this.CategoriesArr := [GetLang("全部"), GetLang("图文"), GetLang("输入控制"),
        GetLang("宏控制"), GetLang("调试"), GetLang("软件自身")]
        this.CategoriesMap := Map(
            GetLang("图文"), [
                GetLang("截图"),
                GetLang("截图提取文本"),
                GetLang("自由贴")
            ],
            GetLang("输入控制"), [
                GetLang("启用鼠标"),
                GetLang("启用键盘"),
                GetLang("启用键鼠"),
                GetLang("禁用鼠标"),
                GetLang("禁用键盘"),
                GetLang("禁用键鼠"),
                GetLang("启用鼠标加速"),
                GetLang("禁用鼠标加速")
            ],
            GetLang("宏控制"), [
                GetLang("显示菜单"),
                GetLang("关闭菜单"),
                GetLang("暂停所有宏"),
                GetLang("恢复所有宏"),
                GetLang("终止所有宏")
            ],
            GetLang("调试"), [
                GetLang("开启变量监视"),
                GetLang("关闭变量监视"),
                GetLang("开启指令显示"),
                GetLang("关闭指令显示"),
            ],
            GetLang("软件自身"), [
                GetLang("关闭软件"),
                GetLang("休眠"),
                GetLang("重载")
            ],
        )
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
        this.OnCmdChange()
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
        title := this.ParentTile GetLang("RMT指令编辑器")
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
        body := main.Add("Grid").Grid_Row(1).Margin("15,14")
        body.Rows("40", "40", "40", "*")
        body.Cols("80", "*")

        body.Add("TextBlock").Grid_Row(0).Grid_Column(0).Text(GetLang("类别：")).VerticalAlignment("Center")
        cat := body.Add("ComboBox").Grid_Row(0).Grid_Column(1).Name("CategoryCombo").Width(180).Height(26).MinHeight(26).HorizontalAlignment("Left")
        for c in this.CategoriesArr
            cat.Add("ComboBoxItem").Content(c)

        body.Add("TextBlock").Grid_Row(1).Grid_Column(0).Text(GetLang("指令：")).VerticalAlignment("Center")
        body.Add("ComboBox").Grid_Row(1).Grid_Column(1).Name("CmdTypeCombo").Width(180).Height(26).MinHeight(26).HorizontalAlignment("Left")

        menuRow := body.Add("StackPanel").Name("MenuRow").Grid_Row(2).Grid_Column(1).Orientation("Horizontal").VerticalAlignment("Center")
        menuRow.Add("TextBlock").Text(GetLang("菜单序号：")).VerticalAlignment("Center")
        menuRow.Add("ComboBox").Name("MenuDLCombo").Width(120).Height(26).MinHeight(26).Margin("4,0,0,0")

        btnRow := body.Add("StackPanel").Grid_Row(3).Grid_ColumnSpan(2).Orientation("Horizontal").HorizontalAlignment("Center").VerticalAlignment("Center")
        btnRow.Add("Button").Name("BtnOk").Content(GetLang("确定")).Width(100).Height(36).MinHeight(36)

        ; === 创建 XAMLHost ===
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", this.OwnerHwnd)
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"', 'Title="' this._EscapeXml(title) '" Width="310" Height="210" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, 'FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"', 'FontFamily="' MainSoftData.FontType '"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; === 事件 ===
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))
        this.ui.OnEvent("CategoryCombo", "SelectionChanged", ObjBindMethod(this, "OnTypeChane"))
        this.ui.OnEvent("CmdTypeCombo", "SelectionChanged", ObjBindMethod(this, "OnCmdChange"))
        this.ui.OnEvent("BtnOk", "Click", ObjBindMethod(this, "OnSureBtnClick"))

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

    _SetDDL(comboName, items, text) {
        if (!IsObject(this.ui))
            return
        this._ComboPush(comboName, "ClearItems", "")
        for it in items {
            if (it == "")
                continue
            this._ComboPush(comboName, "AddItem", it)
        }
        for i, it in items {
            if (it == text) {
                this._ComboPush(comboName, "SelectedIndex", String(i - 1))
                return
            }
        }
        this._ComboPush(comboName, "SelectedIndex", "0")
    }

    Init(cmd) {
        ; 新格式: RMT指令_类别_指令 或 RMT指令_类别_指令_序号
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        if (cmdArr.Length >= 4) {
            cmdCategory := cmdArr[2]
            cmdStr := cmdArr[3]
            menuDLIndex := cmdStr == GetLang("显示菜单") && cmdArr.Length >= 5 ? Integer(cmdArr[4]) : 1
        } else if (cmdArr.Length >= 3) {
            cmdCategory := cmdArr[2]
            cmdStr := cmdArr[3]
            menuDLIndex := 1
        } else {
            cmdCategory := GetLang("全部")
            cmdStr := GetLang("截图")
            menuDLIndex := 1
        }

        this.InitCategoriesMap()
        Category := cmdCategory
        CmdStrArr := this.CategoriesMap[Category]

        this._SetDDL("CategoryCombo", this.CategoriesArr, Category)
        this._SetDDL("CmdTypeCombo", CmdStrArr, cmdStr)

        FoldInfo := MySoftData.TableInfo[3].FoldInfo
        DropDownArr := []
        loop FoldInfo.RemarkArr.Length {
            DropDownArr.Push(A_Index ". " FoldInfo.RemarkArr[A_Index])
        }
        this.ui.Update("MenuDLCombo", "ClearItems", "")
        for it in DropDownArr
            this.ui.Update("MenuDLCombo", "AddItem", it)
        this.ui.Update("MenuDLCombo", "SelectedIndex", String(menuDLIndex - 1))
    }

    OnTypeChane(state := "", ctrl := "", event := "") {
        if (!IsObject(this.ui))
            return
        Category := this.ui.Query("CategoryCombo")
        CmdStrArr := this.CategoriesMap[Category]
        this._SetDDL("CmdTypeCombo", CmdStrArr, CmdStrArr.Length >= 1 ? CmdStrArr[1] : "")
        this.OnCmdChange()
    }

    ; 操作类型 DropDownList Change 处理
    OnCmdChange(state := "", ctrl := "", event := "") {
        if (!IsObject(this.ui))
            return
        CmdStr := this.ui.Query("CmdTypeCombo")
        IsShowMenuDL := CmdStr == GetLang("显示菜单")
        this.ui.Update("MenuRow", "Visibility", IsShowMenuDL ? "Visible" : "Collapsed")
    }

    OnSureBtnClick(state, ctrl, event) {
        if (!this.CheckIfValid())
            return
        CommandStr := this.GetCommandStr()
        this.SureBtnAction.Call(CommandStr)
        this._CloseWindow()
    }

    CheckIfValid() {
        cmd := this.ui.Query("CmdTypeCombo")
        if (cmd == GetLang("禁用键鼠") || cmd == GetLang("禁用鼠标") || cmd == GetLang("禁用键盘")) {
            if (cmd == GetLang("禁用鼠标"))
                tipBody := GetLang("此操作将 立即禁用鼠标输入，您将无法通过鼠标操作计算机！")
            else if (cmd == GetLang("禁用键盘"))
                tipBody := GetLang("此操作将 立即禁用键盘输入，您将无法通过键盘操作计算机！")
            else
                tipBody := GetLang("此操作将 立即禁用键盘和鼠标输入，您将无法通过键鼠操作计算机！")
            tipStr := Format("{}`n{}`n{}`n{}`n{}", tipBody, GetLang("重要须知："), GetLang(
                "- 以管理员身份运行本软件，否则该指令无效。"), GetLang("- 务必后续执行对应的启用指令，否则输入设备将保持禁用状态！"), GetLang("是否确认禁用？"))
            title := cmd == GetLang("禁用鼠标") ? GetLang("禁用鼠标（需管理员权限）")
                : (cmd == GetLang("禁用键盘") ? GetLang("禁用键盘（需管理员权限）") : GetLang("禁用键鼠（需管理员权限）"))
            if (MsgBox(tipStr, title, "4") == "No")
                return false
        }

        if (cmd == GetLang("启用键鼠") || cmd == GetLang("启用鼠标") || cmd == GetLang("启用键盘")) {
            title := cmd == GetLang("启用鼠标") ? GetLang("启用鼠标（需管理员权限）")
                : (cmd == GetLang("启用键盘") ? GetLang("启用键盘（需管理员权限）") : GetLang("启用键鼠（需管理员权限）"))
            MsgBox(GetLang("- 必须 以管理员身份运行本软件，否则该指令无效。"), title)
        }
        return true
    }

    GetCommandStr() {
        ; CMD格式: RMT指令_类别_指令 或 RMT指令_类别_指令_序号
        CommandStr := Format("{}_{}_{}", GetLang("RMT指令"), this.ui.Query("CategoryCombo"), this.ui.Query("CmdTypeCombo"))
        if (this.ui.Query("CmdTypeCombo") == GetLang("显示菜单")) {
            idx := Integer(this.ui.Query("MenuDLCombo>SelectedIndex")) + 1
            CommandStr .= "_" idx
        }
        return CommandStr
    }

    InitCategoriesMap() {
        if (this.CategoriesMap.Has(GetLang("全部")))
            return

        AllCmdArr := []
        for Index, Value in this.CategoriesArr {
            if (this.CategoriesMap.Has(Value)) {
                CmdStrArr := this.CategoriesMap[Value]
                AllCmdArr.Push(CmdStrArr*)
            }
        }
        this.CategoriesMap.Set(GetLang("全部"), AllCmdArr)
    }
}
