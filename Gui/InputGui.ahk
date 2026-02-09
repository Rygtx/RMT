#Requires AutoHotkey v2.0

class InputGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""

        this.ReadTypeMap := Map(
            GetLang("文本文件"), [GetLang("读取全部内容"), GetLang("逐行读取"), GetLang("指定行")],
            GetLang("Excel"), [GetLang("表格行"), GetLang("表格列"), GetLang("指定单元格"), GetLang("指定区域")])
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
        this.RefreshConVisable()
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("输入编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80, 20), GetLang("快捷方式："))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!l")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 5, 80), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 120
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX := 20
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("输入类型:"))
        PosX += 80
        TypeArr := GetLangArr(["弹窗", "状态", "文本文件", "Excel", "继续", "继续&取消"])
        this.TypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 3, 150), TypeArr)
        this.TypeCon.OnEvent("Change", this.OnRefreshType.Bind(this))

        PosX := 280
        this.EncodingConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("文件编码:"))
        this.EncodingConArr.Push(con)
        PosX += 80
        TypeArr := GetLangArr(MySoftData.FileEncodingArr)
        this.EncodingCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 3, 150), TypeArr)
        this.EncodingConArr.Push(this.EncodingCon)

        PosX := 20
        PosY += 40
        this.InterConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("交互时:"))
        this.InterConArr.Push(con)
        PosX += 80
        TypeArr := GetLangArr(["暂停当前宏", "暂停所有宏"])
        this.PauseTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 3, 150), TypeArr)
        this.InterConArr.Push(this.PauseTypeCon)

        PosX := 280
        this.CancelConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("取消时:"))
        this.CancelConArr.Push(con)
        PosX += 80
        TypeArr := GetLangArr(["终止当前宏", "终止所有宏"])
        this.CancelTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R5", PosX, PosY - 3, 150), TypeArr)
        this.CancelConArr.Push(this.CancelTypeCon)

        PosX := 20
        PosY += 40
        this.FilePathConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("文件路径:"))
        this.FilePathConArr.Push(con)
        PosX += 80
        this.FilePathCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 320, 30))
        this.FilePathConArr.Push(this.FilePathCon)
        PosX += 330
        con := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("选择路径"))
        con.OnEvent("Click", (*) => this.OnSelectPathBtnClick())
        this.FilePathConArr.Push(con)

        PosX := 20
        PosY += 40
        this.ReadConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("读取类型:"))
        this.ReadConArr.Push(con)
        PosX += 80
        this.ReadTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY, 150), GetLangArr([]))
        this.ReadTypeCon.OnEvent("Change", this.OnRefreshReadType.Bind(this))
        this.ReadConArr.Push(this.ReadTypeCon)

        PosX := 280
        this.FileRowConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("行号:"))
        this.FileRowConArr.Push(con)
        PosX += 80
        this.FileRowCon := MyGui.Add("ComboBox", Format("x{} y{} w{} h{}", PosX, PosY, 150, 30), [])
        this.FileRowConArr.Push(this.FileRowCon)

        PosX := 280
        this.ExcelConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表名或序号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.NameOrSerialCon := MyGui.Add("ComboBox", Format("x{} y{} w{} h{}", PosX, PosY, 150, 30), [])
        this.ExcelConArr.Push(this.NameOrSerialCon)

        PosX := 20
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表格行号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.RowCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 150), [])
        this.ExcelConArr.Push(this.RowCon)

        PosX := 280
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("表格列号:"))
        this.ExcelConArr.Push(con)
        PosX += 80
        this.ColCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 150, 30), [])
        this.ExcelConArr.Push(this.ColCon)

        PosX := 20
        PosY += 40
        this.RegionConArr := []
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("终止行号:"))
        this.RegionConArr.Push(con)
        PosX += 80
        this.EndRowCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 150), [])
        this.RegionConArr.Push(this.EndRowCon)

        PosX := 280
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 5, 80), GetLang("终止列号:"))
        this.RegionConArr.Push(con)
        PosX += 80
        this.EndColCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY, 150, 30), [])
        this.RegionConArr.Push(this.EndColCon)

        PosX := 10
        PosY += 40
        this.ResultConArr := []
        Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 510, 100), GetLang("结果保存选项:"))
        this.ResultConArr.Push(Con)

        PosX := 20
        PosY += 20
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{} h30", PosX, PosY, 200), GetLang(
            "如果变量存在则不改变数值"))
        this.ResultConArr.Push(this.IsIgnoreExistCon)

        PosX := 20
        PosY += 40
        Con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("结果："))
        this.ResultConArr.Push(Con)

        PosX += 50
        this.SaveTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["变量",
            "数组"]))
        this.SaveTypeCon.Enabled := false
        this.ResultConArr.Push(this.SaveTypeCon)

        PosX += 105
        this.SaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
        this.ResultConArr.Push(this.SaveNameCon)

        PosY += 50
        PosX := 210
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{} Center", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.Gui.Hide())
        MyGui.Show(Format("w{} h{}", 535, 450))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("输入")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr()
        this.DLArrayArr := GetGuiArrNameArr()
        this.FileReadTypeArr := GetLangArr(["读取全部内容", "指定行", "逐行读取"])
        this.ExcelReadTypeArr := GetLangArr(["指定行", "指定列", "指定单元格", "指定区域"])
        ReadTypeArr := this.Data.Type == "文本文件" ? this.FileReadTypeArr : this.ExcelReadTypeArr

        this.TypeCon.Text := GetLang(this.Data.Type)
        this.EncodingCon.Text := GetShowEncoding(this.Data.Encoding)
        this.PauseTypeCon.Text := GetLang(this.Data.PauseType)
        this.CancelTypeCon.Text := GetLang(this.Data.CancelType)
        this.FilePathCon.Text := this.Data.FilePath
        this.SaveNameCon.Text := this.Data.SaveName
        this.ReadTypeCon.Add(ReadTypeArr)
        loop ReadTypeArr.Length {
            if (ReadTypeArr[A_Index] == GetLang(this.Data.ReadType)) {
                this.ReadTypeCon.Value := A_Index
                break
            }
        }
        SetDLConValue(this.FileRowCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.FileRow)
        SetDLConValue(this.NameOrSerialCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.NameOrSerial)
        SetDLConValue(this.RowCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.Row)
        SetDLConValue(this.ColCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.Col)
        SetDLConValue(this.EndRowCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.EndRow)
        SetDLConValue(this.EndColCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.EndCol)
    }

    OnRefreshType(*) {
        ReadTypeArr := []
        this.ReadTypeCon.Delete()
        if (this.ReadTypeMap.Has(this.TypeCon.Text)) {
            ReadTypeArr := this.ReadTypeMap[this.TypeCon.Text]
            this.ReadTypeCon.Add(ReadTypeArr)
            this.ReadTypeCon.Value := 1
        }
        this.RefreshConVisable()
    }

    OnRefreshReadType(*) {
        this.RefreshConVisable()
    }

    RefreshConVisable() {
        IsPopUp := this.TypeCon.Text == GetLang("弹窗")
        IsState := this.TypeCon.Text == GetLang("状态")
        IsFile := this.TypeCon.Text == GetLang("文本文件")
        IsExcel := this.TypeCon.Text == GetLang("Excel")
        IsGoOn := this.TypeCon.Text == GetLang("继续")
        IsGoOnAndCancel := this.TypeCon.Text == GetLang("继续&取消")

        IsFileGetAll := this.ReadTypeCon.Text == GetLang("读取全部内容")
        IsFileByLine := this.ReadTypeCon.Text == GetLang("逐行读取")
        IsFileGetLine := this.ReadTypeCon.Text == GetLang("指定行")

        IsExcelRow := this.ReadTypeCon.Text == GetLang("表格行")
        IsExcelCol := this.ReadTypeCon.Text == GetLang("表格列")
        IsExcelCell := this.ReadTypeCon.Text == GetLang("指定单元格")
        IsExcelRegion := this.ReadTypeCon.Text == GetLang("指定区域")

        HasEncoding := IsFile
        HasInter := IsPopUp || IsState || IsGoOn || IsGoOnAndCancel
        HasCancel := IsGoOnAndCancel
        HasFilePath := IsFile || IsExcel
        HasReadType := IsFile || IsExcel
        HasFileRow := IsFileByLine || IsFileGetLine
        HasExcel := IsExcel
        HasExcelRegion := IsExcelRegion
        HasRes := IsPopUp || IsState || IsFile || IsExcel
        ResOnlyVar := IsPopUp || IsState || IsFileGetAll || IsFileGetLine || IsExcelCell

        this.SetConArrVisible(this.EncodingConArr, HasEncoding)
        this.SetConArrVisible(this.InterConArr, HasInter)
        this.SetConArrVisible(this.CancelConArr, HasCancel)
        this.SetConArrVisible(this.FilePathConArr, HasFilePath)
        this.SetConArrVisible(this.ReadConArr, HasReadType)
        this.SetConArrVisible(this.FileRowConArr, HasFileRow)
        this.SetConArrVisible(this.ExcelConArr, HasExcel)
        this.SetConArrVisible(this.RegionConArr, HasExcelRegion)
        this.SetConArrVisible(this.ResultConArr, HasRes)

        this.SaveTypeCon.Text := ResOnlyVar ? GetLang("变量") : GetLang("数组")
        ResArr := ResOnlyVar ? this.DLVariableArr : this.DLArrayArr
        SetDLConValue(this.SaveNameCon, RemoveInVariable(ResArr, 1), this.SaveNameCon.Text)
    }

    SetConArrVisible(ConArr, Visible) {
        loop ConArr.Length {
            ConArr[A_Index].Visible := Visible
        }
    }

    OnSelectPathBtnClick() {
        path := FileSelect(1, , GetLang("选择输入的源文件"))
        this.FilePathCon.Value := path
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveData()
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        IsFile := this.TypeCon.Text == GetLang("文本文件")
        IsExcel := this.TypeCon.Text == GetLang("Excel")

        if ((IsFile || IsExcel) && this.FilePathCon.Text == "") {
            MsgBox("文件路径不能为空")
            return false
        }

        if (!CheckVarNameIfValid(this.SaveNameCon.Text))
            return false

        return true
    }

    TriggerMacro() {
        this.SaveData()
        CommandStr := this.GetCommandStr()
        OnTriggerSepcialItemMacro(CommandStr)

        Res := ""
        if (this.Data.SaveType == "变量" && MySoftData.VariableMap.Has(this.Data.SaveName))
            Res := MySoftData.VariableMap[this.Data.SaveName]
        if (this.Data.SaveType == "数组" && MySoftData.ArrayMap.Has(this.Data.SaveName))
            Res := GetArrayStr(MySoftData.ArrayMap[this.Data.SaveName])

        if (Res != "") {
            tip1 := Format(GetLang("变量：{}"), this.Data.SaveName)
            tip2 := Format(GetLang("值：{}"), Res)
            MsgBox(tip1 "`n" tip2)
        }
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        Remark := this.RemarkCon.Value
        if (Remark == "") {
            Remark := this.TypeCon.Text
        }
        CommandStr := CorrectRemark(CommandStr, Remark)
        return CommandStr
    }

    SaveData() {    
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        this.Data.Type := GetLangKey(this.TypeCon.Text)
        this.Data.Encoding := GetSoftEncoding(this.EncodingCon.Text)
        this.Data.PauseType := GetLangKey(this.PauseTypeCon.Text)
        this.Data.CancelType := GetLangKey(this.CancelTypeCon.Text)
        this.Data.FilePath := this.FilePathCon.Text
        this.Data.ReadType := GetLangKey(this.ReadTypeCon.Text)
        this.Data.FileRow := GetLangKey(this.FileRowCon.Text)
        this.Data.NameOrSerial := GetLangKey(this.NameOrSerialCon.Text)
        this.Data.Row := GetLangKey(this.RowCon.Text)
        this.Data.Col := GetLangKey(this.ColCon.Text)
        this.Data.EndRow := GetLangKey(this.EndRowCon.Text)
        this.Data.EndCol := GetLangKey(this.EndColCon.Text)
        this.Data.SaveType := GetLangKey(this.SaveTypeCon.Text)
        this.Data.SaveName := GetVarName(this.SaveNameCon.Text)

        if (this.SaveNameCon.Visible) {
            if (this.Data.SaveType == "变量")
                MySoftData.GlobalVariMap[this.Data.SaveName] := true
            if (this.Data.SaveType == "数组")
                MySoftData.GlobalArrMap[this.Data.SaveName] := true
        }
        SaveMacroCMDData(this.Data)
    }
}
