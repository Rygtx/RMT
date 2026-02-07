#Requires AutoHotkey v2.0

class InputStateGui {
    __new() {
        this.Gui := ""
        this.TrueAction := ""
        this.FalseAction := ""
        this.HideAction := ""
    }

    ShowGui() {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
    }

    AddGui() {
        MyGui := Gui("-Caption +AlwaysOnTop +ToolWindow", GetLang("状态选择"))
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)
        MyGui.BackColor := "EEAA99"
        WinSetTransColor("EEAA99", MyGui)
        this.Gui := MyGui
        PosX := 25
        PosY := 50
        TrueBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("真值"))
        TrueBtn.OnEvent("Click", this.OnTrueBtnClick.Bind(this))

        PosX := 210
        FalseBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("假值"))
        FalseBtn.OnEvent("Click", this.OnTrueBtnClick.Bind(this))

        MyGui.Show(Format("w{} h{}", 300, 150))
    }

    OnTrueBtnClick(*) {
        this.OnTrue()
        this.OnHide()
        this.Gui.Hide()
    }

    OnFalseBtnClick(*) {
        this.OnFalse()
        this.OnHide()
        this.Gui.Hide()
    }

    OnTrue() {
        if (this.TrueAction != "") {
            Action := this.TrueAction
            Action()
            this.TrueAction := ""
        }
    }

    OnFalse() {
        if (this.FalseAction != "") {
            Action := this.FalseAction
            Action()
            this.FalseAction := ""
        }
    }

    OnHide() {
        if (this.HideAction != "") {
            Action := this.HideAction
            Action()
            this.HideAction := ""
        }
    }
}
