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
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 5, 180), GetLang("如果变量存在则不改变数值"))

        PosX := 10
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("类型："))

        PosX += 50
        this.TypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 110), GetLangArr(["创建", "取值"]))
        this.TypeCon.Value := 1
        this.TypeCon.OnEvent("Change", (*) => this.OnRefresh())

        PosX += 140
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 70, 20), GetLang("数组名："))

        PosX += 65
        this.NameCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R8", PosX, PosY - 5, 130), [])

        PosY += 30
        PosX := 200
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.Show(Format("w{} h{}", 500, 220))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("数组")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
    
        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        this.NameCon.Text := this.Data.Name
    }

    OnRefresh() {

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
    
        SaveMacroCMDData(this.Data)
    }
}
