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

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 50, 30), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX += 220
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 5, 180), GetLang("如果变量存在则不改变数值"))

        PosX := 10
        PosY += 35
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("运算表达式"))
        PosX += 290
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("保存结果变量"))

        PosY += 25
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 35, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 290, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(1))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 350, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 35, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 290, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(2))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 350, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 35, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 290, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(3))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 350, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 35, PosY - 3, 250), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 290, PosY - 4, 50), GetLang("编辑"))
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(4))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 350, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 40
        PosX := 250
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 500, 270))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("运算")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)

        ; 兼容性检查：如果ExpressionArr不存在，初始化为空数组
        if (!ObjHasOwnProp(this.Data, "ExpressionArr") || !IsObject(this.Data.ExpressionArr)) {
            this.Data.ExpressionArr := ["", "", "", ""]
        }

        ; 迁移旧数据：如果ExpressionArr为空但OperationArr有内容，则将OperationArr复制到ExpressionArr
        loop 4 {
            if (this.Data.ExpressionArr.Has(A_Index) && this.Data.ExpressionArr[A_Index] == "" 
                && this.Data.OperationArr.Has(A_Index) && this.Data.OperationArr[A_Index] != "") {
                this.Data.ExpressionArr[A_Index] := this.Data.OperationArr[A_Index]
            }
        }

        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        loop this.Data.ToggleArr.Length {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
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

        ; 保存表达式
        if (this.OperationSubGui && this.OperationSubGui.ExpressionCon) {
            expression := this.OperationSubGui.ExpressionCon.Value
            this.Data.ExpressionArr[index] := expression
        }
    }

    OnEditVariableBtnClick(index) {
        if (this.OperationSubGui == "") {
            this.OperationSubGui := OperationSubGui()
        }

        this.SaveOperationData()
        macroStr := this.GetCommandStr()
        VariableObjArr := GetGuiVariableObjArr(this.VariableObjArr)
        this.OperationSubGui.VariableObjArr := VariableObjArr
        ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
        this.OperationSubGui.ParentTile := ParentTile "-"

        SymbolArr := this.Data.SymbolGroups[index]
        ValueArr := this.Data.ValueGroups[index]
        Expression := this.Data.ExpressionArr.Has(index) ? this.Data.ExpressionArr[index] : ""
        this.OperationSubGui.SureBtnAction := (index, command, SymbolArr, ValueArr) => this.OnSureOperationBtnClick(
            index, command, SymbolArr, ValueArr)

        ; 将表达式作为参数传递给ShowGui，Name为空表示没有预先选择的变量
        this.OperationSubGui.ShowGui(index, "", this.OperationConArr[index].Value, SymbolArr, ValueArr, Expression)
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
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        loop this.Data.ToggleArr.Length {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.NameArr[A_Index] := ""  ; NameArr不再使用，变量从表达式中获取
            this.Data.OperationArr[A_Index] := GetLangStr(this.OperationConArr[A_Index].Value, 2)
            this.Data.UpdateNameArr[A_Index] := GetLangKey(this.UpdateNameConArr[A_Index].Text)
        }

        ; 确保ExpressionArr存在且有4个元素
        if (!ObjHasOwnProp(this.Data, "ExpressionArr") || !IsObject(this.Data.ExpressionArr)) {
            this.Data.ExpressionArr := ["", "", "", ""]
        }
        while (this.Data.ExpressionArr.Length < 4) {
            this.Data.ExpressionArr.Push("")
        }

        ; 添加全局变量，方便下拉选取
        loop this.Data.ToggleArr.Length {
            if (this.Data.ToggleArr[A_Index])
                MySoftData.GlobalVariMap[this.Data.UpdateNameArr[A_Index]] := true
        }
        SaveMacroCMDData(this.Data)
    }
}
