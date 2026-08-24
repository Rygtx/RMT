#Requires AutoHotkey v2.0
#Include MacroEditGui.ahk

class CompareProEditItemGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this.RemarkCon := ""
        this.FocusCon := ""
        this.MacroGui := ""

        this.IsSubMacroEdit := false
        this.Data := ""
        this.CondiNumber := 1

        this.EditType := 1  ;1正常分支 2兜底分支
        this.ToggleConArr := []
        this.NameConArr := []
        this.CompareTypeConArr := []
        this.VariableConArr := []
        this.LogicalTypeCon := ""
        this.MacroCon := ""
    }

    MacroEditShowGui(CommandStr, CondiNumber) {
        paramArr := StrSplit(CommandStr, "_")
        Data := GetMacroCMDData(paramArr[1])
        this.Data := Data
        this.CondiNumber := CondiNumber
        EditType := CondiNumber <= Data.VariNameArr.Length ? 1 : 2
        if (EditType == 2) {
            this.ShowGui(EditType, [[], [], []], GetLang("且"), Data.DefaultMacro, Data.DefaultControlType)
            return
        }

        ; 与「如果」一致：直接从 Data 取条件（中文 key + 数字比较类型）
        DataArr := [Data.VariNameArr[CondiNumber], Data.CompareTypeArr[CondiNumber], Data.VariableArr[CondiNumber]]
        logicStr := Data.LogicTypeArr[CondiNumber] == 1 ? GetLang("且") : GetLang("或")
        macro := Data.MacroArr[CondiNumber]
        controlType := Data.ControlTypeArr[CondiNumber]
        this.ShowGui(EditType, DataArr, logicStr, macro, controlType)
    }

    ShowGui(EditType, DataArr, logicStr, macro, controlType) {
        if (this.Gui != "") {
            if (this.OwnerHwnd != "") {
                this.Gui.Opt("+Owner" this.OwnerHwnd)
            }
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
            }
        }

        this.Init(EditType, DataArr, logicStr, macro, controlType)
        this.OnRefresh()
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("如果Pro分支编辑器"))
        this.Gui := MyGui
        if (this.OwnerHwnd != "") {
            MyGui.Opt("+Owner" this.OwnerHwnd)
        }
        MyGui.SetFont("S10 W550 Q2", MainSoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 80, 30), GetLang("逻辑关系："))
        this.LogicalTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX + 85, PosY - 3, 60), GetLangArr([
            "且", "或"]))

        PosY += 30
        PosX := 10
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))
        PosX += 230
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))

        loop 4 {
            if (A_Index == 1)
                PosY += 25
            else
                PosY += 35
            PosX := 15
            con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
            con.OnEvent("Click", (*) => this.OnRefresh())
            this.ToggleConArr.Push(con)
            con.Value := 1

            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
            this.NameConArr.Push(con)

            con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX + 160, PosY - 3, 80), GetLangArr(["大于", "大于等于",
                "等于", "小于等于",
                "小于", "字符包含", "变量存在", "正则匹配"]))
            con.Value := 1
            con.OnEvent("Change", (*) => this.OnRefresh())
            this.CompareTypeConArr.Push(con)

            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 245, PosY - 3, 120), [])
            this.VariableConArr.Push(con)
        }

        PosY += 40
        PosX := 10
        SplitPosY := PosY
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 160, 20), GetLang("分支指令:"))

        PosX += 80
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 60, 25), GetLang("编辑"))
        btnCon.OnEvent("Click", (*) => this.OnEditMacroBtnClick())

        PosY += 25
        PosX := 10
        this.MacroCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 370, 60), "")

        PosY += 65
        PosX := 10
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), GetLang("流程控制："))
        PosX += 80
        this.ControlTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY, 125), GetLangArr(["无",
            "循环-跳过本轮", "循环-跳出", "分支-跳出"]))
        this.ControlTypeCon.Value := 1

        PosY += 40
        PosX := 170
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.OnEvent("Close", (*) => this.OnClose())
        pos := GetCenterPosOnActiveMonitor(420, 400)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 420, 400))
    }

    OnClose(*) {
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    Init(EditType, DataArr, logicStr, macro, controlType) {
        this.EditType := EditType
        this.LogicalTypeCon.Text := logicStr == "" ? GetLang("且") : logicStr
        this.MacroCon.Value := GetLangMacro(macro, 1)
        this.ControlTypeCon.Text := GetLang(controlType)
        this.DLVariableArr := GetGuiVarArr(1)

        VariNameArr := DataArr[1]
        CompareTypeArr := DataArr[2]
        VariableArr := DataArr[3]
        loop 4 {
            this.ToggleConArr[A_Index].Value := VariNameArr.Length >= A_Index
            this.NameConArr[A_Index].Delete()
            this.NameConArr[A_Index].Add(this.DLVariableArr)
            ; 与「如果」一致：显示多语言变量名
            this.NameConArr[A_Index].Text := VariNameArr.Length >= A_Index
                ? GetLang(VariNameArr[A_Index]) : "Var" A_Index
            cmp := CompareTypeArr.Length >= A_Index ? Integer(CompareTypeArr[A_Index]) : 1
            if (cmp < 1 || cmp > 8)
                cmp := 1
            this.CompareTypeConArr[A_Index].Value := cmp
            this.VariableConArr[A_Index].Delete()
            this.VariableConArr[A_Index].Add(this.DLVariableArr)
            this.VariableConArr[A_Index].Text := VariableArr.Length >= A_Index
                ? GetLang(VariableArr[A_Index]) : "Var" A_Index
        }

        isEnabled := EditType == 1
        this.LogicalTypeCon.Enabled := isEnabled
        loop 4 {
            this.ToggleConArr[A_Index].Enabled := isEnabled
        }
        this.OnRefresh()
    }

    OnRefresh(*) {
        loop 4 {
            isEnable := this.ToggleConArr[A_Index].Value && this.EditType == 1
            this.NameConArr[A_Index].Enabled := isEnable
            this.CompareTypeConArr[A_Index].Enabled := isEnable
            OperaTypeValue := this.CompareTypeConArr[A_Index].Value
            EnableVari := OperaTypeValue != 7 && isEnable
            this.VariableConArr[A_Index].Enabled := EnableVari
        }
    }

    OnClickSureBtn() {
        action := this.SureBtnAction
        if (this.IsSubMacroEdit) {
            if (this.EditType == 2) {
                this.Data.DefaultMacro := GetLangMacro(this.MacroCon.Value, 2)
                this.Data.DefaultControlType := GetLangKey(this.ControlTypeCon.Text)
            }
            else {
                VariNameArr := []
                CompareTypeArr := []
                VariableArr := []
                loop 4 {
                    if (this.ToggleConArr[A_Index].Value) {
                        VariNameArr.Push(GetLangKey(this.NameConArr[A_Index].Text))
                        CompareTypeArr.Push(this.CompareTypeConArr[A_Index].Value)
                        VariableArr.Push(GetLangKey(this.VariableConArr[A_Index].Text))
                    }
                }
                this.Data.VariNameArr[this.CondiNumber] := VariNameArr
                this.Data.CompareTypeArr[this.CondiNumber] := CompareTypeArr
                this.Data.VariableArr[this.CondiNumber] := VariableArr
                this.Data.LogicTypeArr[this.CondiNumber] := this.LogicalTypeCon.Value
                this.Data.MacroArr[this.CondiNumber] := GetLangMacro(this.MacroCon.Value, 2)
                this.Data.ControlTypeArr[this.CondiNumber] := GetLangKey(this.ControlTypeCon.Text)
            }
            SaveMacroCMDData(this.Data)
            action(this.MacroCon.Value)
        }
        else if (this.EditType == 1) {
            condiStr := ""
            loop 4 {
                if (this.ToggleConArr[A_Index].Value) {
                    if (this.CompareTypeConArr[A_Index].Value != 7) {
                        condiStr .= this.NameConArr[A_Index].Text " " this.CompareTypeConArr[A_Index].Text " " this.VariableConArr[
                            A_Index].Text
                    }
                    else {
                        condiStr .= this.NameConArr[A_Index].Text " " this.CompareTypeConArr[A_Index].Text
                    }

                    condiStr .= "⎖"
                }
            }
            condiStr := Trim(condiStr, "⎖")
            logicStr := this.LogicalTypeCon.Text
            macro := this.MacroCon.Value
            controlType := GetLangKey(this.ControlTypeCon.Text)
            action(condiStr, logicStr, macro, controlType)
        }
        else {
            controlType := GetLangKey(this.ControlTypeCon.Text)
            action(GetLang("以上都不是"), "", this.MacroCon.Value, controlType)
        }

        this.SureBtnAction := ""
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    OnMacroBtnClick(CommandStr) {
        this.MacroCon.Value := GetLangMacro(CommandStr, 1)
    }

    OnEditMacroBtnClick() {
        if (this.MacroGui == "") {
            this.MacroGui := MacroEditGui()
            this.MacroGui.DLVariableArr := this.DLVariableArr
            this.MacroGui.SureFocusCon := this.LogicalTypeCon

            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            this.MacroGui.ParentTile := ParentTile "-"
        }

        if (MainSoftData.IsModalSubGui && this.Gui != "") {
            this.MacroGui.OwnerHwnd := this.Gui.Hwnd
        }
        else {
            this.MacroGui.OwnerHwnd := ""
        }

        this.MacroGui.SureBtnAction := (command) => this.OnMacroBtnClick(command)
        this.MacroGui.ShowGui(this.MacroCon.Value, false)
    }
}
