#Requires AutoHotkey v2.0

class RunGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.RemarkCon := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this.PathTextCon := ""
        this.VariCon := ""
        this.VariTipCon := ""
        this.RunModeCon := ""
        this.SaveNameConArr := []
        this.SaveNameTipConArr := []
        this.HideCon := ""
        this.StdInCon := ""
        this.StdInTipCon := ""
        this.StdInEditBtnCon := ""
        this.StdOutTipCon := ""
        this.ActiveEdit := ""

        this.StdInText := ""
        this.StdInEditGui := ""
        this.StdInEditCon := ""
        this.StdInEditVariCon := ""

        this.Data := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            if (this.OwnerHwnd != "") {
                this.Gui.Opt("+Owner" this.OwnerHwnd)
            }
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
            }
        }

        this.Init(cmd)
        this.ToggleFunc(true)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("运行编辑器"))
        this.Gui := MyGui
        if (this.OwnerHwnd != "") {
            MyGui.Opt("+Owner" this.OwnerHwnd)
        }
        MyGui.SetFont("S10 W550 Q2", MainSoftData.FontType)

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
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("模式："))

        PosX += 40
        ModeArr := [GetLang("不等待"), GetLang("等待+返回值"), GetLang("等待+輸入输出")]
        this.RunModeCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R3", PosX, PosY - 3, 110), ModeArr)
        this.RunModeCon.OnEvent("Change", (*) => this.OnModeChange())

        PosX += 120
        this.HideCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("隐藏窗口"))

        PosY += 35
        PosX := 10
        this.VariTipCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 150), GetLang("变量："))

        PosX += 40
        this.VariCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R5", PosX, PosY - 3, 110), [])

        PosX += 120
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 60, 25), GetLang("追加名"))
        btnCon.OnEvent("Click", (*) => this.OnClickAddVarNameBtn())

        PosX += 70
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 60, 25), GetLang("追加值"))
        btnCon.OnEvent("Click", (*) => this.OnClickAddVarValueBtn())

        PosX := 10
        PosY += 35
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("目标："))

        PosX += 40
        this.PathTextCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 3, 450))
        this.PathTextCon.OnEvent("Focus", (*) => this.ActiveEdit := this.PathTextCon)

        PosX += 455
        btnCon := MyGui.Add("Button", Format("x{} y{}", PosX, PosY - 5), GetLang("选择文件"))
        btnCon.OnEvent("Click", (*) => this.OnClickFileSelectBtn())

        PosY += 35
        PosX := 10
        this.StdOutTipCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("输出："))
        PosX += 40
        tip1 := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("返回值"))
        this.SaveNameTipConArr.Push(tip1)
        PosX += 40
        con1 := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 3, 100), [])
        this.SaveNameConArr.Push(con1)

        PosX += 110
        tip2 := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 40), GetLang("输出"))
        this.SaveNameTipConArr.Push(tip2)
        PosX += 40
        con2 := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 3, 100), [])
        this.SaveNameConArr.Push(con2)

        PosX += 110
        tip3 := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 40), GetLang("错误"))
        this.SaveNameTipConArr.Push(tip3)
        PosX += 40
        con3 := MyGui.Add("ComboBox", Format("x{} y{} w{}", PosX, PosY - 3, 100), [])
        this.SaveNameConArr.Push(con3)

        PosY += 30
        PosX := 10
        this.StdInTipCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 2, 50), GetLang("输入："))
        PosX += 40
        this.StdInCon := MyGui.Add("Edit", Format("x{} y{} w{} h{} Multi VScroll WantReturn", PosX, PosY - 1, 390, 60), "")
        this.StdInCon.OnEvent("Focus", (*) => this.ActiveEdit := this.StdInCon)

        PosX += 400
        this.StdInEditBtnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 1, 100, 60), GetLang("编辑"))
        this.StdInEditBtnCon.OnEvent("Click", (*) => this.OpenStdInEditor())
        this.StdInCon.OnEvent("Change", (*) => this.OnStdInOuterChange())

        PosY += 70
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("支持启动程序（如.exe、.bat）、打开文件（如.txt、.mp4）或网址等等"))

        PosY += 35
        PosX := 240
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.OnGuiClose())
        pos := GetCenterPosOnActiveMonitor(580, 350)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 580, 350))
    }

    OnStdInOuterChange() {
        if (this.StdInCon == "")
            return
        this.StdInText := this.StdInCon.Value
        if (this.StdInEditGui != "") {
            this.StdInEditCon.Value := this.StdInText
        }
    }

    OnModeChange() {
        val := this.RunModeCon.Value
        if (val == 1) {
            this.StdOutTipCon.Visible := false
            loop 3 {
                this.SaveNameTipConArr[A_Index].Visible := false
                this.SaveNameConArr[A_Index].Visible := false
            }
            this.StdInTipCon.Visible := false
            this.StdInCon.Visible := false
            this.StdInEditBtnCon.Visible := false
        } else if (val == 2) {
            this.StdOutTipCon.Visible := true
            this.SaveNameTipConArr[1].Visible := true
            this.SaveNameConArr[1].Visible := true
            loop 2 {
                this.SaveNameTipConArr[A_Index + 1].Visible := false
                this.SaveNameConArr[A_Index + 1].Visible := false
            }
            this.StdInTipCon.Visible := false
            this.StdInCon.Visible := false
            this.StdInEditBtnCon.Visible := false
        } else {
            this.StdOutTipCon.Visible := true
            loop 3 {
                this.SaveNameTipConArr[A_Index].Visible := true
                this.SaveNameConArr[A_Index].Visible := true
            }
            this.StdInTipCon.Visible := true
            this.StdInCon.Visible := true
            this.StdInEditBtnCon.Visible := true
        }
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("运行")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)

        this.PathTextCon.Value := this.Data.Target

        DLVariableArr := GetGuiVarArr(1)
        this.VariCon.Delete()
        this.VariCon.Add(DLVariableArr)
        this.VariCon.Value := 1

        this.RunModeCon.Value := this.Data.Mode
        this.HideCon.Value := ObjHasOwnProp(this.Data, "Hide") ? this.Data.Hide : false
        this.StdInText := ObjHasOwnProp(this.Data, "StdIn") ? this.Data.StdIn : ""
        this.UpdateStdInPreview()

        loop 3 {
            this.SaveNameConArr[A_Index].Delete()
            this.SaveNameConArr[A_Index].Add(GetGuiVarArr(0))
            if (ObjHasOwnProp(this.Data, "SaveNameArr") && this.Data.SaveNameArr.Length >= A_Index)
                this.SaveNameConArr[A_Index].Text := this.Data.SaveNameArr[A_Index]
            else
                this.SaveNameConArr[A_Index].Text := (A_Index == 1 ? "ExitCode" : (A_Index == 2 ? "StdOut" : "StdErr"))
        }
        this.OnModeChange()
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        commandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        commandStr := CorrectRemark(commandStr, this.RemarkCon.Value)
        return commandStr
    }

    ToggleFunc(state) {
        MacroAction := (*) => this.TriggerMacro()
        Hotkey("!l", MacroAction, state ? "On" : "Off")
    }

    OnClickFileSelectBtn() {
        fileString := FileSelect("S1", "", GetLang("选择要运行的文件"))
        if (fileString == "")
            return

        this.PathTextCon.Value := fileString
    }

    OpenStdInEditor() {
        if (this.StdInEditGui == "") {
            this.AddStdInEditorGui()
        }

        if (this.OwnerHwnd != "") {
            this.StdInEditGui.Opt("+Owner" this.OwnerHwnd)
        }
        this.StdInEditVariCon.Delete()
        this.StdInEditVariCon.Add(GetGuiVarArr(1))
        this.StdInEditVariCon.Value := 1
        this.StdInEditCon.Value := this.StdInText
        this.StdInEditGui.Show()
        try this.StdInEditGui.Activate()
    }

    AddStdInEditorGui() {
        MyGui := Gui(, this.ParentTile GetLang("输入编辑器"))
        this.StdInEditGui := MyGui

        if (this.OwnerHwnd != "") {
            MyGui.Opt("+Owner" this.OwnerHwnd)
        }
        MyGui.SetFont("S10 W550 Q2", MainSoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 2, 50), GetLang("变量："))

        PosX += 40
        this.StdInEditVariCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R6", PosX, PosY - 1, 130), [])
        this.StdInEditVariCon.Add(GetGuiVarArr(1))
        this.StdInEditVariCon.Value := 1

        PosX += 140
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 1, 70, 25), GetLang("追加名"))
        btnCon.OnEvent("Click", (*) => this.OnClickStdInEditorAddVarNameBtn())

        PosX += 80
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 1, 70, 25), GetLang("追加值"))
        btnCon.OnEvent("Click", (*) => this.OnClickStdInEditorAddVarValueBtn())

        PosX := 10
        PosY += 35
        this.StdInEditCon := MyGui.Add("Edit", Format("x{} y{} w{} h{} Multi VScroll WantReturn", PosX, PosY, 680, 300), this.StdInText)
        this.StdInEditCon.OnEvent("Focus", (*) => this.ActiveEdit := this.StdInEditCon)
        this.StdInEditCon.OnEvent("Change", (*) => this.OnStdInEditChange())

        btnOk := MyGui.Add("Button", "x330 y350 w90 h30", GetLang("确定"))
        btnOk.OnEvent("Click", (*) => this.OnClickStdInEditorOk())

        MyGui.OnEvent("Close", (*) => this.OnClickStdInEditorClose())
        MyGui.Show("w700 h395")
    }

    OnStdInEditChange() {
        if (this.StdInEditCon != "") {
            this.StdInText := this.StdInEditCon.Value
            this.UpdateStdInPreview()
        }
    }

    OnClickStdInEditorAddVarNameBtn() {
        if (this.StdInEditCon == "")
            return

        SendMessage(0x00C2, true, StrPtr(this.StdInEditVariCon.Text), this.StdInEditCon.Hwnd)
        this.OnStdInEditChange()
    }

    OnClickStdInEditorAddVarValueBtn() {
        if (this.StdInEditCon == "")
            return

        if (this.StdInEditVariCon.Text != "") {
            SendMessage(0x00C2, true, StrPtr("{" this.StdInEditVariCon.Text "}"), this.StdInEditCon.Hwnd)
            this.OnStdInEditChange()
        }
    }

    OnClickStdInEditorOk() {
        this.OnStdInEditChange()
        this.StdInEditGui.Hide()
    }

    OnClickStdInEditorClose() {
        if (this.StdInEditGui != "") {
            this.StdInEditGui.Hide()
        }
    }

    UpdateStdInPreview() {
        if (this.StdInCon == "")
            return

        previewText := this.StdInText
        if (previewText == "")
            previewText := GetLang("（空）")

        this.StdInCon.Value := previewText
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveRunData()
        this.ToggleFunc(false)
        action := this.SureBtnAction
        action(this.GetCommandStr())

        if (this.StdInEditGui != "") {
            this.StdInEditGui.Hide()
        }

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    OnGuiClose() {
        this.ToggleFunc(false)

        if (this.StdInEditGui != "") {
            this.StdInEditGui.Hide()
        }

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    CheckIfValid() {
        if (this.PathTextCon.Value == "") {
            MsgBox(GetLang("目标不能为空！"))
            return false
        }
        return true
    }

    TriggerMacro() {
        this.SaveRunData()
        OnTriggerSepcialItemMacro(this.GetCommandStr())
    }

    SaveRunData() {
        this.Data.Target := GetLangStr(this.PathTextCon.Value, 2)
        this.Data.Mode := this.RunModeCon.Value
        this.Data.Hide := this.HideCon.Value ? true : false

        if (this.Data.Mode == 1) {
            this.Data.DeleteProp("StdIn")
            this.Data.DeleteProp("SaveNameArr")
        } else if (this.Data.Mode == 2) {
            this.Data.DeleteProp("StdIn")
            this.Data.SaveNameArr := [this.SaveNameConArr[1].Text]
        } else if (this.Data.Mode == 3) {
            this.Data.StdIn := this.StdInText
            this.Data.SaveNameArr := [this.SaveNameConArr[1].Text, this.SaveNameConArr[2].Text, this.SaveNameConArr[3].Text]
        }

        SaveMacroCMDData(this.Data)
    }

    OnClickAddVarNameBtn() {
        targetCon := (this.ActiveEdit != "" && this.ActiveEdit.Visible) ? this.ActiveEdit : this.PathTextCon
        if (targetCon && targetCon.Hwnd)
            this.InsertIntoEdit(targetCon, this.VariCon.Text)
    }

    OnClickAddVarValueBtn() {
        if (this.VariCon.Text != "") {
            targetCon := (this.ActiveEdit != "" && this.ActiveEdit.Visible) ? this.ActiveEdit : this.PathTextCon
            if (targetCon && targetCon.Hwnd)
                this.InsertIntoEdit(targetCon, "{" this.VariCon.Text "}")
        }
    }

    InsertIntoEdit(editCon, text) {
        SendMessage(0x00C2, true, StrPtr(text), editCon.Hwnd) ; EM_REPLACESEL
    }
}