#Requires AutoHotkey v2.0

class CMDTipGui {
    __new() {
        this.Gui := ""
        this.SureBtnAction := ""
        this.Data := ""
        this.isLoadParams := false
        this.ShowCount := 0
        this.ContentCon := ""
        this._wheelCb := ""
    }

    GetShowOptions() {
        ; -DPIScale：x/y/w/h 与 MouseGetPos、A_ScreenWidth 同为物理像素
        return Format("NoActivate x{} y{} w{} h{}", this.PosX, this.PosY, this.Width, this.Height)
    }

    ShowGui(CMDStr) {
        if (!this.isLoadParams) {
            this.isLoadParams := true
            this.LoadParams()
        }

        if (this.Gui == "") {
            this.AddGui()
            this.OnToggleMacroWorkState()
        }
        else {
            style := WinGetStyle(this.Gui.Hwnd)
            isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
            if (!isVisible)
                this.Gui.Show(this.GetShowOptions())
        }

        this.AddCMD(CMDStr)

        ; 订阅滚轮热键（仅首次或窗口重建时）
        if (!this._wheelCb) {
            this._wheelCb := ObjBindMethod(this, "_OnWheel")
            WinHotkey.SubscribeMouse("WheelUp", this._wheelCb)
            WinHotkey.SubscribeMouse("WheelDown", this._wheelCb)
        }
    }

    LoadParams() {
        this.PosX := Integer(MainSoftData.CMDPosX)
        this.PosY := Integer(MainSoftData.CMDPosY)
        this.Width := Integer(MainSoftData.CMDWidth)
        this.Height := Integer(MainSoftData.CMDHeight)
        this.BGColor := MainSoftData.CMDBGColor
        this.RunBGColor := MainSoftData.CMDRunBGColor
        ; 配置值为「背景透明度」：0=不透明，100=完全透明 → WinSetTransparent 相反
        this.Transparency := Integer((100 - MainSoftData.CMDTransparency) * 2.55)
        this.FontSize := MainSoftData.CMDFontSize
        this.FontColor := MainSoftData.CMDFontColor
    }

    ; 设置保存后刷新布局；重建窗口以确保 -DPIScale 生效
    ApplySettings() {
        this.LoadParams()
        this.isLoadParams := true
        if (this.Gui == "")
            return

        savedText := ""
        savedCount := this.ShowCount
        wasVisible := false
        try {
            savedText := this.ContentCon.Value
            style := WinGetStyle(this.Gui.Hwnd)
            wasVisible := (style & 0x10000000)
        }
        try this.Gui.Destroy()
        this.Gui := ""
        this.ContentCon := ""

        if (!wasVisible)
            return

        this.AddGui()
        this.ContentCon.Value := savedText
        this.ShowCount := savedCount
        this.OnToggleMacroWorkState()
    }

    ; 主题变更后刷新颜色（保留已有窗口与内容）
    ApplyThemeColors() {
        this.BGColor := MainSoftData.CMDBGColor
        this.RunBGColor := MainSoftData.CMDRunBGColor
        this.FontColor := MainSoftData.CMDFontColor
        if (this.Gui == "")
            return
        try {
            this.Gui.SetFont(Format("S{} W550 Q2 C{}", this.FontSize, this.FontColor), MainSoftData.FontType)
            this.OnToggleMacroWorkState()
        }
    }

    AddGui() {
        ; 与 ColorPanelGui / 录制浮层一致：禁用 DPIScale，直接使用物理屏幕坐标
        MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        this.Gui := MyGui
        MyGui.BackColor := this.BGColor
        MyGui.SetFont(Format("S{} W550 Q2 C{}", this.FontSize, this.FontColor), MainSoftData.FontType)
        MyGui.Opt("+E0x20")  ; 点击穿透
        WinSetTransparent(this.Transparency, MyGui)  ; 设置透明度

        ; 添加文本控件（宽度和高度匹配窗口，自动换行）
        this.ContentCon := MyGui.Add("Edit", Format("x0 y0 w{} h{}", this.Width, this.Height), "")
        this.ContentCon.Opt("Background" this.BGColor)

        MyGui.Show(this.GetShowOptions())
    }

    AddCMD(CMDStr) {
        this.ShowCount++
        if (this.ShowCount >= 100) {
            this.ShowCount--
            Pos := InStr(this.ContentCon.Value, "`n")
            this.ContentCon.Value := SubStr(this.ContentCon.Value, Pos + 1)
        }

        if (this.ContentCon.Value == "")
            this.ContentCon.Value := CMDStr
        else
            this.ContentCon.Value .= Format("`n{}", CMDStr)

        SendMessage(0xB6, 0, 10000, this.ContentCon)
    }

    Hide() {
        if (this.Gui == "")
            return

        this.ShowCount := 0
        this.ContentCon.Value := ""
        this.Gui.Hide()

        ; 取消订阅滚轮热键
        if (this._wheelCb) {
            WinHotkey.UnsubscribeMouse("WheelUp", this._wheelCb)
            WinHotkey.UnsubscribeMouse("WheelDown", this._wheelCb)
            this._wheelCb := ""
        }
    }

    _OnWheel(key, *) {
        this.OnScrollWheel(key)
    }

    OnToggleMacroWorkState() {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        ColorStr := MySoftData.IsMacroWorking ? this.RunBGColor : this.BGColor
        this.Gui.BackColor := ColorStr
        this.ContentCon.Opt("Background" ColorStr)
        this.ContentCon.Redraw()
    }

    OnScrollWheel(key) {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        ; 鼠标与窗口均为物理坐标
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY
        isOnWin := mouseX >= this.PosX && mouseY >= this.PosY
        isOnWin := isOnWin && mouseX <= this.PosX + this.Width && mouseY <= this.PosY + this.Height
        if (!isOnWin)
            return

        isDown := InStr(key, "Down", "Off") ? true : false
        ChangeValue := isDown ? 2 : -2
        SendMessage(0xB6, 0, ChangeValue, this.ContentCon) ; EM_LINESCROLL = 0xB6
    }
}
