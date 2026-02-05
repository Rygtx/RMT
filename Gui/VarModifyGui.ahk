#Requires AutoHotkey v2.0

class VarModifyGui {
    __new() {
        this.Gui := ""
        this.ParentHwnd := ""
        this.SureAction := ""
    }

    ShowGui(Name, Value) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
            this.Gui.Opt("+Owner" this.ParentHwnd)
        }
        this.Value := Value
        this.NameCon.Text := Name
        this.ValueCon.Text := Value
    }

    AddGui() {
        MyGui := Gui(, GetLang("修改"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 5
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY,), GetLang("变量名："))
        PosX := 10
        PosY += 20
        this.NameCon := MyGui.Add("Text", Format("x{} y{} w260 h50", PosX, PosY), "")

        PosX := 10
        PosY += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("值："))
        PosY += 25
        this.ValueCon := MyGui.Add("Edit", Format("x{} y{} w260 h80", PosX, PosY), "")

        PosY += 90
        PosX := 90
        con := MyGui.Add("Button", Format("x{} y{} w100", PosX, PosY), GetLang("确定"))
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.Show(Format("w{} h{}", 280, 230))
    }

    OnSureBtnClick() {
        if (this.Value == this.ValueCon.Text) {
            return
        }

        action := this.SureAction
        action(this.NameCon.Text, this.ValueCon.Text)
        this.Gui.Hide()
    }
}
