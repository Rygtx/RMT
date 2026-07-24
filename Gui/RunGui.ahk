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
        this.OptionCon := ""
        this.StdInCon := ""
        this.StdInTipCon := ""
        this.StdInEditBtnCon := ""
        this.StdOutTipCon := ""
        this.ActiveEdit := ""

        this.StdInEditGui := ""
        this.StdInEditCon := ""
        this.StdInEditVariCon := ""

        this.EncInCon := ""
        this.EncOutCon := ""
        this.EncErrCon := ""
        this.EncInTextCon := ""
        this.EncOutTextCon := ""
        this.EncErrTextCon := ""

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
        ModeArr := [GetLang("不等待"), GetLang("等待+返回值"), GetLang("不等待+输入"), GetLang("等待+输入输出")]
        this.RunModeCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R4", PosX, PosY - 3, 110), ModeArr)
        this.RunModeCon.OnEvent("Change", (*) => this.OnModeChange())

        PosX += 120
        Options := ["Hide", "", "Min", "Max"]
        this.OptionCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R4", PosX, PosY - 3, 50), Options)

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
        this.ActiveEdit := this.PathTextCon

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
        encArr := ["UTF-8", "UTF-16", "CP0"]
        this.EncInTextCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 2, 70), GetLang("输入编码："))
        PosX += 70
        this.EncInCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R6", PosX, PosY - 1, 90), encArr)
        PosX += 100
        this.EncOutTextCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 2, 70), GetLang("输出编码："))
        PosX += 70
        this.EncOutCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R6", PosX, PosY - 1, 90), encArr)
        PosX += 100
        this.EncErrTextCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 2, 70), GetLang("错误编码："))
        PosX += 70
        this.EncErrCon := MyGui.Add("ComboBox", Format("x{} y{} w{} R6", PosX, PosY - 1, 90), encArr)

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
        pos := GetCenterPosOnActiveMonitor(580, 370)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 580, 370))
    }

    OnStdInOuterChange() {
        if (this.StdInCon == "")
            return
        if (this.StdInEditGui != "") {
            this.StdInEditCon.Value := this.StdInCon.Value
        }
    }

    OnModeChange() {
        val := this.RunModeCon.Value
        switch val {
            case 1:
                this.StdOutTipCon.Visible := false
                loop 3 {
                    this.SaveNameTipConArr[A_Index].Visible := false
                    this.SaveNameConArr[A_Index].Visible := false
                }
                this.StdInTipCon.Visible := false
                this.StdInCon.Visible := false
                this.StdInEditBtnCon.Visible := false

                this.EncInCon.Visible := false
                this.EncInTextCon.Visible := false
                this.EncOutCon.Visible := false
                this.EncOutTextCon.Visible := false
                this.EncErrCon.Visible := false
                this.EncErrTextCon.Visible := false

            case 2:
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

                this.EncInCon.Visible := false
                this.EncInTextCon.Visible := false
                this.EncOutCon.Visible := false
                this.EncOutTextCon.Visible := false
                this.EncErrCon.Visible := false
                this.EncErrTextCon.Visible := false

            case 3:
                this.StdOutTipCon.Visible := false
                loop 3 {
                    this.SaveNameTipConArr[A_Index].Visible := false
                    this.SaveNameConArr[A_Index].Visible := false
                }
                this.StdInTipCon.Visible := true
                this.StdInCon.Visible := true
                this.StdInEditBtnCon.Visible := true

                this.EncInCon.Visible := true
                this.EncInTextCon.Visible := true
                this.EncOutCon.Visible := false
                this.EncOutTextCon.Visible := false
                this.EncErrCon.Visible := false
                this.EncErrTextCon.Visible := false

            case 4:
                this.StdOutTipCon.Visible := true
                loop 3 {
                    this.SaveNameTipConArr[A_Index].Visible := true
                    this.SaveNameConArr[A_Index].Visible := true
                }
                this.StdInTipCon.Visible := true
                this.StdInCon.Visible := true
                this.StdInEditBtnCon.Visible := true

                this.EncInCon.Visible := true
                this.EncInTextCon.Visible := true
                this.EncOutCon.Visible := true
                this.EncOutTextCon.Visible := true
                this.EncErrCon.Visible := true
                this.EncErrTextCon.Visible := true
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
        this.OptionCon.Value := ObjHasOwnProp(this.Data, "Option") ? this.Data.Option + 1 : 2
        this.StdInCon.Value := ObjHasOwnProp(this.Data, "StdIn") ? this.Data.StdIn : ""

        ; Load encoding - default to UTF-8
        this.EncInCon.Text  := (ObjHasOwnProp(this.Data, "Encoding") && ObjHasOwnProp(this.Data.Encoding, "In"))  ? this.Data.Encoding.In  : "UTF-8"
        this.EncOutCon.Text := (ObjHasOwnProp(this.Data, "Encoding") && ObjHasOwnProp(this.Data.Encoding, "Out")) ? this.Data.Encoding.Out : "UTF-8"
        this.EncErrCon.Text := (ObjHasOwnProp(this.Data, "Encoding") && ObjHasOwnProp(this.Data.Encoding, "Err")) ? this.Data.Encoding.Err : "UTF-8"

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
        this.StdInEditCon.Value := this.StdInCon.Value
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
        this.StdInEditCon := MyGui.Add("Edit", Format("x{} y{} w{} h{} Multi VScroll WantReturn", PosX, PosY, 680, 300), this.StdInCon.Value)
        this.StdInEditCon.OnEvent("Focus", (*) => this.ActiveEdit := this.StdInEditCon)
        this.StdInEditCon.OnEvent("Change", (*) => this.OnStdInEditChange())

        btnOk := MyGui.Add("Button", "x330 y350 w90 h30", GetLang("确定"))
        btnOk.OnEvent("Click", (*) => this.OnClickStdInEditorClose())

        MyGui.OnEvent("Close", (*) => this.OnClickStdInEditorClose())
        MyGui.Show("w700 h395")
    }

    OnStdInEditChange() {
        if (this.StdInEditCon != "") {
            if (this.StdInCon != "")
                this.StdInCon.Value := this.StdInEditCon.Value
        }
    }

    OnClickStdInEditorAddVarNameBtn() {
        if (this.StdInEditCon == "")
            return

        this.InsertIntoEdit(this.StdInEditCon, this.StdInEditVariCon.Text)
        this.OnStdInEditChange()
    }

    OnClickStdInEditorAddVarValueBtn() {
        if (this.StdInEditCon == "")
            return

        if (this.StdInEditVariCon.Text != "") {
            this.InsertIntoEdit(this.StdInEditCon, "{" this.StdInEditVariCon.Text "}")
            this.OnStdInEditChange()
        }
    }

    OnClickStdInEditorClose() {
        this.StdInEditGui.Hide()
    }

    OnClickSureBtn() {
         ; ----- 编码提示（仅当模式为“等待+输入输出”时）-----
        if (this.RunModeCon.Value == 3) {
            for enc in [this.EncInCon.Text, this.EncOutCon.Text] {
                if (enc != "UTF-8" && enc != "UTF-16" && (SubStr(enc, 1, 2) != "CP")) {
                    MsgBox(Format("不支持{}编码", enc))
                    return
                }
            }
        }
        ; ----- 目標為空提示 -----
        if (this.PathTextCon.Value == "") {
            MsgBox(GetLang("目标不能为空！"))
            return
        }

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
            GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
        }
        this.Gui.Hide()
    }

    OnGuiClose() {
        this.ToggleFunc(false)

        if (this.StdInEditGui != "") {
            this.StdInEditGui.Hide()
        }

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
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
        this.Data.Option := this.OptionCon.Value - 1

        if (this.Data.Mode == 1) {
            if (ObjHasOwnProp(this.Data, "StdIn"))
                this.Data.DeleteProp("StdIn")
            if (ObjHasOwnProp(this.Data, "SaveNameArr"))
                this.Data.DeleteProp("SaveNameArr")
            if (ObjHasOwnProp(this.Data, "Encoding"))
                this.Data.DeleteProp("Encoding")
        } else if (this.Data.Mode == 2) {
            if (ObjHasOwnProp(this.Data, "StdIn"))
                this.Data.DeleteProp("StdIn")
            this.Data.SaveNameArr := [this.SaveNameConArr[1].Text]
            if (ObjHasOwnProp(this.Data, "Encoding"))
                this.Data.DeleteProp("Encoding")
        } else if (this.Data.Mode == 3) {
            this.Data.StdIn := this.StdInCon.Value
             if (ObjHasOwnProp(this.Data, "SaveNameArr"))
                this.Data.DeleteProp("SaveNameArr")
            enc := {}
            enc.In  := this.EncInCon.Text
            this.Data.Encoding := enc
        } else if (this.Data.Mode == 4) {
            this.Data.StdIn := this.StdInCon.Value
            this.Data.SaveNameArr := [this.SaveNameConArr[1].Text, this.SaveNameConArr[2].Text, this.SaveNameConArr[3].Text]
            enc := {}
            enc.In  := this.EncInCon.Text
            enc.Out := this.EncOutCon.Text
            enc.Err := this.EncErrCon.Text
            this.Data.Encoding := enc
        }

        SaveMacroCMDData(this.Data)
    }

    OnClickAddVarNameBtn() {
        targetCon := this.ActiveEdit.Visible ? this.ActiveEdit : this.PathTextCon
        this.InsertIntoEdit(targetCon, this.VariCon.Text)
    }

    OnClickAddVarValueBtn() {
        if (this.VariCon.Text != "") {
            targetCon := this.ActiveEdit.Visible ? this.ActiveEdit : this.PathTextCon
            this.InsertIntoEdit(targetCon, "{" this.VariCon.Text "}")
        }
    }

    InsertIntoEdit(editCon, text) {
        SendMessage(0x00C2, true, StrPtr(text), editCon.Hwnd) ; EM_REPLACESEL
    }
}