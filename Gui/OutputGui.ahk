#Requires AutoHotkey v2.0

class OutputGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.FilePathConArr := []
        this.ExcelConArr := []
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
        this.ToggleFunc(true)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("输出编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("快捷方式："))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!l")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 5, 80), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 90
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX := 10
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 80, 20), GetLang("输出类型:"))
        PosX += 80
        this.OutputTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 130), GetLangArr(["发送内容",
            "粘贴内容", "临时提示", "指令窗口", "软件弹窗", "系统语音", "复制到剪切板", "文本文件", "Excel"]))
        this.OutputTypeCon.Value := 1
        this.OutputTypeCon.OnEvent("Change", (*) => this.OnOutTypeChange())

        PosX := 250
        this.EncodingConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("文件编码:"))
        this.EncodingConArr.Push(con)
        PosX += 80
        TypeArr := GetLangArr(MySoftData.FileEncodingArr)
        this.EncodingCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 3, 130), TypeArr)
        this.EncodingConArr.Push(this.EncodingCon)

        PosX := 10
        PosY += 30
        this.TextTipCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 80, 20), GetLang("输出内容："))
        PosX += 80
        this.TextCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 370, 50))

        PosX := 10
        PosY += 55
        this.VariTipCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 350, 20), GetLang("变量数组："))
        PosX += 80
        this.VarTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY, 85), GetLangArr(["变量",
            "数组"]))
        this.VarTypeCon.Value := 1
        this.VarTypeCon.OnEvent("Change", this.OnRefreshVarType.Bind(this))
        PosX += 90
        this.VariCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R10", PosX, PosY, 130), [])
        this.VarNameBtn := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 135, PosY - 1, 70, 29), GetLang("追加名"))
        this.VarNameBtn.OnEvent("Click", (*) => this.OnClickAddVarNameBtn())
        this.VarValueBtn := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX + 210, PosY - 1, 70, 29), GetLang("追加值"))
        this.VarValueBtn.OnEvent("Click", (*) => this.OnClickAddVarValueBtn())

        PosX := 10
        PosY += 35
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("文件路径:"))
        this.FilePathConArr.Push(con)
        PosX += 80
        this.FilePathCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 280, 30))
        this.FilePathConArr.Push(this.FilePathCon)
        PosX += 290
        con := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("选择路径"))
        con.OnEvent("Click", (*) => this.OnSelectPathBtnClick())
        this.FilePathConArr.Push(con)

        PosX := 10
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("写入类型:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.ExcelTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY, 130), GetLangArr(["单元格",
            "行号自增", "列号自增", "指定区域-行", "指定区域-列"]))
        this.ExcelConArr.Push(this.ExcelTypeCon)
        this.ExcelTypeCon.OnEvent("Change", (*) => this.OnOutTypeChange())

        PosX += 160
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表名或序号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.NameOrSerialCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 130, 30))
        this.ExcelConArr.Push(this.NameOrSerialCon)

        PosX := 10
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表格行号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.RowVarCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 130), [])
        this.ExcelConArr.Push(this.RowVarCon)

        PosX += 160
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表格列号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.ColVarCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 130, 30), [])
        this.ExcelConArr.Push(this.ColVarCon)

        PosX := 10
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("终止行号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.RowEndCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 130), [])
        this.ExcelConArr.Push(this.RowEndCon)

        PosX += 160
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("终止列号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.ColEndCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 130, 30), [])
        this.ExcelConArr.Push(this.ColEndCon)

        PosY += 45
        PosX := 200
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.ToggleFunc(false))
        MyGui.Show(Format("w{} h{}", 500, 400))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("输出")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr(1)

        this.TextCon.Value := GetLangStr(this.Data.Text, 1)
        this.OutputTypeCon.Value := this.Data.OutputType
        this.EncodingCon.Text := GetShowEncoding(this.Data.Encoding)
        this.FilePathCon.Value := this.Data.FilePath
        this.VariCon.Delete()
        this.VariCon.Add(this.DLVariableArr)
        this.VariCon.Value := 1
        this.RowVarCon.Delete()
        this.RowVarCon.Add(GetGuiVarArr(2))
        this.ColVarCon.Delete()
        this.ColVarCon.Add(GetGuiVarArr(2))
        this.RowEndCon.Delete()
        this.RowEndCon.Add(GetGuiVarArr(2))
        this.ColEndCon.Delete()
        this.ColEndCon.Add(GetGuiVarArr(2))

        this.ExcelTypeCon.Value := this.Data.ExcelType
        this.NameOrSerialCon.Value := this.Data.NameOrSerial
        this.RowVarCon.Text := this.Data.RowVar
        this.ColVarCon.Text := this.Data.ColVar
        this.RowEndCon.Text := this.Data.RowEndVar
        this.ColEndCon.Text := this.Data.ColEndVar

        this.OnOutTypeChange()
    
        if (this.OutputTypeCon.Value == 9 && (this.ExcelTypeCon.Value == 4 || this.ExcelTypeCon.Value == 5))
            this.VariCon.Text := this.Data.ArrName
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

    OnRefreshVarType(*) {
        IsResVar := this.VarTypeCon.Text == GetLang("变量")
        DLArr := IsResVar ? GetGuiVarArr(1) : GetGuiArrNameArr()
        SetDLConValue(this.VariCon, DLArr, this.VariCon.Text)
    }

    OnClickAddVarNameBtn() {
        this.TextCon.Value .= this.VariCon.Text
    }

    OnClickAddVarValueBtn() {
        ArraySymbol := this.VarTypeCon.Text == GetLang("变量") ? "" : "ε"
        this.TextCon.Value .= "{" ArraySymbol this.VariCon.Text "}"
    }

    OnOutTypeChange() {
        IsTextFile := this.OutputTypeCon.Value == 8
        showFileConArr := this.OutputTypeCon.Value == 8 || this.OutputTypeCon.Value == 9
        showExcelConArr := this.OutputTypeCon.Value == 9

        loop this.EncodingConArr.Length {
            this.EncodingConArr[A_Index].Visible := IsTextFile
        }

        loop this.FilePathConArr.Length {
            this.FilePathConArr[A_Index].Visible := showFileConArr
        }

        loop this.ExcelConArr.Length {
            this.ExcelConArr[A_Index].Visible := showExcelConArr
        }

        ExcelType := this.ExcelTypeCon.Value
        this.RowVarCon.Enabled := ExcelType != 2
        this.ColVarCon.Enabled := ExcelType != 3
        this.RowEndCon.Enabled := ExcelType == 4 || ExcelType == 5
        this.ColEndCon.Enabled := ExcelType == 4 || ExcelType == 5

        isOnlyArr := showExcelConArr && (this.ExcelTypeCon.Value == 4 || this.ExcelTypeCon.Value == 5)
        this.TextCon.Enabled := !isOnlyArr
        this.VarNameBtn.Enabled := !isOnlyArr
        this.VarValueBtn.Enabled := !isOnlyArr
        this.VarTypeCon.Enabled := !isOnlyArr
        this.VarTypeCon.Value := isOnlyArr ? 2 : this.VarTypeCon.Value
        if (isOnlyArr)
            this.OnRefreshVarType()
    }

    OnSelectPathBtnClick() {
        path := FileSelect(1, , GetLang("选择输出的目标文件"))
        this.FilePathCon.Value := path
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveOutputData()
        this.ToggleFunc(false)
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        if (this.OutputTypeCon.Value == 8 || this.OutputTypeCon.Value == 9) {
            if (this.FilePathCon.Value == "") {
                MsgBox(GetLang("请选择文件路径"))
                return
            }
        }
        return true
    }

    TriggerMacro() {
        this.SaveOutputData()
        OnTriggerSepcialItemMacro(this.GetCommandStr())
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    SaveOutputData() {
        this.Data.Text := GetLangStr(this.TextCon.Value, 2)
        this.Data.OutputType := this.OutputTypeCon.Value
        this.Data.Encoding := GetSoftEncoding(this.EncodingCon.Text)
        this.Data.FilePath := this.FilePathCon.Value
        this.Data.ExcelType := this.ExcelTypeCon.Value
        this.Data.NameOrSerial := this.NameOrSerialCon.Value
        this.Data.RowVar := GetLangStr(this.RowVarCon.Text, 2)
        this.Data.ColVar := GetLangStr(this.ColVarCon.Text, 2)
        this.Data.RowEndVar := GetLangStr(this.RowEndCon.Text, 2)
        this.Data.ColEndVar := GetLangStr(this.ColEndCon.Text, 2)
        this.Data.ArrName := GetLangStr(this.VariCon.Text, 2)
        SaveMacroCMDData(this.Data)
    }
}
