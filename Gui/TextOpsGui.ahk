#Requires AutoHotkey v2.0

class TextOpsGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.RemarkCon := ""

        this.ArgsTypeMap := Map(
            GetLang("去除空格"), [
                GetLang("去除所有空格"),
                GetLang("去除前空白字符"),
                GetLang("去除后空白字符"),
                GetLang("去除所有空白字符")
            ],
            GetLang("大小写转换"), [
                GetLang("全部大写"),
                GetLang("全部小写"),
                GetLang("首字母大写"),
            ],
            GetLang("文本统计"), [
                GetLang("字符数"),
                GetLang("单词数"),
                GetLang("行数"),
            ],
            GetLang("内容提取"), [
                GetLang("数字提取"),
                GetLang("字母提取"),
                GetLang("中文提取"),
            ],
            GetLang("内容分割"), [
                GetLang("文本分割"),
                GetLang("定长分割"),
            ])
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
        MyGui := Gui(, this.ParentTile GetLang("文本处理编辑器"))
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
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY - 3, 75), GetLang("处理类型:"))
        PosX += 75
        TypeArr := GetLangArr(["内容分割", "文本替换", "内容提取", "去除空格", "大小写转换", "文本统计"])
        this.TypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 150), TypeArr)
        this.TypeCon.OnEvent("Change", this.OnRefresh.Bind(this))

        PosX := 275
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY - 3, 75), GetLang("文本来源:"))
        PosX += 75
        this.NameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 150), [])

        PosY += 30
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 510, 100), GetLang("处理参数"))

        ; 第一行：类型选项   类型参数
        PosY += 30
        PosX := 20
        this.ArgsTypeConTip := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("类型选项:"))
        PosX += 75
        this.ArgsTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 150), [])

        PosX := 275
        this.ArgsNameConTip := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("类型参数:"))
        PosX += 75
        this.ArgsNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 150), [])

        PosY += 35
        PosX := 20
        this.ReplaceConArr := []
        Con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("查找文本:"))
        this.ReplaceConArr.Push(Con)
        PosX += 75
        this.SearchCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 150), [])
        this.ReplaceConArr.Push(this.SearchCon)

        PosX := 275
        Con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("替换文本:"))
        this.ReplaceConArr.Push(Con)
        PosX += 75
        this.ReplaceCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 150), [])
        this.ReplaceConArr.Push(this.ReplaceCon)

        ;结果
        {
            PosX := 10
            PosY += 45
            MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 510, 100), GetLang("结果保存选项:"))

            PosX := 20
            PosY += 20
            this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{} h30", PosX, PosY, 200), GetLang(
                "如果变量存在则不改变数值"))

            PosX := 20
            PosY += 40
            this.ResultConArr := []
            Con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("结果："))
            this.ResultConArr.Push(Con)

            PosX += 50
            this.SaveTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["变量",
                "数组"]))
            this.SaveTypeCon.OnEvent("Change", this.OnRefreshDataType.Bind(this))
            this.SaveTypeCon.Enabled := false
            this.ResultConArr.Push(this.SaveTypeCon)

            PosX += 105
            this.SaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
            this.ResultConArr.Push(this.SaveNameCon)
        }

        PosY += 50
        PosX := 210
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{} Center", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.Gui.Hide())
        MyGui.Show(Format("w{} h{}", 535, 350))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("文本处理")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr()
        this.DLArrayArr := GetGuiArrNameArr()
        this.SimpleDLVariableArr := RemoveInVariable(this.DLVariableArr, 1)

        this.TypeCon.Text := GetLangKey(this.Data.Type)
        SetDLConValue(this.NameCon, this.SimpleDLVariableArr, this.Data.Name)
        SetDLConValue(this.ArgsNameCon, this.DLVariableArr, this.Data.ArgsName)

        SetDLConValue(this.SearchCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.Search)
        SetDLConValue(this.ReplaceCon, RemoveInVariable(this.DLVariableArr, 2), this.Data.Replace)

        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        this.SaveTypeCon.Text := GetLang(this.Data.SaveType)
        this.SaveNameCon.Text := this.Data.SaveName
    }

    OnRefresh(*) {
        IsSplit := this.TypeCon.Text == GetLang("内容分割")
        IsReplace := this.TypeCon.Text == GetLang("文本替换")
        IsGetEx := this.TypeCon.Text == GetLang("内容提取")
        IsSpace := this.TypeCon.Text == GetLang("去除空格")
        IsUpLow := this.TypeCon.Text == GetLang("大小写转换")
        IsStatistics := this.TypeCon.Text == GetLang("文本统计")

        ArgsDLArr := []
        this.ArgsTypeCon.Delete()
        if (this.ArgsTypeMap.Has(this.TypeCon.Text)) {
            ArgsDLArr := this.ArgsTypeMap[this.TypeCon.Text]
            this.ArgsTypeCon.Add(ArgsDLArr)
            this.ArgsTypeCon.Value := 1

            loop ArgsDLArr.Length {
                if (ArgsDLArr[A_Index] == GetLang(this.Data.ArgsType)) {
                    this.ArgsTypeCon.Text := GetLang(this.Data.ArgsType)
                    break
                }
            }
        }

        ShowArgsType := IsUpLow || IsSpace || IsStatistics
        ShowArgsName := IsSplit
        this.ArgsTypeConTip.Enabled := ShowArgsType
        this.ArgsTypeCon.Enabled := ShowArgsType
        this.ArgsNameConTip.Enabled := ShowArgsName
        this.ArgsNameCon.Enabled := ShowArgsName
        loop this.ReplaceConArr.Length {
            this.ReplaceConArr[A_Index].Enabled := IsReplace
        }

        OnlyResVar := IsReplace || IsSpace || IsUpLow || IsStatistics
        OnlyResArr := IsSplit || IsGetEx
        this.SaveTypeCon.Value := OnlyResVar ? 1 : 2
        this.OnRefreshDataType()
    }

    OnRefreshDataType(*) {
        IsResVar := this.SaveTypeCon.Text == GetLang("变量")
        ResArr := IsResVar ? this.DLVariableArr : this.DLArrayArr
        SetDLConValue(this.SaveNameCon, RemoveInVariable(ResArr, 1), this.SaveNameCon.Text)
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveTextOpsData()
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        if (this.TypeCon.Text == GetLang("文本替换")) {
            if (this.SearchCon.Text == "" || this.ReplaceCon.Text == "") {
                MsgBox(GetLang("搜索文本和替换文本不能为空"))
                return false
            }
        }

        if (this.TypeCon.Text == GetLang("内容分割")) {
            if (this.ArgsNameCon.Text == "") {
                MsgBox(GetLang("类型参数不能为空"))
                return false
            }
        }

        if (IsNumber(this.SaveNameCon.Text)) {
            MsgBox(GetLang("结果变量名不规范：变量名不能是纯数字"))
            return false
        }
        return true
    }

    TriggerMacro() {
        this.SaveTextOpsData()
        CommandStr := this.GetCommandStr()
        tableItem := MySoftData.SpecialTableItem
        tableItem.KilledArr[1] := false
        tableItem.PauseArr[1] := 0
        tableItem.ActionCount[1] := 0
        tableItem.VariableMapArr[1] := Map()
        tableItem.index := 1

    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    SaveTextOpsData() {
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        this.Data.Type := GetLangKey(this.TypeCon.Text)
        this.Data.Name := this.NameCon.Text
        this.Data.ArgsType := GetLangKey(this.ArgsTypeCon.Text)
        this.Data.ArgsName := GetLangKey(this.ArgsNameCon.Text)
        this.Data.Search := GetLangKey(this.SearchCon.Text)
        this.Data.Replace := GetLangKey(this.ReplaceCon.Text)
        this.Data.SaveType := GetLangKey(this.SaveTypeCon.Text)
        this.Data.SaveName := this.SaveNameCon.Text

        if (this.Data.SaveType == "变量")
            MySoftData.GlobalVariMap[this.Data.SaveName] := true
        if (this.Data.SaveType == "数组")
            MySoftData.GlobalArrMap[this.Data.SaveName] := true
        SaveMacroCMDData(this.Data)
    }
}
