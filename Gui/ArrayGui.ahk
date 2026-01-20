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
        this.TypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["创建", "克隆",
            "取值",
            "赋值", "插入", "追加","长度"]))
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
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 100), GetLang("创建参数"))
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
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 100), GetLang("取值参数"))
            this.GetConArr.Push(Con)

            PosX := 20
            PosY += 25
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("索引："))
            this.GetConArr.Push(Con)
            PosX += 50
            this.GetIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
            this.GetConArr.Push(this.GetIndexCon)
        }
        ;赋值
        {
            PosX := 10
            PosY := SplitPosY
            this.SetConArr := []
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 100), GetLang("赋值参数"))
            this.SetConArr.Push(Con)

            PosX := 20
            PosY += 25
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("索引："))
            this.SetConArr.Push(Con)
            PosX += 50
            this.SetIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
            this.SetConArr.Push(this.SetIndexCon)

            PosX += 125
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("数据："))
            this.SetConArr.Push(Con)
            PosX += 50
            this.SetTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["变量或值",
                "数组"]))
            this.SetTypeCon.OnEvent("Change", this.OnRefreshDataType.Bind(this))
            this.SetConArr.Push(this.SetTypeCon)

            PosX += 105
            this.SetNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
            this.SetConArr.Push(this.SetNameCon)
        }

        ;插入
        {
            PosX := 10
            PosY := SplitPosY
            this.InsertConArr := []
            Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 100), GetLang("插入参数"))
            this.InsertConArr.Push(Con)

            PosX := 20
            PosY += 25
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("索引："))
            this.InsertConArr.Push(Con)
            PosX += 50
            this.InsertIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
            this.InsertConArr.Push(this.InsertIndexCon)

            PosX += 125
            Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("数据："))
            this.InsertConArr.Push(Con)
            PosX += 50
            this.InsertTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr([
                "变量或值",
                "数组"]))
            this.InsertTypeCon.OnEvent("Change", this.OnRefreshDataType.Bind(this))
            this.InsertConArr.Push(this.InsertTypeCon)

            PosX += 105
            this.InsertNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
            this.InsertConArr.Push(this.InsertNameCon)
        }

        ; ;追加
        ; {
        ;     PosX := 10
        ;     PosY := SplitPosY
        ;     this.InsertConArr := []
        ;     Con := MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 100), GetLang("插入参数"))
        ;     this.InsertConArr.Push(Con)

        ;     PosX := 20
        ;     PosY += 25
        ;     Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("索引："))
        ;     this.InsertConArr.Push(Con)
        ;     PosX += 50
        ;     this.InsertIndexCon := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 5, 100), [0])
        ;     this.InsertConArr.Push(this.InsertIndexCon)

        ;     PosX += 125
        ;     Con := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("数据："))
        ;     this.InsertConArr.Push(Con)
        ;     PosX += 50
        ;     this.InsertTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr([
        ;         "变量或值",
        ;         "数组"]))
        ;     this.InsertTypeCon.OnEvent("Change", this.OnRefreshDataType.Bind(this))
        ;     this.InsertConArr.Push(this.InsertTypeCon)

        ;     PosX += 105
        ;     this.InsertNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
        ;     this.InsertConArr.Push(this.InsertNameCon)
        ; }

        ;结果
        {
            PosX := 20
            PosY := 200
            this.ResultConArr := []
            Con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("结果："))
            this.ResultConArr.Push(Con)

            PosX += 50
            this.SaveTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 100), GetLangArr(["变量",
                "数组"]))
            this.ResultConArr.Push(this.SaveTypeCon)

            PosX += 105
            this.SaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX, PosY - 5, 100), [])
            this.ResultConArr.Push(this.SaveNameCon)
        }

        PosY := 230
        PosX := 240
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.Show(Format("w{} h{}", 580, 280))
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

        this.SetIndexCon.Delete()
        this.SetIndexCon.Add(RemoveInVariable(this.VariableObjArr, 2))
        this.SetIndexCon.Text := this.Data.SetIndex
        this.SetTypeCon.Text := this.Data.SetType
        this.SetNameCon.Text := this.Data.SetName

        this.InsertIndexCon.Delete()
        this.InsertIndexCon.Add(RemoveInVariable(this.VariableObjArr, 2))
        this.InsertIndexCon.Text := this.Data.InsertIndex
        this.InsertTypeCon.Text := this.Data.InsertType
        this.InsertNameCon.Text := this.Data.InsertName

        this.SaveTypeCon.Text := GetLang(this.Data.SaveType)
        this.SaveNameCon.Text := this.Data.SaveName
    }

    OnRefresh(*) {
        IsCreate := this.TypeCon.Text == GetLang("创建")
        IsClone := this.TypeCon.Text == GetLang("克隆")
        IsGet := this.TypeCon.Text == GetLang("取值")
        IsSetValue := this.TypeCon.Text == GetLang("赋值")
        IsInsert := this.TypeCon.Text == GetLang("插入")
        IsAdd := this.TypeCon.Text == GetLang("追加")
        IsLength := this.TypeCon.Text == GetLang("长度")
        OnlyResVar := IsLength
        OnlyResArr := IsClone

        this.IsIgnoreExistCon.Visible := IsCreate || IsClone || IsGet || IsLength
        this.SetConArrVisible(this.MainIndexConArr, IsGet || IsLength || IsSetValue || IsClone || IsInsert)
        this.SetConArrVisible(this.CreateConArr, IsCreate)
        this.SetConArrVisible(this.GetConArr, IsGet)
        this.SetConArrVisible(this.SetConArr, IsSetValue)
        this.SetConArrVisible(this.InsertConArr, IsInsert)
        this.SetConArrVisible(this.ResultConArr, IsGet || IsLength || IsClone)

        if (OnlyResVar || OnlyResArr) {
            this.SaveTypeCon.Value := OnlyResVar ? 1 : 2
            this.SaveTypeCon.Enabled := false
        }
        else {
            this.SaveNameCon.Enabled := true
        }
    }

    SetConArrVisible(ConArr, isVisible) {
        loop ConArr.Length {
            ConArr[A_Index].Visible := isVisible
        }
    }

    OnRefreshDataType(*) {

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
