#Requires AutoHotkey v2.0

class OperationSubGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.FocusCon := ""
        this.Index := 0
        this.Name := ""
        this.SymbolArr := []
        this.ValueArr := []

        this.ExpressionCon := ""
        this.OperaVariableCon := ""
        this.BaseValueCon := ""
        this.BaseResultCon := ""
    }

    ShowGui(index, Name, cmd, SymbolArr, ValurArr) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.DLVariableArr := GetGuiVarArr()
        this.Index := index
        this.Name := Name
        this.SymbolArr := SymbolArr
        this.ValueArr := ValurArr

        this.OperaVariableCon.Delete()
        this.OperaVariableCon.Add(this.DLVariableArr)
        this.OperaVariableCon.Text := "10"
        if (IsNumber(this.Name)) {
            this.BaseValueCon.Value := this.Name
        }
        this.UpdateExpression()
        this.UpdateExampleValue()
        this.FocusCon.Focus()
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("运算编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 400), Format("{}`n{}", GetLang(
            "运算符：+（加）、-（减）、*（乘）、（/）除、（%）取余"), GetLang("^（乘方）、..（字符拼接）")))

        PosX := 10
        PosY += 40
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 300, 20), GetLang("当前运算表达式"))
        PosY += 20
        this.ExpressionCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY, 350), "")
        this.ExpressionCon.Enabled := false

        PosX := 10
        PosY += 30
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY + 3, 120, 20), GetLang("被操作数值/变量："))
        PosX += 120
        this.OperaVariableCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY, 120), [])

        PosX := 10
        PosY += 30
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 300, 20), GetLang("操作运算符"))
        PosX := 10
        PosY += 20
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 50, 30), "+")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("+"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 60, PosY, 50, 30), "-")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("-"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 120, PosY, 50, 30), "*")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("*"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 180, PosY, 50, 30), "/")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("/"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 240, PosY, 50, 30), "%")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("%"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 300, PosY, 50, 30), "^")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("^"))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 360, PosY, 50, 30), "..")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn(".."))

        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 120), GetLang("假定操作变量值："))
        this.BaseValueCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX + 120, PosY - 3, 50), "10")

        PosY += 20
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 120), GetLang("换算后的结果是："))
        this.BaseResultCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX + 120, PosY, 200), "10")

        PosY += 30
        PosX := 10
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 100, PosY, 100, 40), GetLang("退格"))
        btnCon.OnEvent("Click", (*) => this.OnBackspaceBtnClick())
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 250, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 430, 300))
    }

    OnClickOperatorBtn(Symbol) {
        if (this.BaseValueCon.Value == "") {
            MsgBox(GetLang("被操作数值/变量不能为空"))
            return
        }
        Value := this.OperaVariableCon.Text
        this.SymbolArr.Push(Symbol)
        this.ValueArr.Push(Value)
        this.UpdateExpression()
    }

    OnBackspaceBtnClick() {
        if (this.SymbolArr.Length <= 0)
            return
        this.SymbolArr.Pop()
        this.ValueArr.Pop()
        this.UpdateExpression()
    }

    OnClickSureBtn() {
        if (this.SureBtnAction == "")
            return

        action := this.SureBtnAction
        action(this.Index, this.ExpressionCon.Value, this.SymbolArr, this.ValueArr)
        this.Gui.Hide()
    }

    UpdateExpression() {
        text := this.Name
        loop this.SymbolArr.Length {
            leftBracket := A_Index == 1 ? "" : "("
            rightBracket := A_Index == 1 ? "" : ")"
            Symbol := this.SymbolArr[A_Index]
            Value := this.ValueArr[A_Index]
            text := leftBracket text rightBracket Symbol Value
        }
        this.ExpressionCon.Value := text
        this.UpdateExampleValue()
    }

    UpdateExampleValue() {
        HasVariable := false
        loop this.ValueArr.Length {
            if (!IsNumber(this.ValueArr[A_Index])) {
                this.BaseResultCon.Value := GetLang("表达式中有变量无法进行预算")
                return
            }
        }

        sum := GetOperationResult(this.BaseValueCon.Value, this.SymbolArr, this.ValueArr)
        this.BaseResultCon.Value := sum
    }
}
