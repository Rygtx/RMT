#Requires AutoHotkey v2.0
#Include CompareProEditItemGui.ahk

class CompareProGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this.RemarkCon := ""
        this.MacroGui := ""
        this.FocusCon := ""
        this.ItemEditGui := ""
        this.ContextMenu := ""

        this.CompareTypeStrArr := GetLangArr(["大于", "大于等于", "等于", "小于等于",
            "小于", "字符包含", "变量存在", "正则匹配"])

        this.CompareTypeStrMap := Map(GetLang("大于"), 1, GetLang("大于等于"), 2, GetLang("等于"), 3, GetLang("小于等于"),
        4, GetLang("小于"), 5, GetLang("字符包含"), 6, GetLang("变量存在"), 7, GetLang("正则匹配"), 8)

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
        MyGui := Gui(, this.ParentTile GetLang("如果Pro编辑器"))
        this.Gui := MyGui
        if (this.OwnerHwnd != "") {
            MyGui.Opt("+Owner" this.OwnerHwnd)
        }
        MyGui.SetFont("S10 W550 Q2", MainSoftData.FontType)

        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("快捷方式："))
        PosX += 70
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
        PosY += 30
        this.LVCon := MyGui.Add("ListView", Format("x{} y{} w480 h280 -LV0x10 NoSort", PosX, PosY), GetLangArr(["条件",
            "关系", "指令"]))
        this.LVCon.OnEvent("ContextMenu", this.ShowContextMenu.Bind(this))
        this.LVCon.OnEvent("DoubleClick", this.OnDoubleClick.Bind(this))
        ; 设置列宽（单位：px）
        this.LVCon.ModifyCol(1, 260) ; 第一列宽度
        this.LVCon.ModifyCol(2, 50) ; 自动填充剩余宽度
        this.LVCon.ModifyCol(3, 150) ; 自动填充剩余宽度

        PosY += 290
        PosX := 190
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        this.FocusCon := btnCon

        MyGui.OnEvent("Close", (*) => this.OnGuiClose())
        pos := GetCenterPosOnActiveMonitor(500, 380)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 500, 380))
    }

    OnGuiClose() {
        this.ToggleFunc(false)
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("如果Pro")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr(1)

        this.LVCon.Delete()
        loop this.Data.MacroArr.Length {
            condiStr := this.FormatBranchCondiStr(this.Data, A_Index)
            logicStr := this.Data.LogicTypeArr[A_Index] == 1 ? GetLang("且") : GetLang("或")
            macro := GetLangMacro(this.Data.MacroArr[A_Index], 1)
            this.LVCon.Add(, condiStr, logicStr, macro)
        }
        this.LVCon.Add(, GetLang("以上都不是"), "", GetLangMacro(this.Data.DefaultMacro, 1))
        this.LVCon.Focus()  ; 🔥 强制获得焦点，解决第一次双击无效问题
    }

    ; 与「如果」一致：变量存在不拼右侧值；多条件用 ⎕ 分隔
    FormatBranchCondiStr(Data, itemIndex) {
        condiStr := ""
        loop Data.VariNameArr[itemIndex].Length {
            cmp := Data.CompareTypeArr[itemIndex][A_Index]
            name := GetLang(Data.VariNameArr[itemIndex][A_Index])
            typeStr := (cmp >= 1 && cmp <= this.CompareTypeStrArr.Length)
                ? this.CompareTypeStrArr[cmp] : this.CompareTypeStrArr[1]
            if (cmp != 7)
                condiStr .= name " " typeStr " " GetLang(Data.VariableArr[itemIndex][A_Index])
            else
                condiStr .= name " " typeStr
            condiStr .= "⎖"
        }
        return Trim(condiStr, "⎖")
    }

    DefaultBranchCondiStr() {
        return GetLang("Var1") " " GetLang("等于") " " GetLang("Var1")
    }

    ToggleFunc(state) {
        MacroAction := (*) => this.TriggerMacro()
        if (state) {
            Hotkey("!l", MacroAction, "On")
        }
        else {
            Hotkey("!l", MacroAction, "Off")
        }
    }

    ShowContextMenu(ctrl, item, isRightClick, x, y) {
        if (item == 0)
            return

        if (this.ContextMenu == "") {
            this.ContextMenu := Menu()
            this.ContextMenu.Add(GetLang("编辑"), (*) => this.MenuHandler(GetLang("编辑")))
            this.ContextMenu.Add()  ; 分隔线
            this.ContextMenu.Add(GetLang("向上插入分支"), (*) => this.MenuHandler(GetLang("向上插入分支")))
            this.ContextMenu.Add(GetLang("向下插入分支"), (*) => this.MenuHandler(GetLang("向下插入分支")))
            this.ContextMenu.Add()  ; 分隔线
            this.ContextMenu.Add(GetLang("向上移动"), (*) => this.MenuHandler(GetLang("向上移动")))
            this.ContextMenu.Add(GetLang("向下移动"), (*) => this.MenuHandler(GetLang("向下移动")))
            this.ContextMenu.Add()  ; 分隔线
            this.ContextMenu.Add(GetLang("删除"), (*) => this.MenuHandler(GetLang("删除")))
        }
        this.CurItme := item
        this.ContextMenu.Show(x, y)
    }

    OnDoubleClick(ctrl, item) {
        if (item == 0)
            return
        this.OnEditItem(item)
    }

    MenuHandler(cmdStr) {
        isFinally := this.LVCon.GetText(this.CurItme, 1) == GetLang("以上都不是")
        switch cmdStr {
            case GetLang("编辑"):
            {
                this.OnEditItem(this.CurItme)
            }
            case GetLang("向上插入分支"):
            {
                this.Data.ControlTypeArr.InsertAt(this.CurItme, "无")
                this.LVCon.Insert(this.CurItme, , this.DefaultBranchCondiStr(), GetLang("且"), "")
            }
            case GetLang("向下插入分支"):
            {
                if (isFinally) {
                    MsgBox(GetLang("不可向最后的分支插入"))
                    return
                }
                this.Data.ControlTypeArr.InsertAt(this.CurItme + 1, "无")
                this.LVCon.Insert(this.CurItme + 1, , this.DefaultBranchCondiStr(), GetLang("且"), "")
            }
            case GetLang("向上移动"):
            {
                if (isFinally) {
                    MsgBox(GetLang("最后的分支不能变更顺序"))
                    return
                }
                if (this.CurItme == 1) {
                    MsgBox(GetLang("第一个分支不能上移"))
                    return
                }
                this.LVCon.Insert(this.CurItme - 1, , this.LVCon.GetText(this.CurItme, 1), this.LVCon.GetText(this.CurItme,
                    2), this.LVCon.GetText(this.CurItme, 3))
                this.LVCon.Delete(this.CurItme + 1)
                ct := this.Data.ControlTypeArr[this.CurItme]
                this.Data.ControlTypeArr.RemoveAt(this.CurItme)
                this.Data.ControlTypeArr.InsertAt(this.CurItme - 1, ct)
            }
            case GetLang("向下移动"):
            {
                if (isFinally || this.LVCon.GetCount() == this.CurItme + 1) {
                    MsgBox(GetLang("最后的分支不能变更顺序"))
                    return
                }

                this.LVCon.Insert(this.CurItme + 2, , this.LVCon.GetText(this.CurItme, 1), this.LVCon.GetText(this.CurItme,
                    2), this.LVCon.GetText(this.CurItme, 3))
                this.LVCon.Delete(this.CurItme)
                ct := this.Data.ControlTypeArr[this.CurItme]
                this.Data.ControlTypeArr.RemoveAt(this.CurItme)
                this.Data.ControlTypeArr.InsertAt(this.CurItme + 1, ct)
            }
            case GetLang("删除"):
            {
                if (isFinally) {
                    MsgBox(GetLang("最后的分支不能删除，若无需该分支请清空分支指令"))
                    return
                }
                this.LVCon.Delete(this.CurItme)
                if (this.CurItme <= this.Data.ControlTypeArr.Length)
                    this.Data.ControlTypeArr.RemoveAt(this.CurItme)
            }
        }
    }

    OnEditItem(item) {
        if (this.ItemEditGui == "") {
            this.ItemEditGui := CompareProEditItemGui()
            this.ItemEditGui.SureFocusCon := this.FocusCon
        }
        ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
        this.ItemEditGui.ParentTile := ParentTile "-"

        if (MainSoftData.IsModalSubGui && this.Gui != "") {
            this.ItemEditGui.OwnerHwnd := this.Gui.Hwnd
        }
        else {
            this.ItemEditGui.OwnerHwnd := ""
        }

        this.ItemEditGui.DLVariableArr := this.DLVariableArr
        NumberIndex := item
        EditType := this.LVCon.GetText(item, 1) == GetLang("以上都不是") ? 2 : 1
        DataArr := this.GetCondiStrDataArr(this.LVCon.GetText(item, 1))
        logicStr := this.LVCon.GetText(item, 2)
        macro := this.LVCon.GetText(item, 3)
        controlType := EditType == 1 ? this.Data.ControlTypeArr[NumberIndex] : this.Data.DefaultControlType
        this.ItemEditGui.ShowGui(EditType, DataArr, logicStr, macro, controlType)
        this.ItemEditGui.SureBtnAction := this.OnSureEditItem.Bind(this, item)
    }

    OnSureEditItem(item, condiStr, logicStr, macro, controlType) {
        this.LVCon.Modify(item, , condiStr, logicStr, macro)
        NumberIndex := item
        EditType := this.LVCon.GetText(item, 1) == GetLang("以上都不是") ? 2 : 1
        if (EditType == 1)
            this.Data.ControlTypeArr[NumberIndex] := controlType
        else 
            this.Data.DefaultControlType := controlType
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveCompareProData()
        this.ToggleFunc(false)
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    CheckIfValid() {
        return true
    }

    TriggerMacro() {
        this.SaveCompareProData()
        OnTriggerSepcialItemMacro(this.GetCommandStr())
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    GetItemNumber(nodeItemID) {
        ItemNumber := 1
        PreItemID := this.LVCon.GetPrev(nodeItemID)
        while (PreItemID != 0) {
            ItemNumber += 1
            PreItemID := this.LVCon.GetPrev(PreItemID)
        }
        return ItemNumber
    }

    GetCondiStrDataArr(condiStr) {
        condiStrArr := StrSplit(condiStr, "⎖")
        VariNameArr := []
        CompareTypeArr := []
        VariableArr := []
        if (condiStr != GetLang("以上都不是")) {
            loop condiStrArr.Length {
                parsed := this.ParseSingleCondi(condiStrArr[A_Index])
                VariNameArr.Push(parsed[1])
                CompareTypeArr.Push(parsed[2])
                VariableArr.Push(parsed[3])
            }
        }

        return [VariNameArr, CompareTypeArr, VariableArr]
    }

    ; 按已知比较符拆分，避免变量名/值中的空格被截断（如 "a b 等于 hello world"）
    ParseSingleCondi(item) {
        item := Trim(item)
        if (item == "")
            return ["", 1, ""]

        ; 长操作符优先，避免「大于」先于「大于等于」误匹配；含英文 "Var Exists" 等带空格文案
        opOrder := [GetLang("大于等于"), GetLang("小于等于"), GetLang("字符包含"), GetLang("变量存在"),
            GetLang("正则匹配"), GetLang("大于"), GetLang("等于"), GetLang("小于")]
        for typeStr in opOrder {
            if (!this.CompareTypeStrMap.Has(typeStr))
                continue
            typeId := this.CompareTypeStrMap[typeStr]
            mid := " " typeStr " "
            pos := InStr(item, mid)
            if (pos > 0) {
                name := SubStr(item, 1, pos - 1)
                value := SubStr(item, pos + StrLen(mid))
                return [name, typeId, value]
            }
            ; 「变量存在」无右侧值：name + 空格 + 操作符
            if (typeId == 7) {
                endNeedle := " " typeStr
                endLen := StrLen(endNeedle)
                if (StrLen(item) > endLen && SubStr(item, StrLen(item) - endLen + 1) == endNeedle)
                    return [SubStr(item, 1, StrLen(item) - endLen), typeId, ""]
            }
        }

        ; 兜底：无法识别操作符时尽量保留整段为变量名
        return [item, 1, ""]
    }

    SaveCompareProData() {
        this.Data.VariNameArr := []
        this.Data.CompareTypeArr := []
        this.Data.VariableArr := []
        this.Data.LogicTypeArr := []
        this.Data.MacroArr := []
        loop this.LVCon.GetCount() {
            if (A_Index == this.LVCon.GetCount()) {
                this.Data.DefaultMacro := GetLangMacro(this.LVCon.GetText(A_Index, 3), 2)
                break
            }
            CondiDataArr := this.GetCondiStrDataArr(this.LVCon.GetText(A_Index, 1))
            LogicType := this.LVCon.GetText(A_Index, 2) == GetLang("且") ? 1 : 2
            ; 与「如果」一致：变量名/比较值存中文 key（GetLangKey）
            this.Data.VariNameArr.Push(GetLangKeyArr(CondiDataArr[1]))
            this.Data.CompareTypeArr.Push(CondiDataArr[2])
            this.Data.VariableArr.Push(GetLangKeyArr(CondiDataArr[3]))
            this.Data.LogicTypeArr.Push(LogicType)
            this.Data.MacroArr.Push(GetLangMacro(this.LVCon.GetText(A_Index, 3), 2))
        }

        ; 分支数与流程控制数组对齐（插入/删除后可能残留）
        while (this.Data.ControlTypeArr.Length > this.Data.MacroArr.Length)
            this.Data.ControlTypeArr.Pop()
        while (this.Data.ControlTypeArr.Length < this.Data.MacroArr.Length)
            this.Data.ControlTypeArr.Push("无")

        SaveMacroCMDData(this.Data)
    }
}
