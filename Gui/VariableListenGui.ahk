#Requires AutoHotkey v2.0

class VariableListenGui {
    __new() {
        this.Gui := ""
        this.TopCon := ""
        this.LVCon := ""
    }

    ShowGui() {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
        IniWrite(true, IniFile, IniSection, "IsOpenListenVar")
        this.Refresh()
        this.LVCon.Focus()  ; 🔥 强制获得焦点，解决第一次双击无效问题
    }

    Refresh() {
        if (!IsObject(this.Gui))
            return

        style := WinGetStyle(this.Gui)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        this.LVCon.Opt("-Redraw")
        count := this.LVCon.GetCount()
        LVKeys := Map()
        loop count {
            row := count - A_Index + 1
            key := this.LVCon.GetText(row, 1)
            value := this.LVCon.GetText(row, 2)
            if !MySoftData.VariableMap.Has(key)
                this.LVCon.Delete(row)
            else if (String(MySoftData.VariableMap[key]) != value)
                this.LVCon.Delete(row)
            else
                LVKeys[key] := True
        }

        ; 3) 添加 Map 中有但 LV 没有的项
        for key, value in MySoftData.VariableMap {
            if !LVKeys.Has(key) {
                this.LVCon.Add(, key, value)
            }
        }
        this.LVCon.Opt("+Redraw")
    }

    AddGui() {
        MyGui := Gui(, GetLang("变量监视器"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.TopCon := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("窗口置顶"))
        this.TopCon.OnEvent("Click", this.OnTogTop.Bind(this))

        PosX := 10
        PosY += 30
        this.LVCon := MyGui.Add("ListView", Format("x{} y{} w350 h250 -LV0x10 NoSort Sort", PosX, PosY), GetLangArr([
            "变量名", "变量值"]))
        ; 设置列宽（单位：px）
        this.LVCon.ModifyCol(1, 120) ; 第一列宽度
        this.LVCon.ModifyCol(2, 205) ; 自动填充剩余宽度
        this.LVCon.OnEvent("DoubleClick", this.OnDoubleClick.Bind(this))

        MyGui.OnEvent("Close", this.OnClose.Bind(this))
        MyGui.Show(Format("w{} h{}", 370, 300))
    }

    OnClose(*) {
        if (MySoftData.MacroEditGui.Gui != "") {
            style := WinGetStyle(MySoftData.MacroEditGui.Gui)
            isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
            if (isVisible) {
                MySoftData.MacroEditGui.ToolMenu.Uncheck(GetLang("变量监视"))
            }
        }
        IniWrite(false, IniFile, IniSection, "IsOpenListenVar")
    }

    OnTogTop(*) {
        state := this.topCon.Value
        if (state) {
            this.Gui.Opt("+AlwaysOnTop")
        }
        else {
            this.Gui.Opt("-AlwaysOnTop")
        }
    }

    OnDoubleClick(LV, RowNumber, *) {
        varName := this.LVCon.GetText(RowNumber, 1)
        curValue := this.LVCon.GetText(RowNumber, 2)
        Title := Format("{}:{}      {}:{}", GetLang("变量名"), varName, GetLang("变量值"), curValue)
        Title .= "`n" GetLang("请输入新的变量值：")
        newValue := InputBox(Title, "修改", "w300 h110")

        ; 检查用户是否取消输入
        if newValue.Result = "Cancel"
            return
        if (newValue.Value == "") {
            DelGlobalVariable([varName])
            return
        }
        SetGlobalVariable([varName], [newValue.Value], false)
    }
}
