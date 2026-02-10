#Requires AutoHotkey v2.0

class InputBtnGui {
    __new() {
        this.Gui := ""
        this.TrueAction := ""
        this.FalseAction := ""
        this.ContinueAction := ""
        this.CancelAction := ""
        this.HideAction := ""
    }
    ;1 真值 假值  2 继续  3 继续&取消
    ShowGui(Type) {
        PreviousActiveWindow := WinExist("A")
        if (this.Gui != "") {
            this.Gui.Show("NA")
        }
        else {
            this.AddGui()
        }
        this.Type := Type
        this.Init()
        WinActivate(PreviousActiveWindow)
    }

    AddGui() {
        MyGui := Gui("-Caption +AlwaysOnTop +ToolWindow", GetLang("状态选择"))
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)
        MyGui.BackColor := "EEAA99"
        WinSetTransColor("EEAA99", MyGui)
        this.Gui := MyGui
        PosX := 25
        PosY := 50
        this.ValueConArr := []
        TrueBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("真值"))
        TrueBtn.OnEvent("Click", this.OnTrueBtnClick.Bind(this))
        this.ValueConArr.Push(TrueBtn)

        PosX := 210
        FalseBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("假值"))
        FalseBtn.OnEvent("Click", this.OnTrueBtnClick.Bind(this))
        this.ValueConArr.Push(FalseBtn)

        PosX := 110
        PosY := 50
        this.ContinueConArr := []
        ContinueBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("继续"))
        ContinueBtn.OnEvent("Click", this.OnContinueBtnClick.Bind(this))
        this.ContinueConArr.Push(ContinueBtn)

        PosX := 25
        PosY := 50
        this.ContAndCancelConArr := []
        ContinueBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("继续"))
        ContinueBtn.OnEvent("Click", this.OnContinueBtnClick.Bind(this))
        this.ContAndCancelConArr.Push(ContinueBtn)

        PosX := 210
        CancelBtn := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("取消"))
        CancelBtn.OnEvent("Click", this.OnCancelBtnClick.Bind(this))
        this.ContAndCancelConArr.Push(CancelBtn)

        MyGui.Show(Format("w{} h{} NA", 300, 150))
    }

    Init() {
        loop this.ValueConArr.Length {
            this.ValueConArr[A_Index].Visible := this.Type == 1
        }

        loop this.ContinueConArr.Length {
            this.ContinueConArr[A_Index].Visible := this.Type == 2
        }

        loop this.ContAndCancelConArr.Length {
            this.ContAndCancelConArr[A_Index].Visible := this.Type == 3
        }
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

    OnContinueBtnClick(*) {
        this.OnContinue()
        this.OnHide()
        this.Gui.Hide()
    }

    OnCancelBtnClick(*) {
        this.OnCancel()
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

    OnContinue() {
        if (this.ContinueAction != "") {
            Action := this.ContinueAction
            Action()
            this.ContinueAction := ""
        }
    }

    OnCancel() {
        if (this.CancelAction != "") {
            Action := this.CancelAction
            Action()
            this.CancelAction := ""
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
