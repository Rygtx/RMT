#Requires AutoHotkey v2.0

class ArrayGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
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
        MyGui := Gui(, this.ParentTile GetLang("数组编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX += 200
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 5, 180), GetLang(
            "如果变量存在则不改变数据"))

        PosX := 20
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("类型："))

        PosX += 50
        this.TypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["创建", "取值"]))
        this.TypeCon.Value := 1
        this.TypeCon.OnEvent("Change", this.OnRefresh.Bind(this))

        PosX += 125
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("数组名："))
        PosX += 65
        this.NameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R8", PosX, PosY - 5, 100), [])

        PosX += 120
        this.MainIndexConArr := []
        Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("子索引："))
        this.MainIndexConArr.Push(Con)
        PosX += 65
        this.MainIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 90), ["0"])
        this.MainIndexConArr.Push(this.MainIndexCon)
        PosX += 95
        Con := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 7, 25), "?")
        Con.OnEvent("Click", this.OnClickIndexHelpBtn.Bind(this))
        this.MainIndexConArr.Push(Con)

        PosY += 35
        SplitPosY := PosY

        ;创建参数
        {
            PosX := 10
            PosY := SplitPosY
            this.CreateConArr := []
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 150), GetLang("创建参数"))
            this.CreateConArr.Push(Con)

            PosX := 20
            PosY += 25
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("初始数据："))
            this.CreateConArr.Push(Con)
            PosX += 75
            this.InitArrCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 400), "1, 2, 3")
            this.CreateConArr.Push(this.InitArrCon)
            PosX += 405
            Con := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 7, 25), "?")
            Con.OnEvent("Click", this.OnClickInitHelpBtn.Bind(this))
            this.CreateConArr.Push(Con)
        }

        ;取值参数
        {
            PosX := 10
            PosY := SplitPosY
            this.GetConArr := []
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 150), GetLang("取值参数"))
            this.GetConArr.Push(Con)

            PosX := 20
            PosY += 25
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("索引："))
            this.GetConArr.Push(Con)
            PosX += 50
            this.GetIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
            this.GetConArr.Push(this.GetIndexCon)

            PosX += 125
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("默认值："))
            this.GetConArr.Push(Con)
            PosX += 65
            this.GetDefaultCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
            this.GetConArr.Push(this.GetDefaultCon)
        }
        ;结果
        {
            PosX := 20
            PosY := 270
            this.ResultConArr := []
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 550, 50), GetLang("结果："))
            this.ResultConArr.Push(Con)

            PosX += 50
            this.SaveTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["变量",
                "数组"]))
            this.SaveTypeCon.Value := 1
            this.SaveTypeCon.OnEvent("Change", this.OnSaveTypeChange.Bind(this))
            this.ResultConArr.Push(this.SaveTypeCon)

            PosX += 105
            this.SaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
            this.ResultConArr.Push(this.SaveNameCon)
        }

        PosY := 300
        PosX := 240
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.Show(Format("w{} h{}", 580, 350))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("数组")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)

        this.TypeCon.Text := GetLang(this.Data.Type)
        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        this.NameCon.Delete()
        ; this.NameCon.Add(RemoveInVariable(this.VariableObjArr, 2))    ;todo这是数组名，不是变量名
        this.NameCon.Text := this.Data.Name
        this.MainIndexCon.Delete()
        this.MainIndexCon.Add(RemoveInVariable(this.VariableObjArr, 2))
        this.MainIndexCon.Text := this.Data.MainIndex

        this.InitArrCon.Text := GetArrayStr(this.Data.InitArr)

        this.GetIndexCon.Delete()
        this.GetIndexCon.Add(RemoveInVariable(this.VariableObjArr, 2))
        this.GetIndexCon.Text := this.Data.GetIndex
        this.GetDefaultCon.Delete()
        this.GetDefaultCon.Add(RemoveInVariable(this.VariableObjArr, 2))
        this.GetDefaultCon.Text := this.Data.GetDefault

        this.SaveTypeCon.Text := GetLang(this.Data.SaveType)
        this.SaveNameCon.Text := this.Data.SaveName
    }

    OnRefresh(*) {
        IsCreate := this.TypeCon.Text == GetLang("创建")
        IsGet := this.TypeCon.Text == GetLang("取值")

        loop this.MainIndexConArr.Length {
            this.MainIndexConArr[A_Index].Visible := IsGet
        }
        loop this.CreateConArr.Length {
            this.CreateConArr[A_Index].Visible := IsCreate
        }
        loop this.GetConArr.Length {
            this.GetConArr[A_Index].Visible := IsGet
        }
        loop this.ResultConArr.Length {
            this.ResultConArr[A_Index].Visible := IsGet
        }
    }

    OnSaveTypeChange(*) {
        if (this.SaveTypeCon.Value == 1) {
            this.SaveNameCon.Text := this.NameCon.Text
            if (this.MainIndexCon.Text != 0)
                this.SaveNameCon.Text .= "-" this.MainIndexCon.Text

            this.SaveNameCon.Text .= "-" this.GetIndexCon.Text
        }
        else if (this.SaveTypeCon.Value == 2) {
            this.SaveNameCon.Text := "NewArr"
        }
    }

    OnClickIndexHelpBtn(*) {
        str1 := "数组支持二维，该参数可控制数组或子数组进行调度"
        str2 := '一维数组时，保持默认值0即可'
        str3 := "0. 数组本身"
        str4 := 'N. 对应索引的子数组'
        MsgBox(Format("{}`n{}`n{}`n{}", str1, str2, str3, str4))
    }

    OnClickInitHelpBtn(*) {
        str1 := "1. 逗号分割数据"
        str2 := "案例数据：1,2,文本,4"
        str3 := '数组-1=1、数组-2=2、数组-3="文本"、数组-4=4'
        str4 := "2. 中括号表示数组数据"
        str5 := '案例数据：1,"文本",[2, 5, 7],8'
        str6 := '数组-1=1、数组-2="文本"、数组-3=2, 5, 7、数组-4=8'
        str7 := "3. 数据中使用\符号，表示原本的功能"
        str8 := "案例数据1,我的\,世界,\[若梦兔\],4"
        str9 := '数组-1=1、数组-2="我的,世界"、数组-3="[若梦兔]"、数组-4=4'
        MsgBox(Format("{}`n{}`n{}`n{}`n{}`n{}`n{}`n{}`n{}", str1, str2, str3, str4, str5, str6, str7, str8, str9))
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveSubMacroData()
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        return true
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    SaveSubMacroData() {
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        this.Data.Name := this.NameCon.Text
        this.Data.InitArr := GetArray(this.InitArrCon.Text)
        SaveMacroCMDData(this.Data)
    }
}
