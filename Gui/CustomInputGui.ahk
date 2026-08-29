#Requires AutoHotkey v2.0

; Worker 侧通知回调（Worker 启动时赋值；主进程保持为空，避免引用 Worker 专有函数 MsgSendHandler）
global MyInputPopUpNotify := ""

; 通知主进程输入弹窗的显示/隐藏状态（显示期间暂时禁用 Enter 触发键；Worker 通过 IPC 同步到主进程）
NotifyInputPopUpState(state) {
    if (MySoftData.isWorker) {
        if (MyInputPopUpNotify != "")
            MyInputPopUpNotify.Call(state)
    }
    else
        MySoftData.InputPopUpShowing := state
}

class CustomInputGui {
    __new() {
        this.Gui := ""
        this.HideAction := ""
        this.SureAction := ""
        this.CloseAction := ""
    }

    ShowGui(Label) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
        this.LabelCon.Value := Label
        this.ContentCon.Value := ""     ; 清除上次文本
        this.ContentCon.Focus()          ; 自动获取焦点，方便输入信息
        NotifyInputPopUpState(true)      ; 显示期间暂时禁用 Enter 触发键
    }

    AddGui() {
        MyGui := Gui(, GetLang("输入弹窗"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MainSoftData.FontType)

        PosX := 10
        PosY := 15
        this.LabelCon := MyGui.Add("Text", Format("x{} y{} w350", PosX, PosY), "变量名：Data")

        PosX := 10
        PosY += 30
        this.ContentCon := MyGui.Add("Edit", Format("x{} y{} w350 h150", PosX, PosY), "")

        PosY += 160
        PosX += 130
        con := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("确定"))
        con.OnEvent("Click", this.OnSureBtnClick.Bind(this))
        MyGui.OnEvent("Close", this.OnCloseBtnClick.Bind(this))

        pos := GetCenterPosOnActiveMonitor(365, 250)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 365, 250))
    }

    OnSureBtnClick(*) {
        this.OnSure()
        this.OnHide()
        this.Gui.Hide()
    }

    OnCloseBtnClick(*) {
        this.OnClose()
        this.OnHide()
    }

    OnSure() {
        if (this.SureAction != "") {
            Action := this.SureAction
            Action(this.ContentCon.Text)
            this.SureAction := ""
        }
    }

    OnClose() {
        if (this.CloseAction != "") {
            Action := this.CloseAction
            Action()
            this.CloseAction := ""
        }
    }

    OnHide() {
        NotifyInputPopUpState(false)     ; 弹窗关闭后恢复 Enter 触发键
        if (this.HideAction != "") {
            Action := this.HideAction
            Action()
            this.HideAction := ""
        }
    }
}
