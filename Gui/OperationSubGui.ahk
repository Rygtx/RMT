#Requires AutoHotkey v2.0

class OperationSubGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
        this.FocusCon := ""
        this.Index := 0
        this.Name := ""
        this.SymbolArr := []
        this.ValueArr := []

        this.ExpressionCon := ""
        this.OperaVariableCon := ""  ; 恢复下拉框
        this.BaseValueCon := ""
        this.BaseResultCon := ""
        this.IsEditMode := false  ; 标记是否使用表达式编辑模式
    }

    ShowGui(index, Name, cmd, SymbolArr, ValurArr, Expression := "") {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Index := index
        this.Name := Name
        this.SymbolArr := SymbolArr
        this.ValueArr := ValurArr

        ; 初始化变量列表下拉框
        this.OperaVariableCon.Delete()
        this.OperaVariableCon.Add(this.VariableObjArr)
        this.OperaVariableCon.Text := "10"

        if (IsNumber(this.Name)) {
            this.BaseValueCon.Value := this.Name
        }

        ; 如果有表达式参数，优先使用；否则从SymbolArr/ValueArr生成
        if (Expression != "") {
            this.ExpressionCon.Value := Expression
            this.IsEditMode := true
        } else if (cmd != "") {
            ; 使用旧格式的OperationArr字符串作为表达式
            this.ExpressionCon.Value := cmd
            this.IsEditMode := true
        } else if (this.ExpressionCon.Value == "" || this.ExpressionCon.Value == Name) {
            this.UpdateExpression()
            this.IsEditMode := false
        } else {
            this.IsEditMode := true
        }

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
            "运算符：+（加）、-（减）、*（乘）、（/）除、（%）取余"), GetLang("^（乘方）、()（括号）")))

        PosX := 10
        PosY += 40
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 300, 20), GetLang("当前运算表达式（可编辑）"))
        PosY += 20
        this.ExpressionCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY, 350), "")
        this.ExpressionCon.Enabled := true  ; 改为可编辑

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

        PosY += 40
        PosX := 10
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 50, 30), "(")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn("("))
        con := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 60, PosY, 50, 30), ")")
        con.OnEvent("Click", (*) => this.OnClickOperatorBtn(")"))

        PosY += 40
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 120), GetLang("变量列表："))
        PosX += 120
        this.OperaVariableCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY, 200), [])
        this.OperaVariableCon.OnEvent("Change", (*) => this.OnVariableChanged())

        PosX := 10
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 120), GetLang("换算后的结果是："))
        this.BaseResultCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX + 120, PosY, 200), "10")

        PosY += 30
        PosX := 10
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("计算结果"))
        btnCon.OnEvent("Click", (*) => this.OnCalculateResultBtnClick())
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 110, PosY, 100, 40), GetLang("退格"))
        btnCon.OnEvent("Click", (*) => this.OnBackspaceBtnClick())
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 220, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 370, 310))
    }

    OnClickOperatorBtn(Symbol) {
        ; 所有运算符直接添加到表达式
        this.ExpressionCon.Value := this.ExpressionCon.Value Symbol
        this.UpdateExampleValue()
        this.IsEditMode := true
    }

    OnVariableChanged() {
        ; 当用户选择变量时，自动添加到表达式
        VarName := this.OperaVariableCon.Text
        if (VarName != "" && VarName != "10") {
            ; 如果当前表达式不为空且不是运算符，添加一个空格
            currentExpr := this.ExpressionCon.Value
            if (currentExpr != "" && !InStr("+-*/%^().", SubStr(currentExpr, -1))) {
                this.ExpressionCon.Value := currentExpr VarName
            } else {
                this.ExpressionCon.Value := currentExpr VarName
            }
            this.UpdateExampleValue()
            this.IsEditMode := true
        }
    }

    OnBackspaceBtnClick() {
        ; 获取当前表达式
        expr := this.ExpressionCon.Value
        if (expr == "")
            return

        ; 删除最后一个字符
        this.ExpressionCon.Value := SubStr(expr, 1, -1)

        ; 同步更新SymbolArr和ValueArr（尝试反向解析）
        this.TryParseFromExpression()
        this.UpdateExampleValue()
        this.IsEditMode := true
    }

    OnCalculateResultBtnClick() {
        ; 计算当前表达式的结果
        expr := this.ExpressionCon.Value
        if (expr == "") {
            MsgBox(GetLang("表达式不能为空"))
            return
        }

        ; 检查是否包含变量
        hasVariable := RegExMatch(expr, "[a-zA-Z_]")

        ; 如果有变量，先将其替换为假定值（10）
        if (hasVariable) {
            ; 获取所有变量名
            VarNames := []
            pos := 1
            loop {
                match := RegExMatch(expr, "[a-zA-Z_][a-zA-Z0-9_]*", &VarName, pos)
                if (!match)
                    break
                ; 避免重复添加
                found := false
                for v in VarNames {
                    if (v == VarName[0]) {
                        found := true
                        break
                    }
                }
                if (!found)
                    VarNames.Push(VarName[0])
                pos := match + StrLen(VarName[0])
            }

            ; 替换变量为假定值10
            testExpr := expr
            for VarName in VarNames {
                testExpr := StrReplace(testExpr, VarName, "10")
            }

            ; 计算包含变量的表达式
            try {
                result := EvaluateExpression(testExpr)
                MsgBox(Format("{}：{}{}", GetLang("假定变量值为10，计算结果"), result, "`n" GetLang("提示：实际运行时会使用真实的变量值")))
            } catch Error as e {
                MsgBox(Format(GetLang("表达式语法错误：{}"), e.Message))
            }
        } else {
            ; 没有变量，直接计算
            try {
                result := EvaluateExpression(expr)
                MsgBox(Format(GetLang("计算结果：{}"), result))
            } catch Error as e {
                MsgBox(Format(GetLang("表达式语法错误：{}"), e.Message))
            }
        }
    }

    OnClickSureBtn() {
        if (this.SureBtnAction == "")
            return

        ; 获取表达式
        expression := this.ExpressionCon.Value

        ; 如果表达式是空的或只有基础值，使用旧的SymbolArr/ValueArr
        if (expression == "" || expression == this.Name) {
            action := this.SureBtnAction
            action(this.Index, this.ExpressionCon.Value, this.SymbolArr, this.ValueArr)
        } else {
            ; 使用新表达式
            action := this.SureBtnAction
            action(this.Index, expression, this.SymbolArr, this.ValueArr)
        }

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
        expr := this.ExpressionCon.Value
        if (expr == "")
            return

        ; 检查是否包含变量（字母开头的标识符）
        ; 如果包含字母，则认为是变量
        HasVariable := RegExMatch(expr, "[a-zA-Z_]")

        if (HasVariable) {
            this.BaseResultCon.Value := GetLang("表达式中有变量无法进行预算")
            return
        }

        ; 尝试计算表达式
        try {
            result := EvaluateExpression(expr)
            this.BaseResultCon.Value := result
        } catch {
            this.BaseResultCon.Value := GetLang("表达式语法错误")
        }
    }

    ; 尝试从表达式反向解析SymbolArr和ValueArr
    TryParseFromExpression() {
        expr := this.ExpressionCon.Value
        if (expr == "")
            return false

        ; 简单的解析：按运算符分割
        ; 这只是近似解析，用于兼容旧格式
        this.SymbolArr := []
        this.ValueArr := []

        ; 去除括号和空格
        expr := RegExReplace(expr, "[\(\)\s]+", "")

        ; 按运算符分割
        tokens := RegExReplace(expr, "([+\-*/%\^])", "|$1|")
        tokens := StrSplit(tokens, "|")

        ; 过滤空值
        filteredTokens := []
        for token in tokens {
            if (token != "")
                filteredTokens.Push(token)
        }

        ; 第一个是基础值，已经存储在this.Name中
        ; 剩余的是 运算符 + 值 的对
        i := 1
        while (i + 1 <= filteredTokens.Length) {
            symbol := filteredTokens[i]
            value := filteredTokens[i + 1]

            ; 验证symbol是运算符
            if (InStr("+-*/%^", symbol) || symbol == "..") {
                this.SymbolArr.Push(symbol)
                this.ValueArr.Push(value)
                i += 2
            } else {
                i += 1
            }
        }

        return this.SymbolArr.Length > 0
    }
}
