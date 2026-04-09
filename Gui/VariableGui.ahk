#Requires AutoHotkey v2.0

class VariableGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.RemarkCon := ""

        this.IsIgnoreExistCon := ""
        this.ToggleConArr := []
        this.VariableConArr := []
        this.OperaTypeConArr := []
        this.CopyVariableConArr := []
        this.MinVariableConArr := []
        this.MaxVariableConArr := []
        this.Data := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
        this.OnRefresh()
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("变量编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX += 200
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 5, 180), GetLang(
            "如果变量存在则不改变数值"))

        PosX += 200
        Con := MyGui.Add("Button", Format("x{} y{} w30", PosX, PosY - 4), "?")
        Con.OnEvent("Click", this.OnClickTypeHelpBtn.Bind(this))

        {
            PosX := 10
            PosY += 30
            MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 660, 180), GetLang("变量："))

            PosX := 11
            PosY += 20
            MyGui.Add("Text", Format("x{} y{} w{} h{} Center", PosX, PosY, 50, 20), GetLang("开关"))

            PosX += 50
            MyGui.Add("Text", Format("x{} y{} w{} h{} Center", PosX, PosY, 80, 20), GetLang("变量名"))

            PosX += 125
            MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("操作类型"))

            PosX += 110
            MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("选择/输入"))

            PosX += 110
            MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("最小值选择/输入"))

            PosX += 130
            MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("最大值选择/输入"))

            PosX := 10
            PosY += 20
            con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX + 20, PosY, 30, 20), "")
            con.Value := 1
            this.ToggleConArr.Push(con)

            PosX += 50
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.VariableConArr.Push(con)

            PosX += 125
            con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 2, 80), GetLangArr(["数值", "随机数值", "字符",
                "删除"]))
            con.OnEvent("Change", (*) => this.OnRefresh())
            this.OperaTypeConArr.Push(con)

            PosX += 90
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.CopyVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MinVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MaxVariableConArr.Push(con)

            PosX := 10
            PosY += 35
            con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX + 20, PosY, 30, 20), "")
            con.Value := 1
            this.ToggleConArr.Push(con)

            PosX += 50
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.VariableConArr.Push(con)

            PosX += 125
            con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 2, 80), GetLangArr(["数值", "随机数值", "字符",
                "删除"]))
            con.OnEvent("Change", (*) => this.OnRefresh())
            this.OperaTypeConArr.Push(con)

            PosX += 90
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.CopyVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MinVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MaxVariableConArr.Push(con)

            PosX := 10
            PosY += 35
            con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX + 20, PosY, 30, 20), "")
            con.Value := 1
            this.ToggleConArr.Push(con)

            PosX += 50
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.VariableConArr.Push(con)

            PosX += 125
            con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 2, 80), GetLangArr(GetLangArr(["数值",
                "随机数值", "字符",
                "删除"])))
            con.OnEvent("Change", (*) => this.OnRefresh())
            this.OperaTypeConArr.Push(con)

            PosX += 90
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.CopyVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MinVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MaxVariableConArr.Push(con)

            PosX := 10
            PosY += 35
            con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX + 20, PosY, 30, 20), "")
            con.Value := 1
            this.ToggleConArr.Push(con)

            PosX += 50
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.VariableConArr.Push(con)

            PosX += 125
            con := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 2, 80), GetLangArr(["数值", "随机数值", "字符",
                "删除"]))
            con.OnEvent("Change", (*) => this.OnRefresh())
            this.OperaTypeConArr.Push(con)

            PosX += 90
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.CopyVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MinVariableConArr.Push(con)

            PosX += 130
            con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 2, 120), [])
            this.MaxVariableConArr.Push(con)
        }

        PosY += 50
        PosX := 290
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{} Center", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 680, 300))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("变量")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr()

        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        loop 4 {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.VariableConArr[A_Index].Delete()
            this.VariableConArr[A_Index].Add(RemoveInVariable(this.DLVariableArr))
            this.VariableConArr[A_Index].Text := GetLang(this.Data.VariableArr[A_Index])
            this.OperaTypeConArr[A_Index].Value := this.Data.OperaTypeArr[A_Index]
            this.CopyVariableConArr[A_Index].Delete()
            this.CopyVariableConArr[A_Index].Add(this.DLVariableArr)
            this.CopyVariableConArr[A_Index].Text := GetLang(this.Data.CopyVariableArr[A_Index])
            this.MinVariableConArr[A_Index].Delete()
            this.MinVariableConArr[A_Index].Add(RemoveInVariable(this.DLVariableArr, 2))
            this.MinVariableConArr[A_Index].Text := GetLang(this.Data.MinVariableArr[A_Index])
            this.MaxVariableConArr[A_Index].Delete()
            this.MaxVariableConArr[A_Index].Add(RemoveInVariable(this.DLVariableArr, 2))
            this.MaxVariableConArr[A_Index].Text := GetLang(this.Data.MaxVariableArr[A_Index])
        }
    }

    OnRefresh() {
        loop 4 {
            OperaTypeValue := this.OperaTypeConArr[A_Index].Value
            EnableCopy := OperaTypeValue == 1 || OperaTypeValue == 3
            EnableMinMax := OperaTypeValue == 2
            this.CopyVariableConArr[A_Index].Enabled := EnableCopy
            this.MinVariableConArr[A_Index].Enabled := EnableMinMax
            this.MaxVariableConArr[A_Index].Enabled := EnableMinMax
        }
    }

    OnClickTypeHelpBtn(*) {
        str1 := GetLang("循环次数：如指令上级存在 循环 指令，则该变量为该循环体执行的次数")
        str2 := GetLang("宏循环次数：配置整体执行的次数")
        str3 := GetLang("句柄ID：实时获取当前鼠标窗口句柄ID")
        str4 := GetLang("当前鼠标坐标X：实时获取当前鼠标X")
        str5 := GetLang("当前鼠标坐标Y：实时获取当前鼠标Y")

        str := Format("{}`n{}`n{}`n{}`n{}", str1, str2, str3, str4, str5)
        MsgBox(str, GetLang("变量信息说明"), "Owner" this.Gui.Hwnd)
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveVariableData()
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        loop 4 {
            IsOn := this.ToggleConArr[A_Index].Value
            if (IsOn && !CheckVarNameIfValid(this.VariableConArr[A_Index].Text))
                return false
        }
        return true
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        Remark := this.RemarkCon.Value
        if (Remark == "") {
            loop 4 {
                if (this.ToggleConArr[A_Index].Value) {
                    CurVarRemark := this.VariableConArr[A_Index].Text
                    if (this.OperaTypeConArr[A_Index].Value == 1) {
                        if (IsNumber(this.CopyVariableConArr[A_Index].Text)) {
                            CurVarRemark .= "=" this.CopyVariableConArr[A_Index].Text
                        }
                    }
                    else if (this.OperaTypeConArr[A_Index].Value == 2) {
                        CurVarRemark .= GetLang("随机")
                        isNumSpan := IsNumber(this.MinVariableConArr[A_Index].Text) && IsNumber(this.MaxVariableConArr[
                            A_Index].Text)
                        if (isNumSpan)
                            CurVarRemark .= this.MinVariableConArr[A_Index].Text "~" this.MaxVariableConArr[A_Index].Text
                    }
                    else if (this.OperaTypeConArr[A_Index].Value == 4) {
                        CurVarRemark .= GetLang("删除")
                    }
                    Remark .= CurVarRemark "&"
                }
            }
            Remark := RTrim(Remark, "&")
        }
        CommandStr := CorrectRemark(CommandStr, Remark)
        return CommandStr
    }

    SaveVariableData() {
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.VariableArr[A_Index] := GetLangKey(this.VariableConArr[A_Index].Text)
            this.Data.OperaTypeArr[A_Index] := this.OperaTypeConArr[A_Index].Value
            this.Data.CopyVariableArr[A_Index] := GetLangKey(this.CopyVariableConArr[A_Index].Text)
            this.Data.MinVariableArr[A_Index] := GetLangKey(this.MinVariableConArr[A_Index].Text)
            this.Data.MaxVariableArr[A_Index] := GetLangKey(this.MaxVariableConArr[A_Index].Text)
        }

        ; 添加全局变量，方便下拉选取
        loop 4 {
            if (this.Data.ToggleArr[A_Index])
                MySoftData.GlobalVariMap[this.Data.VariableArr[A_Index]] := true
        }

        SaveMacroCMDData(this.Data)
    }
}
