#Requires AutoHotkey v2.0
#Include OperationSubGui.ahk

class OperationGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
        this.RemarkCon := ""
        this.Data := ""
        this.OperationSubGui := ""

        this.IsIgnoreExistCon := ""
        this.ToggleConArr := []
        this.NameConArr := []
        this.OperationConArr := []
        this.UpdateNameConArr := []
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("运算编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 20
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 50, 30), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX := 10
        PosY += 30
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 110), GetLang("创建/更新选项："))

        PosX += 115
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 150), GetLang("变量存在忽略操作"))

        PosX := 10
        PosY += 25
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("选择/输入"))
        PosX += 150
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("运算表达式"))
        PosX += 290
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("保存结果变量"))

        PosY += 25
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 415, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(1))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 475, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 415, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(2))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 475, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 415, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(3))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 475, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 415, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(4))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 475, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 40
        PosX := 250
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 630, 280))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("运算")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)

        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        loop 4 {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.NameConArr[A_Index].Delete()
            this.NameConArr[A_Index].Add(RemoveInVariable(this.VariableObjArr))
            this.NameConArr[A_Index].Text := GetLang(this.Data.NameArr[A_Index])
            this.OperationConArr[A_Index].Value := GetLangStr(this.Data.OperationArr[A_Index], 1)
            this.UpdateNameConArr[A_Index].Delete()
            this.UpdateNameConArr[A_Index].Add(RemoveInVariable(this.VariableObjArr))
            this.UpdateNameConArr[A_Index].Text := GetLang(this.Data.UpdateNameArr[A_Index])
        }
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        Remark := this.RemarkCon.Value
        if (Remark == "") {
            Remark := GetLang("更新")
            loop 4 {
                if (this.ToggleConArr[A_Index].Value) {
                    Remark .= this.UpdateNameConArr[A_Index].Text "&"
                }
            }
            Remark := RTrim(Remark, "&")
        }
        CommandStr := CorrectRemark(CommandStr, Remark)
        return CommandStr
    }

    OnSureOperationBtnClick(index, command, SymbolArr, ValueArr) {
        con := this.OperationConArr[index]
        con.Value := command
        this.Data.SymbolGroups[index] := SymbolArr
        this.Data.ValueGroups[index] := ValueArr
    }

    OnEditVariableBtnClick(index) {
        if (this.OperationSubGui == "") {
            this.OperationSubGui := OperationSubGui()
        }
        Name := this.NameConArr[index].Text
        if (Name == "" || Name == "空") {
            MsgBox(GetLang("选择/输入1不可为空"))
            return
        }

        this.SaveOperationData()
        macroStr := this.GetCommandStr()
        VariableObjArr := GetGuiVariableObjArr(this.VariableObjArr)
        this.OperationSubGui.VariableObjArr := VariableObjArr
        ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
        this.OperationSubGui.ParentTile := ParentTile "-"

        SymbolArr := this.Data.SymbolGroups[index]
        ValueArr := this.Data.ValueGroups[index]
        this.OperationSubGui.SureBtnAction := (index, command, SymbolArr, ValueArr) => this.OnSureOperationBtnClick(
            index, command, SymbolArr, ValueArr)
        this.OperationSubGui.ShowGui(index, Name, this.OperationConArr[index].Value, SymbolArr, ValueArr)
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveOperationData()
        action := this.SureBtnAction
        action(this.GetCommandStr())
        this.Gui.Hide()
    }

    CheckIfValid() {
        loop 4 {
            if (this.ToggleConArr[A_Index].Value) {
                if (IsNumber(this.UpdateNameConArr[A_Index].Text)) {
                    MsgBox(Format(GetLang("{}. 结果变量名不规范：变量名不能是纯数字"), A_Index))
                    return false
                }

                if (this.UpdateNameConArr[A_Index].Text == "") {
                    MsgBox(Format(GetLang("{}. 结果变量名不规范：变量名不能为空"), A_Index))
                    return false
                }

                if (InStr(this.UpdateNameConArr[A_Index].Text, "_")) {
                    MsgBox(Format(GetLang("{}. 结果变量名不规范：变量名不能包含下划线"), A_Index))
                    return false
                }
            }
        }

        return true
    }

    SaveOperationData() {
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.NameArr[A_Index] := GetLangKey(this.NameConArr[A_Index].Text)
            this.Data.OperationArr[A_Index] := GetLangStr(this.OperationConArr[A_Index].Value, 2)
            this.Data.UpdateNameArr[A_Index] := GetLangKey(this.UpdateNameConArr[A_Index].Text)
        }

        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value

        ; 添加全局变量，方便下拉选取
        loop 4 {
            if (this.Data.ToggleArr[A_Index])
                MySoftData.GlobalVariMap[this.Data.UpdateNameArr[A_Index]] := true
        }

        SaveMacroCMDData(this.Data)
    }
}
