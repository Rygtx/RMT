#Requires AutoHotkey v2.0
#Include MacroEditGui.ahk

class CompareGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.RemarkCon := ""
        this.FocusCon := ""
        this.MacroGui := ""

        this.Data := ""
        this.IsIgnoreExistCon := ""
        this.ToggleConArr := []
        this.NameConArr := []
        this.CompareTypeConArr := []
        this.VariableConArr := []
        this.TrueMacroCon := ""
        this.FalseMacroCon := ""
        this.SaveToggleCon := ""
        this.SaveNameCon := ""
        this.TrueValueCon := ""
        this.FalseValueCon := ""
        this.LogicalTypeCon := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
        this.ToggleFunc(true)
        this.OnRefresh()
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("如果编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("快捷方式："))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!l")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 5, 80), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 90
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosY += 30
        PosX := 10
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))
        PosX += 230
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))

        PosY += 25
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        con.OnEvent("Click", this.OnRefresh.Bind(this))
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

        PosX += 400
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 80, 30), GetLang("逻辑关系："))
        this.LogicalTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX + 85, PosY - 3, 60), GetLangArr([
            "且", "或"]))

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)
        con.OnEvent("Click", this.OnRefresh.Bind(this))
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

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)
        con.OnEvent("Click", this.OnRefresh.Bind(this))
        con.Value := 1

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX + 160, PosY - 3, 80), GetLangArr(GetLangArr(["大于",
            "大于等于", "等于", "小于等于",
            "小于", "字符包含", "变量存在", "正则匹配"])))
        con.Value := 1
        con.OnEvent("Change", (*) => this.OnRefresh())
        this.CompareTypeConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 245, PosY - 3, 120), [])
        this.VariableConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)
        con.OnEvent("Click", this.OnRefresh.Bind(this))
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

        PosY += 35
        PosX := 10
        SplitPosY := PosY
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 160, 20), GetLang("结果真的指令:（可选）"))

        PosX += 160
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 80, 20), GetLang("编辑指令"))
        btnCon.OnEvent("Click", (*) => this.OnTrueBtnClick())

        PosY += 20
        PosX := 10
        this.TrueMacroCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 280, 50), "")

        PosY := SplitPosY
        PosX := 310
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 160, 20), GetLang("结果假的指令:（可选）"))

        PosX += 160
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 80, 20), GetLang("编辑指令"))
        btnCon.OnEvent("Click", (*) => this.OnFalseBtnClick())

        PosY += 20
        PosX := 310
        this.FalseMacroCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 280, 50), "")

        PosY += 60
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 320, 110), GetLang("结果保存到变量中"))

        PosX := 55
        PosY += 25
        this.ResultConArr := []
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{} h{}", PosX, PosY, 180, 20), GetLang(
            "如果变量存在则不改变数值"))
        this.ResultConArr.Push(this.IsIgnoreExistCon)

        PosX := 15
        PosY += 25
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))

        PosX += 50
        Con := MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))
        this.ResultConArr.Push(Con)

        PosX += 110
        Con := MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("真值"))
        this.ResultConArr.Push(Con)

        PosX += 100
        Con := MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("假值"))
        this.ResultConArr.Push(Con)

        PosY += 25
        PosX := 20
        this.SaveToggleCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.SaveToggleCon.OnEvent("Click", this.OnRefresh.Bind(this))
        this.SaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 100), [])
        this.TrueValueCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX + 145, PosY - 4, 70), 0)
        this.FalseValueCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX + 225, PosY - 4, 70), 0)
        this.ResultConArr.Push(this.SaveNameCon)
        this.ResultConArr.Push(this.TrueValueCon)
        this.ResultConArr.Push(this.FalseValueCon)

        PosY -= 30
        PosX := 410
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.Show(Format("w{} h{}", 600, 410))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("如果")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr(1)

        this.TrueMacroCon.Value := GetLangMacro(this.Data.TrueMacro, 1)
        this.FalseMacroCon.Value := GetLangMacro(this.Data.FalseMacro, 1)
        this.SaveToggleCon.Value := this.Data.SaveToggle
        this.SaveNameCon.Delete()
        this.SaveNameCon.Add(GetGuiVarArr())
        this.SaveNameCon.Text := GetLang(this.Data.SaveName)
        this.TrueValueCon.Value := this.Data.TrueValue
        this.FalseValueCon.Value := this.Data.FalseValue
        this.LogicalTypeCon.Value := this.Data.LogicalType
        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        loop this.Data.ToggleArr.Length {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.NameConArr[A_Index].Delete()
            this.NameConArr[A_Index].Add(this.DLVariableArr)
            this.NameConArr[A_Index].Text := GetLang(this.Data.NameArr[A_Index])
            this.CompareTypeConArr[A_Index].Value := this.Data.CompareTypeArr[A_Index]
            this.VariableConArr[A_Index].Delete()
            this.VariableConArr[A_Index].Add(this.DLVariableArr)
            this.VariableConArr[A_Index].Text := GetLang(this.Data.VariableArr[A_Index])
        }
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    CheckIfValid() {
        if (this.SaveToggleCon.Value && !CheckVarNameIfValid(this.SaveNameCon.Text))
            return false

        return true
    }

    ToggleFunc(state) {
        MacroAction := (*) => this.TriggerMacro()
        if (state) {
            Hotkey("!l", MacroAction, "On")
        }
        else {
            Hotkey("!l", MacroAction, "Off")
        }
    }

    OnRefresh(*) {
        loop 4 {
            isEnable := this.ToggleConArr[A_Index].Value

            this.NameConArr[A_Index].Enabled := isEnable
            this.CompareTypeConArr[A_Index].Enabled := isEnable
            OperaTypeValue := this.CompareTypeConArr[A_Index].Value
            EnableVari := OperaTypeValue != 7 && isEnable
            this.VariableConArr[A_Index].Enabled := EnableVari
        }

        canEditResult := this.SaveToggleCon.Value
        loop this.ResultConArr.Length {
            this.ResultConArr[A_Index].Enabled := canEditResult
        }
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return

        this.SaveCompareData()
        action := this.SureBtnAction
        action(this.GetCommandStr())
        this.ToggleFunc(false)
        this.Gui.Hide()
    }

    OnTrueSure(CommandStr) {
        CommandStr := GetLangMacro(CommandStr, 1)
        this.TrueMacroCon.Value := CommandStr
    }

    OnFalseSure(CommandStr) {
        CommandStr := GetLangMacro(CommandStr, 1)
        this.FalseMacroCon.Value := CommandStr
    }

    OnTrueBtnClick() {
        if (this.MacroGui == "") {
            this.MacroGui := MacroEditGui()
            this.MacroGui.SureFocusCon := this.FocusCon

            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            this.MacroGui.ParentTile := ParentTile "-"
        }

        this.MacroGui.SureBtnAction := (command) => this.OnTrueSure(command)
        this.MacroGui.ShowGui(this.TrueMacroCon.Value, false)
    }

    OnFalseBtnClick() {
        if (this.MacroGui == "") {
            this.MacroGui := MacroEditGui()
            this.MacroGui.SureFocusCon := this.FocusCon

            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            this.MacroGui.ParentTile := ParentTile "-"
        }
        this.MacroGui.SureBtnAction := (command) => this.OnFalseSure(command)
        this.MacroGui.ShowGui(this.FalseMacroCon.Value, false)
    }

    TriggerMacro() {
        valid := this.CheckIfValid()
        if (!valid)
            return

        this.SaveCompareData()
        OnTriggerSepcialItemMacro(this.GetCommandStr())
    }

    SaveCompareData() {
        this.Data.TrueMacro := GetLangMacro(this.TrueMacroCon.Value, 2)
        this.Data.FalseMacro := GetLangMacro(this.FalseMacroCon.Value, 2)
        this.Data.SaveToggle := this.SaveToggleCon.Value
        this.Data.SaveName := GetVarName(this.SaveNameCon.Text)
        this.Data.TrueValue := this.TrueValueCon.Value
        this.Data.FalseValue := this.FalseValueCon.Value
        this.Data.LogicalType := this.LogicalTypeCon.Value
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.NameArr[A_Index] := GetLangKey(this.NameConArr[A_Index].Text)
            this.Data.CompareTypeArr[A_Index] := this.CompareTypeConArr[A_Index].Value
            this.Data.VariableArr[A_Index] := GetLangKey(this.VariableConArr[A_Index].Text)
        }

        ; 添加全局变量，方便下拉选取
        if (this.Data.SaveToggle) {
            MySoftData.GlobalVariMap[this.Data.SaveName] := true
        }

        SaveMacroCMDData(this.Data)
    }
}
