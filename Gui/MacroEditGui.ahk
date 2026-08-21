#Requires AutoHotkey v2.0
#Include IntervalGui.ahk
#Include KeyGui.ahk
#Include MouseMoveGui.ahk
#Include SearchGui.ahk
#Include SearchProGui.ahk
#Include ScreenShotGui.ahk
#Include RunGui.ahk
#Include CompareGui.ahk
#Include MMProGui.ahk
#Include OutputGui.ahk
#Include VariableGui.ahk
#Include SubMacroGui.ahk
#Include OperationGui.ahk
#Include BGMouseGui.ahk
#Include ExVariableGui.ahk
#Include RMTCMDGui.ahk
#Include BGKeyGui.ahk
#Include LoopGui.ahk
#Include CompareProGui.ahk
#Include CompareProEditItemGui.ahk
#Include TextOpsGui.ahk
#Include ArrayGui.ahk
#Include InputGui.ahk
#Include FileIOGui.ahk
#Include WindowManageGui.ahk
#include KeyCheckGui.ahk
#Include CommentGui.ahk

class MacroEditGui {
    static Hotkeys := ["f5", "f6", "delete"]

    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.GuiMenu := ""
        this.DebugItemID := 0
        this.CurrentItemID := 0
        this.ShowSaveBtn := false
        this.SureFocusCon := ""
        this.isContextEdit := false
        this.RecordToggleCon := ""
        this.EditModeCon := ""
        this.SubMacroEditGui := ""
        this.SubMacroGraphGui := ""
        this.CompareProEditItemGui := ""
        this.OwnerHwnd := ""

        this.SureBtnAction := ""
        this.SaveBtnAction := ""
        this.SaveBtnCtrl := {}
        this.SubGuiMap := map()
        this.OpenedSubGuis := []  ; 多开时额外创建的子指令编辑器实例
        this.MacroTreeViewCon := ""
        this.MacroEditTextCon := ""
        this.CmdEditType := 1  ;1添加指令 2修改当前指令 3向上插入指令 4 向下插入指令
        this.CurItemID := ""  ;当前操作itemID
        this.LastItemID := "" ;最后的itemID
        this.ContextMenu := ""
        this.BranchContextMenu := ""
        this.RecordMacroCon := ""
        this.DefaultFocusCon := ""
        this.SubMacroLastIndex := 0
        this.DragSourceMap := Map()
        this._dragCancelled := false
        ; 多選複製：使用 TreeView Check 狀態作為多選標記
        this.MultiSelectItems := Map()
        this.MultiSelectAnchor := 0
        this._lbtnHandler := ObjBindMethod(this, "_OnLButtonDown")
        this._notifyHandler := ObjBindMethod(this, "_OnNotify")

        this.InitCommandConfigs()
        this.InitSubGuiConfigs()
        this.InitSubGui()
    }

    InitCommandConfigs() {
        this.CMDStrArr := GetLangArr(["间隔", "按键", "搜索", "搜索Pro", "移动", "移动Pro", "输入", "输出", "循环", "宏操作", "变量", "变量提取",
            "如果", "如果Pro", "运算", "运行", "文件读写", "文本处理", "数组", "RMT指令", "后台鼠标", "后台按键", "窗口管理", "按键检测", "注释", "抓图"])

        this.CMDIconFileArr := ["Images\Soft\Interval.png", "Images\Soft\Key.png",
            "Images\Soft\Search.png", "Images\Soft\SearchPro.png",
            "Images\Soft\Move.png", "Images\Soft\MovePro.png",
            "Images\Soft\Input.png", "Images\Soft\Output.png",
            "Images\Soft\Loop.png", "Images\Soft\Sub.png",
            "Images\Soft\Var.png", "Images\Soft\Extract.png",
            "Images\Soft\If.png", "Images\Soft\IfPro.png",
            "Images\Soft\Operation.png", "Images\Soft\Run.png",
            "Images\Soft\FileIO.png", "Images\Soft\TextOps.png",
            "Images\Soft\Arr.png", "Images\Soft\rabit.png",
            "Images\Soft\Mouse.png", "Images\Soft\Key.png",
            "Images\Soft\WindowManage.png", "Images\Soft\KeyCheck.png",
            "Images\Soft\ScreenShot.png", "Images\Soft\Comment.png"]

        this.IconMap := Map(GetLang("间隔"), "Icon1", GetLang("按键"), "Icon2", GetLang("搜索"), "Icon3",
        GetLang("搜索Pro"), "Icon4", GetLang("移动"), "Icon5", GetLang("移动Pro"), "Icon6", GetLang("输出"), "Icon7",
        GetLang("运行"), "Icon8", GetLang("循环"), "Icon9", GetLang("宏操作"), "Icon10", GetLang("变量"), "Icon11",
        GetLang("变量提取"), "Icon12", GetLang("如果"), "Icon13", GetLang("如果Pro"), "Icon14", GetLang("运算"), "Icon15",
        GetLang("RMT指令"), "Icon16", GetLang("后台鼠标"), "Icon17", GetLang("后台按键"), "Icon18", GetLang("真"), "Icon19",
        GetLang("假"), "Icon20", GetLang("循环次数"), "Icon21", GetLang("条件"), "Icon22", GetLang("循环体"), "Icon23",
        GetLang("文本处理"), "Icon24", GetLang("数组"), "Icon25", GetLang("输入"), "Icon26", GetLang("文件读写"), "Icon27",
        GetLang("流程控制"), "Icon28", GetLang("窗口管理"), "Icon29", GetLang("按键检测"), "Icon30", GetLang("注释"), "Icon31",
        GetLang("抓图"), "Icon32")
    }

    InitSubGuiConfigs() {
        this.SubGuiConfig := [
            {class: IntervalGui, name: "间隔", icon: "Images\Soft\Interval.png", propName: "IntervalGui"},
            {class: KeyGui, name: "按键", icon: "Images\Soft\Key.png", propName: "KeyGui"},
            {class: SearchGui, name: "搜索", icon: "Images\Soft\Search.png", propName: "SearchGui"},
            {class: SearchProGui, name: "搜索Pro", icon: "Images\Soft\SearchPro.png", propName: "SearchProGui"},
            {class: MouseMoveGui, name: "移动", icon: "Images\Soft\Move.png", propName: "MouseMoveGui"},
            {class: MMProGui, name: "移动Pro", icon: "Images\Soft\MovePro.png", propName: "MMProGui"},
            {class: InputGui, name: "输入", icon: "Images\Soft\Input.png", propName: "InputGui"},
            {class: OutputGui, name: "输出", icon: "Images\Soft\Output.png", propName: "OutputGui"},
            {class: LoopGui, name: "循环", icon: "Images\Soft\Loop.png", propName: "LoopGui"},
            {class: SubMacroGui, name: "宏操作", icon: "Images\Soft\Sub.png", propName: "SubMacroGui"},
            {class: VariableGui, name: "变量", icon: "Images\Soft\Var.png", propName: "VariableGui"},
            {class: ExVariableGui, name: "变量提取", icon: "Images\Soft\Extract.png", propName: "ExVariableGui"},
            {class: CompareGui, name: "如果", icon: "Images\Soft\If.png", propName: "CompareGui"},
            {class: CompareProGui, name: "如果Pro", icon: "Images\Soft\IfPro.png", propName: "CompareProGui"},
            {class: OperationGui, name: "运算", icon: "Images\Soft\Operation.png", propName: "OperationGui"},
            {class: RunGui, name: "运行", icon: "Images\Soft\Run.png", propName: "RunGui"},
            {class: FileIOGui, name: "文件读写", icon: "Images\Soft\FileIO.png", propName: "FileIOGui"},
            {class: TextOpsGui, name: "文本处理", icon: "Images\Soft\TextOps.png", propName: "TextOpsGui"},
            {class: ArrayGui, name: "数组", icon: "Images\Soft\Arr.png", propName: "ArrayGui"},
            {class: RMTCMDGui, name: "RMT指令", icon: "Images\Soft\rabit.png", propName: "RMTCMDGui"},
            {class: BGMouseGui, name: "后台鼠标", icon: "Images\Soft\Mouse.png", propName: "BGMouseGui"},
            {class: BGKeyGui, name: "后台按键", icon: "Images\Soft\Key.png", propName: "BGKeyGui"},
            {class: WindowManageGui, name: "窗口管理", icon: "Images\Soft\WindowManage.png", propName: "WindowManageGui"},
            {class: KeyCheckGui, name: "按键检测", icon: "Images\Soft\KeyCheck.png", propName: "KeyCheckGui"},
            {class: CommentGui, name: "注释", icon: "Images\Soft\Comment.png", propName: "CommentGui"},
            {class: ScreenShotGui, name: "抓图", icon: "Images\Soft\ScreenShot.png", propName: "ScreenShotGui"}
        ]
    }

    InitSubGui() {
        for config in this.SubGuiConfig {
            guiClass := config.class
            guiInstance := guiClass()
            guiInstance.SureBtnAction := (CommandStr) => this.OnSubGuiSureBtnClick(CommandStr)
            this.SubGuiMap.Set(GetLang(config.name), guiInstance)
            this.%config.propName% := guiInstance
        }
    }

    ShowGui(CommandStr, ShowSaveBtn) {
        global MySoftData
        if (this.Gui != "") {
            if (this.OwnerHwnd != "") {
                this.Gui.Opt("+Owner" this.OwnerHwnd)
            }
            this.Gui.Show()
        }
        else {
            this.AddGui()
            ImageListID := IL_Create(30)
            this.MacroTreeViewCon.SetImageList(ImageListID)
            IL_Add(ImageListID, "Images\Soft\Interval.png")
            IL_Add(ImageListID, "Images\Soft\Key.png")
            IL_Add(ImageListID, "Images\Soft\Search.png")
            IL_Add(ImageListID, "Images\Soft\SearchPro.png")
            IL_Add(ImageListID, "Images\Soft\Move.png")
            IL_Add(ImageListID, "Images\Soft\MovePro.png")
            IL_Add(ImageListID, "Images\Soft\Output.png")
            IL_Add(ImageListID, "Images\Soft\Run.png")
            IL_Add(ImageListID, "Images\Soft\Loop.png")
            IL_Add(ImageListID, "Images\Soft\Sub.png")
            IL_Add(ImageListID, "Images\Soft\Var.png")
            IL_Add(ImageListID, "Images\Soft\Extract.png")
            IL_Add(ImageListID, "Images\Soft\If.png")
            IL_Add(ImageListID, "Images\Soft\IfPro.png")
            IL_Add(ImageListID, "Images\Soft\Operation.png")
            IL_Add(ImageListID, "Images\Soft\rabit.png")
            IL_Add(ImageListID, "Images\Soft\Mouse.png")
            IL_Add(ImageListID, "Images\Soft\Key.png")
            IL_Add(ImageListID, "Images\Soft\True.png")
            IL_Add(ImageListID, "Images\Soft\False.png")
            IL_Add(ImageListID, "Images\Soft\LoopCount.png")    ;21 循环次数
            IL_Add(ImageListID, "Images\Soft\Condition.png")
            IL_Add(ImageListID, "Images\Soft\LoopBody.png")
            IL_Add(ImageListID, "Images\Soft\TextOps.png")
            IL_Add(ImageListID, "Images\Soft\Arr.png")
            IL_Add(ImageListID, "Images\Soft\Input.png")
            IL_Add(ImageListID, "Images\Soft\FileIO.png")   ;27 标记一下
            IL_Add(ImageListID, "Images\Soft\Control.png")
            IL_Add(ImageListID, "Images\Soft\WindowManage.png")   ;29 窗口管理
            IL_Add(ImageListID, "Images\Soft\KeyCheck.png")   ;30 按键检测
            IL_Add(ImageListID, "Images\Soft\Comment.png")   ;31 注释
            IL_Add(ImageListID, "Images\Soft\ScreenShot.png")
        }

        ; 注册快捷键热键（仅编辑器前台时拦截，失焦时按键透传给其他程序；关闭时注销）
        this._hkIds := WinHotkey.Register(["F5", "F6", "Delete", "$^c", "$^v"], ObjBindMethod(this, "_OnHotkey"), this.Gui.Hwnd)

        ; 注册拖拽消息监听（先注销再注册，避免重复打开时叠多个处理器）
        OnMessage(0x0201, this._lbtnHandler, 0)
        OnMessage(0x0201, this._lbtnHandler)
        OnMessage(0x004E, this._notifyHandler)  ; WM_NOTIFY：TreeView 多選高亮

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
            }
        }

        UIControls.RecordToggle := this.RecordMacroCon
        MainSoftData.MacroEditGui := this
        this.InitGuiMenu()
        this.Init(CommandStr, ShowSaveBtn)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("宏指令编辑器"))
        this.Gui := MyGui
        if (this.OwnerHwnd != "") {
            MyGui.Opt("+Owner" this.OwnerHwnd)
        }
        MyGui.SetFont("S10 W550 Q2", MainSoftData.FontType)

        PosY := 10
        PosX := 5
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 205, 530), GetLang("指令选项"))

        PosY += 20
        PosX := 10
        index := 0
        for config in this.SubGuiConfig {
            guiInstance := this.%config.propName%
            this.AddIconBtn(MyGui, PosX, PosY, config.icon,
                GetLang(config.name), CreateSubGuiClickHandler(this, guiInstance), guiInstance)
            index += 1
            if (index & 1) {
                PosX += 105
            } else {
                PosX := 10
                PosY += 40
            }
        }

        PosX := 225
        PosY := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("编辑模式："))
        PosX += 70
        this.EditModeCon := MyGui.Add("DropDownList", Format("x{} y{} w80", PosX, PosY - 3), GetLangArr(["逻辑树", "文本"]))
        this.EditModeCon.Value := 1
        this.EditModeCon.OnEvent("Change", this.OnChangeEditMode.Bind(this))

        PosX := 430
        this.RecordMacroCon := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("指令录制"))
        this.RecordMacroCon.Value := false
        this.RecordMacroCon.OnEvent("Click", this.OnClickRecordTog.Bind(this))
        PosX += 85
        isHotKey := CheckIsNormalHotKey(MainSoftData.ToolRecordMacroHotKey)
        CtrlType := isHotKey ? "Hotkey" : "Text"
        con := MyGui.Add(CtrlType, Format("x{} y{} w{}", posX, posY - 3, 100), MainSoftData.ToolRecordMacroHotKey
        )
        con.Enabled := false

        ; 指令显示区：左 215、宽 710 → 右边框 925；图形节点按钮右对齐该边框
        cmdViewLeft := 215
        cmdViewW := 710
        graphBtnW := 80
        graphBtn := MyGui.Add("Button", Format("x{} y{} w{} h{} center", cmdViewLeft + cmdViewW - graphBtnW, PosY - 5, graphBtnW, 26), GetLang("图形节点"))
        graphBtn.OnEvent("Click", this.OnSwitchToGraphEditor.Bind(this))

        PosX := 210
        PosY += 25
        MyGui.Add("Text", Format("x{} y{}", PosX + 10, PosY), GetLang("当前宏指令"))
        expandBtn := MyGui.Add("Button", Format("x{} y{} w{} h{} center", PosX + 85, PosY, 80, 20), GetLang("全部展开"))
        expandBtn.OnEvent("Click", (*) => this.ExpandAll())
        collapseBtn := MyGui.Add("Button", Format("x{} y{} w{} h{} center", PosX + 220, PosY, 80, 20), GetLang("全部折叠"))
        collapseBtn.OnEvent("Click", (*) => this.CollapseAll())

        PosY += 20
        ; +Check：利用原生 Check 狀態顯示多選項目，避免改動節點文字。
        this.MacroTreeViewCon := MyGui.Add("TreeView", Format("x{} y{} w{} h{}", cmdViewLeft, PosY, cmdViewW, 435),
        "+Check")
        this.MacroTreeViewCon.OnEvent("ContextMenu", this.ShowContextMenu.Bind(this))  ; 右键菜单事件
        this.MacroTreeViewCon.OnEvent("DoubleClick", this.OnDoubleClick.Bind(this))  ; 双击编辑指令

        this.MacroEditTextCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", cmdViewLeft, PosY, cmdViewW, 435), "")
        this.MacroEditTextCon.Visible := false

        PosX := 215
        PosY := 500
        btnCon := MyGui.Add("Button", Format("x{} y{} h{} w{} center", PosX, PosY, 40, 100), GetLang("退格"))
        btnCon.OnEvent("Click", (*) => this.Backspace())

        PosX += 150
        btnCon := MyGui.Add("Button", Format("x{} y{} h{} w{} center", PosX, PosY, 40, 100), GetLang("清空指令"))
        btnCon.OnEvent("Click", (*) => this.ClearStr())

        PosX += 150
        btnCon := MyGui.Add("Button", Format("x{} y{} h{} w{} center", PosX, PosY, 40, 100), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnSureBtnClick())

        PosX += 150
        this.SaveBtnCtrl := MyGui.Add("Button", Format("x{} y{} h{} w{} center", PosX, PosY, 40, 100), GetLang("应用并保存"))
        this.SaveBtnCtrl.OnEvent("Click", (*) => this.OnSaveBtnClick())

        pos := GetCenterPosOnActiveMonitor(945, 570)
        MyGui.Show(Format("x{} y{} w{} h{}", pos.x, pos.y, 945, 570))
        MyGui.OnEvent("Close", (*) => this.OnGuiClose())
    }

    AddIconBtn(MyGui, PosX, PosY, ImgFile, LabelText, ClickAction, guiInstance) {
        IconSize := 16
        BtnW := 75
        ImgY := PosY + (30 - IconSize) // 2
        picCon := MyGui.Add("Picture", Format("x{} y{} w{} h{}", PosX, ImgY, IconSize, IconSize), ImgFile)
        btnCon := MyGui.Add("Button", Format("x{} y{} h{} w{} center", PosX + IconSize, PosY, 30, BtnW), LabelText)
        btnCon.SetFont(Format("S{} W{} Q{}", 11, 400, 5))
        btnCon.OnEvent("Click", ClickAction)

        this.DragSourceMap[picCon.Hwnd] := {gui: guiInstance, name: LabelText, isMove: false}
        this.DragSourceMap[btnCon.Hwnd] := {gui: guiInstance, name: LabelText, isMove: false}
    }

    InitGuiMenu() {
        if (this.GuiMenu != "")
            return

        ; 创建菜单栏
        MyMenuBar := MenuBar()

        ; === 文件菜单 ===
        ExeMenu := Menu()
        ExeMenu.Add(GetLang("运行(F5)"), this.MenuHandler.Bind(this))
        ExeMenu.Add(GetLang("单步运行(F6)"), this.MenuHandler.Bind(this))
        ExeMenu.Add(GetLang("终止"), this.MenuHandler.Bind(this))

        ; === 编辑菜单 ===
        this.ToolMenu := Menu()
        this.ToolMenu.Add(GetLang("变量监视"), this.MenuHandler.Bind(this))
        this.ToolMenu.Add(GetLang("指令显示"), this.MenuHandler.Bind(this))
        this.ToolMenu.Add(GetLang("窗口置顶"), this.MenuHandler.Bind(this))

        ; === 添加到菜单栏 ===
        MyMenuBar.Add(GetLang("调试"), ExeMenu)
        MyMenuBar.Add(GetLang("工具"), this.ToolMenu)

        if (MyVarListenGui.Gui != "" && MyVarListenGui.Gui.Hwnd) {
            style := WinGetStyle(MyVarListenGui.Gui.Hwnd)
            isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
            if (isVisible)
                this.ToolMenu.Check(GetLang("变量监视"))
        }

        if (MyCMDTipGui.Gui != "" && MyCMDTipGui.Gui.Hwnd) {
            style := WinGetStyle(MyCMDTipGui.Gui.Hwnd)
            isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
            if (isVisible)
                this.ToolMenu.Check(GetLang("指令显示"))
        }

        try {
            exStyle := DllCall("GetWindowLongPtr", "Ptr", this.Gui.Hwnd, "Int", -20, "UInt") ; GWL_EXSTYLE = -20
            isTop := (exStyle & 0x00000008)
            if (isTop) {
                this.ToolMenu.Check(GetLang("窗口置顶"))
            }
        }

        this.Gui.MenuBar := MyMenuBar
    }

    Init(MacroStr, ShowSaveBtn) {
        MacroStr := GetLangMacro(MacroStr, 1)
        this.ShowSaveBtn := ShowSaveBtn
        this.SubMacroLastIndex := 0
        this.SaveBtnCtrl.Visible := this.ShowSaveBtn
        this.InitTreeView(MacroStr)
        this.InitMacroText(MacroStr)

        this.ClearMultiSelection()
        firstItem := 0
        try firstItem := this.MacroTreeViewCon.GetNext(0)
        this.MacroTreeViewCon.Focus()
        this._SelectCurrent(firstItem)
    }

    Backspace() {
        if (this.EditModeCon.Value == 1) {
            if (this.MacroTreeViewCon.GetCount() == 0)
                return
            preItemID := this.MacroTreeViewCon.GetPrev(this.LastItemID)
            this.MacroTreeViewCon.Delete(this.LastItemID)
            this.LastItemID := preItemID
        }
        else {
            MacroStr := this.GetMacroStr()
            cmdArr := SplitMacro(MacroStr)
            if (cmdArr.Length > 0)
                cmdArr.Pop()
            MacroStr := GetMacroStrByCmdArr(cmdArr)

            ; 回到替换前的滑动值
            firstVisible := SendMessage(0xCE, 0, 0, this.MacroEditTextCon) ; EM_GETFIRSTVISIBLELINE = 0xCE
            this.InitMacroText(MacroStr)
            SendMessage(0xB6, 0, firstVisible, this.MacroEditTextCon) ; EM_LINESCROLL = 0xB6
        }
    }

    ClearStr() {
        this.MacroTreeViewCon.Delete()
        this.MacroEditTextCon.Value := ""
    }

    OnChangeEditMode(*) {
        MacroStr := this.GetMacroStr()
        this.MacroTreeViewCon.Visible := this.EditModeCon.Value == 1
        this.MacroEditTextCon.Visible := this.EditModeCon.Value == 2

        if (this.EditModeCon.Value == 1) {
            this.InitTreeView(MacroStr)
        }
        else if (this.EditModeCon.Value == 2) {
            this.InitMacroText(MacroStr)
        }
    }

    OnClickRecordTog(*) {
        UIControls.RecordToggle := this.RecordMacroCon
        MainSoftData.MacroEditGui := this
        OnHotToolRecordMacro(true)
    }

    ; 切换到图形节点编辑器（先回写当前宏内容）
    OnSwitchToGraphEditor(*) {
        macroStr := this.GetMacroStr()
        macroStr := GetLangMacro(macroStr, 2)
        sureAction := this.SureBtnAction
        if (sureAction != "")
            sureAction(macroStr)
        this.SureBtnAction := ""
        this.OnGuiClose()

        MyMacroGraphGui.OwnerHwnd := ""
        MyMacroGraphGui.SureBtnAction := sureAction
        MyMacroGraphGui.ShowGui(macroStr)
    }

    OnSaveBtnClick() {
        macroStr := this.GetMacroStr()
        macroStr := GetLangMacro(macroStr, 2)
        action := this.SureBtnAction
        action(macroStr)

        this.SureBtnAction := ""

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }

        this.Gui.Hide()

        action := this.SaveBtnAction
        action()
        this.SureFocusCon.Focus()
    }

    OnSureBtnClick() {
        macroStr := this.GetMacroStr()
        macroStr := GetLangMacro(macroStr, 2)
        action := this.SureBtnAction
        action(macroStr)

        this.SureBtnAction := ""

        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }

        this.Gui.Hide()
        this.SureFocusCon.Focus()
    }

    OnGuiClose() {
        if (this._hkIds.Length > 0)
            WinHotkey.UnregisterAll(this._hkIds)
        OnMessage(0x0201, this._lbtnHandler, 0)
        OnMessage(0x004E, this._notifyHandler, 0)
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui) {
            try {
                GuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
            }
        }
        this.Gui.Hide()
    }

    GetMacroStr() {
        MacroStr := ""
        if (this.MacroTreeViewCon.Visible) {
            MacroStr := this.GetTreeMacroStr(0)
        }
        else if (this.MacroEditTextCon.Visible) {
            MacroStr := this.MacroEditTextCon.Value
        }
        return MacroStr
    }

    InitMacroText(MacroStr) {
        this.MacroEditTextCon.Visible := this.EditModeCon.Value == 2

        content := RegExReplace(MacroStr, "[,，⫶]", "`n")
        this.MacroEditTextCon.Value := content
    }

    ShowContextMenu(ctrl, item, isRightClick, x, y) {
        if (item == 0)
            return

        if (this.ContextMenu == "") {
            this.ContextMenu := Menu()
            this.ContextMenu.Add(GetLang("编辑"), (*) => this.ContentMenuHandler(GetLang("编辑")))
            this.ContextMenu.IsSkip := true
            this.ContextMenu.Add(GetLang("跳过指令"), (*) => this.ContentMenuHandler("Skip"))
            this.ContextMenu.IsDebug := true
            this.ContextMenu.Add(GetLang("调试起点"), (*) => this.ContentMenuHandler("Debug"))

            this.ContextMenu.Add()  ; 分隔线
            subMenu := Menu()
            for index, value in this.CMDStrArr {
                subMenu.Add(value, this.ContentMenuHandler.Bind(this, "Next_" value))
                subMenu.SetIcon(value, this.CMDIconFileArr[index])
            }
            this.ContextMenu.Add(GetLang("插入指令"), subMenu)

            this.ContextMenu.Add(GetLang("复制"), (*) => this.ContentMenuHandler(GetLang("复制")))
            if (MainSoftData.SharedCopy)
                this.ContextMenu.Add(GetLang("共享复制"), (*) => this.ContentMenuHandler("SharedCopy"))
            this.ContextMenu.Add(GetLang("粘贴"), (*) => this.ContentMenuHandler(GetLang("粘贴")))

            this.ContextMenu.Add()  ; 分隔线
            this.ContextMenu.Add(GetLang("删除"), (*) => this.ContentMenuHandler(GetLang("删除")))
        }

        if (this.BranchContextMenu == "") {
            this.BranchContextMenu := Menu()

            subMenu := Menu()
            for index, value in this.CMDStrArr {
                subMenu.Add(value, this.ContentMenuHandler.Bind(this, "Add_" value))
                subMenu.SetIcon(value, this.CMDIconFileArr[index])
            }
            this.BranchContextMenu.Add(GetLang("添加指令"), subMenu)  ; 将子菜单添加到主菜单

            this.BranchContextMenu.Add()  ; 分隔线
            this.BranchContextMenu.Add(GetLang("删除"), (*) => this.ContentMenuHandler(GetLang("删除")))
        }

        ; 右鍵只設定「右鍵操作目標」，絕對不改變目前多選狀態。
        ; MultiSelectItems / TreeView Select 狀態都保持原樣。
        this.CurItemID := item
        itemText := this.MacroTreeViewCon.GetText(this.CurItemID)
        cleanItemText := StrReplace(itemText, "→", "")
        isCondi := SubStr(cleanItemText, 1, StrLen(GetLang("条件"))) == GetLang("条件")
        ; 清理→前缀用于菜单状态判断（→是运行时临时标记，不影响逻辑状态）
        if (cleanItemText == "" || SubStr(cleanItemText, 1, 1) == "⎖")
            return
        else if (itemText == GetLang("真") || itemText == GetLang("假") || itemText == GetLang("循环体") || isCondi) {
            this.BranchContextMenu.Show(x, y)
        }
        else {
            CurSkipMenuText := this.ContextMenu.IsSkip ? GetLang("跳过指令") : GetLang("取消跳过")
            SkipMenuText := SubStr(cleanItemText, 1, 2) == "🚫" ? GetLang("取消跳过") : GetLang("跳过指令")
            if (CurSkipMenuText != SkipMenuText) {
                this.ContextMenu.Rename(CurSkipMenuText, SkipMenuText)
                this.ContextMenu.IsSkip := !this.ContextMenu.IsSkip
            }

            CurDebugMenuText := this.ContextMenu.IsDebug ? GetLang("调试起点") : GetLang("取消调试起点")
            DebugMenuText := SubStr(cleanItemText, 1, 1) == "⭐" ? GetLang("取消调试起点") : GetLang("调试起点")
            if (CurDebugMenuText != DebugMenuText) {
                this.ContextMenu.Rename(CurDebugMenuText, DebugMenuText)
                this.ContextMenu.IsDebug := !this.ContextMenu.IsDebug
            }

            this.ContextMenu.Show(x, y)
        }
    }

    _OnHotkey(key) {
        ; 去掉 ~ / $ 前缀后再比较（$ 用于防止 Send 再次触发自身热键）
        key := LTrim(key, "~$")
        if (key == "F5")
            this.MenuHandler(GetLang("运行(F5)"))
        else if (key == "F6")
            this.MenuHandler(GetLang("单步运行(F6)"))
        else if (key == "Delete") {
            this.OnDeleteCmd()
        }
        else if (key == "^c") {
            ; 逻辑树模式：复制选中指令；文本模式：交还编辑框原生复制
            ; 非透传（无 ~）会吞掉按键，避免树控件收到 Ctrl+C 后响铃
            if (!this.MacroTreeViewCon.Visible)
                Send("^c")
            else if (this.CurItemID)
                this.ContentMenuHandler(GetLang("复制"))
        }
        else if (key == "^v") {
            if (!this.MacroTreeViewCon.Visible)
                Send("^v")
            else
                ; 空树/无选中时也允许粘贴到根层
                this.ContentMenuHandler(GetLang("粘贴"))
        }
    }

    OnSoftKey(key, isDown) {
        if (!isDown)
            return

        if (key == "f5")
            this.MenuHandler(GetLang("运行(F5)"))
        if (key == "f6")
            this.MenuHandler(GetLang("单步运行(F6)"))
        if (key == "delete") {
            try {
                focusedHwnd := DllCall("GetFocus", "Ptr")
                if (focusedHwnd = this.MacroTreeViewCon.hwnd)
                    this.OnDeleteCmd()
            }
        }
    }

    OnDoubleClick(ctrl, item) {
        if (item == 0)
            return

        itemText := this.MacroTreeViewCon.GetText(item)
        if (itemText == "" || SubStr(itemText, 1, 1) == "⎖")
            return

        this.CurItemID := item
        if (itemText == GetLang("真") || itemText == GetLang("假") || itemText == GetLang("循环体")) {
            if (this.SubMacroEditGui == "")
                this.SubMacroEditGui := MacroEditGui()

            macroStr := this.GetTreeMacroStr(this.CurItemID)
            this.SubMacroEditGui.SureBtnAction := this.OnSubNodeEdit.Bind(this, this.CurItemID)
            this.SubMacroEditGui.SureFocusCon := this.MacroTreeViewCon
            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            this.SubMacroEditGui.ParentTile := ParentTile "-"

            if (MainSoftData.IsModalSubGui && this.Gui != "") {
                this.SubMacroEditGui.OwnerHwnd := this.Gui.Hwnd
            }
            else {
                this.SubMacroEditGui.OwnerHwnd := ""
            }

            this.SubMacroEditGui.ShowGui(macroStr, false)
            return
        }
        else if (SubStr(itemText, 1, StrLen(GetLang("条件"))) == GetLang("条件")) {
            if (this.CompareProEditItemGui == "")
                this.CompareProEditItemGui := CompareProEditItemGui()
            this.CompareProEditItemGui.IsSubMacroEdit := true
            this.CompareProEditItemGui.SureBtnAction := this.OnSubNodeEdit.Bind(this, this.CurItemID)

            if (MainSoftData.IsModalSubGui && this.Gui != "") {
                this.CompareProEditItemGui.OwnerHwnd := this.Gui.Hwnd
            }
            else {
                this.CompareProEditItemGui.OwnerHwnd := ""
            }

            ParentID := this.MacroTreeViewCon.GetParent(this.CurItemID)
            CommndStr := this.MacroTreeViewCon.GetText(ParentID)
            ItemNumber := this.GetItemNumber(this.CurItemID)
            this.CompareProEditItemGui.MacroEditShowGui(CommndStr, ItemNumber)
            return
        }

        ; 清理→前缀（⭐/🚫 由 GetCmdOnlyText / GetCmdStr 处理）
        cleanText := StrReplace(itemText, "→", "")
        paramsArr := StrSplit(cleanText, "_")
        cmd := GetCmdOnlyText(paramsArr[1])
        ; 图形开始节点：用节点编辑器打开，不走普通指令 SubGui
        if (this._IsGraphStartCmd(cmd)) {
            this._OpenGraphNodeEditor(GetCmdStr(paramsArr[1]), GetCmdSymbol(paramsArr[1]))
            return
        }
        if (!this.SubGuiMap.Has(cmd))
            return
        subGui := this.SubGuiMap[cmd]
        this.OnOpenSubGui(subGui, 2)
    }

    ; 是否为「图形开始节点」序列码（逻辑树中的图入口指令）
    _IsGraphStartCmd(cmd) {
        key := GetLangKey(cmd)
        return key == "图形开始节点" || cmd == GetLang("图形开始节点")
    }

    ; 双击/编辑：打开嵌套节点编辑器，编辑该图形开始节点子图
    _OpenGraphNodeEditor(cmdStr, symbol := "") {
        itemId := this.CurItemID
        parentId := this.MacroTreeViewCon.GetParent(itemId)
        serial := GetLangMacro(cmdStr, 2)
        if (this.SubMacroGraphGui == "")
            this.SubMacroGraphGui := MacroGraphGui()
        this.SubMacroGraphGui.OwnerHwnd := (MainSoftData.IsModalSubGui && this.Gui != "") ? this.Gui.Hwnd : ""
        this.SubMacroGraphGui.ShowToTreeBtn := true
        this.SubMacroGraphGui.OnClosedAction := ""
        this.SubMacroGraphGui.SureBtnAction := (startSerial) => this._OnGraphNodeEditorSure(itemId, startSerial, symbol)
        ; 「逻辑树」：把该子图转成线性宏写回当前逻辑树（循环体等），不打开顶层编辑器
        this.SubMacroGraphGui.OnSwitchToTreeAction := (linear) => this._OnGraphNodeSwitchToTree(parentId, itemId, linear)
        this.SubMacroGraphGui.ShowGui(serial)
    }

    ; 嵌套节点编辑器点「逻辑树」：子图转线性后写回所属分支并刷新树
    _OnGraphNodeSwitchToTree(parentId, itemId, linear) {
        displayLinear := GetLangMacro(linear, 1)
        if (displayLinear == "")
            displayLinear := " "
        if (parentId != 0) {
            try this.MacroTreeViewCon.GetText(parentId)
            catch
                return
            this.OnSubNodeEdit(parentId, displayLinear)
            return
        }
        ; 根级图形开始节点：用线性宏替换该节点
        try this.MacroTreeViewCon.GetText(itemId)
        catch
            return
        this.CurItemID := itemId
        cmds := SplitMacro(displayLinear)
        if (cmds.Length == 0) {
            this.OnDeleteCmd()
            return
        }
        this.OnModifyCmd(cmds[1])
        loop cmds.Length - 1 {
            this.OnNextInsertCmd(cmds[A_Index + 1])
            ; OnNextInsertCmd 后 CurItemID 仍指向原节点；插在其后需推进选中
            nextId := this.MacroTreeViewCon.GetNext(this.CurItemID)
            if (nextId)
                this.CurItemID := nextId
        }
    }

    _OnGraphNodeEditorSure(itemId, startSerial, symbol := "") {
        ; 先清空回调，避免窗口 Closed 重复触发 _Apply 时二次改树
        if (this.SubMacroGraphGui != "")
            this.SubMacroGraphGui.SureBtnAction := ""
        if (itemId == "" || itemId == 0)
            return
        displayStr := symbol . GetLangMacro(startSerial, 1)
        ; 节点可能已被上次回写 RefreshTree 重建；失效则跳过
        try curText := this.MacroTreeViewCon.GetText(itemId)
        catch
            return
        ; 图内容已由 _SaveGraph 落盘；显示序列码未变则不必改树
        if (GetCmdStr(curText) == GetCmdStr(displayStr))
            return
        this.CurItemID := itemId
        ParentID := this.MacroTreeViewCon.GetParent(itemId)
        if (ParentID == 0) {
            this.OnModifyCmd(displayStr)
            return
        }
        ; 位于真/假/循环体/条件下：改子节点后按分支宏整体回写
        this.MacroTreeViewCon.Modify(itemId, , displayStr)
        macroStr := this.GetTreeMacroStr(ParentID)
        RealItemID := this.MacroTreeViewCon.GetParent(ParentID)
        if (RealItemID == 0)
            return
        try this.MacroTreeViewCon.GetText(RealItemID)
        catch
            return
        this.OnSubNodeEdit(ParentID, macroStr)
    }

    MenuHandler(cmdNextStr, *) {
        switch cmdNextStr {
            case GetLang("变量监视"):
            {
                if (MyVarListenGui.Gui != "" && MyVarListenGui.Gui.Hwnd) {
                    style := WinGetStyle(MyVarListenGui.Gui.Hwnd)
                    isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
                    if (isVisible) {
                        this.ToolMenu.Uncheck(GetLang("变量监视"))
                        MyVarListenGui.Gui.Hide()
                        return
                    }
                }
                this.ToolMenu.Check(GetLang("变量监视"))
                MyVarListenGui.ShowGui()
            }
            case GetLang("指令显示"):
            {
                if (MyCMDTipGui.Gui != "" && MyCMDTipGui.Gui.Hwnd) {
                    style := WinGetStyle(MyCMDTipGui.Gui.Hwnd)
                    isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
                    if (isVisible) {
                        MySoftData.CMDTip := false
                        SetCMDTipValue(false)
                        this.ToolMenu.Uncheck(GetLang("指令显示"))
                        MyCMDTipGui.Gui.Hide()
                        return
                    }
                }
                MySoftData.CMDTip := true
                SetCMDTipValue(true)
                MyCMDTipGui.ShowGui(GetLang("开启指令显示"))
                this.ToolMenu.Check(GetLang("指令显示"))
            }
            case GetLang("窗口置顶"):
            {
                WinSetAlwaysOnTop(-1, this.Gui)
                this.ToolMenu.ToggleCheck(GetLang("窗口置顶"))
            }
            case GetLang("运行(F5)"):
            {
                this.ResetDebugState()
                MacroStr := this.GetMacroStr()
                MacroStr := GetLangMacro(macroStr, 2)
                ResArr := StrSplit(MacroStr, "⭐", 2)
                MacroStr := ResArr.Length > 1 ? ResArr[2] : MacroStr
                MyCMDTipGui.Hide()
                OnTriggerSepcialItemMacro(MacroStr)
                MsgBox(GetLang("调试运行结束"), "", "Owner" this.Gui.Hwnd)
            }
            case GetLang("单步运行(F6)"):
            {
                tableItem := MySoftData.SpecialTableItem
                if (tableItem.ColorStateArr[1] == 1) {
                    return
                }

                ; 阶段1: 定位（首次F6或终止后，查找⭐起点或第一项）
                if (this.DebugItemID == 0) {
                    MyCMDTipGui.Hide()
                    this.DebugItemID := this.FindDebugStartItem()
                    if (!this.DebugItemID) {
                        this.DebugItemID := this.MacroTreeViewCon.GetNext(0)
                    }
                }
                if (!this.DebugItemID)
                    return

                try {
                    CurCMD := this.MacroTreeViewCon.GetText(this.DebugItemID)
                } catch {
                    this.ResetDebugState()
                    return
                }

                ; 阶段2: 跳过不可执行项（🚫禁用和⎖容器配置），自动推进不消耗步数
                while (SubStr(CurCMD, 1, 2) == "🚫" || SubStr(CurCMD, 1, 1) == "⎖") {
                    this.AdvanceToNext()
                    if (!this.DebugItemID)
                        return
                    try {
                        CurCMD := this.MacroTreeViewCon.GetText(this.DebugItemID)
                    } catch {
                        this.ResetDebugState()
                        return
                    }
                }

                ; 阶段3: 标记当前位置 → 执行
                this.MarkCurrentPosition(this.DebugItemID)

                CleanCMD := StrReplace(StrReplace(CurCMD, "⭐", ""), "→", "")
                ; 还原格式化的手柄键名后执行
                CleanCMD := MySoftData.ParseCmdJoyDisplay(CleanCMD)
                CurLangCMD := GetLangMacro(CleanCMD, 2)
                OnTriggerSepcialItemMacro(CurLangCMD)

                ; 阶段4: 推进到下一项
                this.AdvanceToNext()
            }
            case GetLang("终止"):
            {
                KillSingleTableMacro(MySoftData.SpecialTableItem)
                this.ResetDebugState()
                MyCMDTipGui.ShowGui(GetLang("终止"))
            }
        }
    }

    ContentMenuHandler(cmdStr, *) {
        ; 右键菜单关闭后焦点可能落到主界面（菜单归主脚本所有，关闭时焦点不会自动回到编辑器），
        ; 先激活编辑器，避免主界面覆盖逻辑树编辑器
        XamlUiDiag("MenuHandler START cmd=" cmdStr " active=" WinGetID("A") " title=" WinGetTitle("A") " editor=" this.Gui.Hwnd, "focus")
        try WinActivate("ahk_id " this.Gui.Hwnd)
        XamlUiDiag("MenuHandler AFTER activate active=" WinGetID("A") " title=" WinGetTitle("A"), "focus")

        ; 粘贴：允许空树/无选中（追加到根层）；其它操作仍需有效节点
        if (cmdStr == GetLang("粘贴")) {
            this.PasteClipboardCommands(A_Clipboard)
            if (Trim(A_Clipboard, " `t`r`n") != "")
                Toast.Show(GetLang("已粘贴"))
            return
        }

        ; 无有效选中节点时（如刚删除后），复制/删除等快捷键不应报错
        if (!this.CurItemID)
            return
        try
            itemText := this.MacroTreeViewCon.GetText(this.CurItemID)
        catch
            return
        ; 清理→前缀用于状态判断
        cleanItemText := StrReplace(itemText, "→", "")
        paramsArr := StrSplit(cmdStr, "_")
        if (paramsArr.Length == 2) {
            modeType := paramsArr[1] == "Pre" ? 3 : paramsArr[1] == "Next" ? 4 : 5
            this.CmdEditType := modeType
            subGui := this.SubGuiMap[paramsArr[2]]
            this.OnOpenSubGui(subGui, modeType)
            return
        }

        switch cmdStr {
            case GetLang("编辑"):
            {
                paramsArr := StrSplit(cleanItemText, "_")
                cmd := GetCmdOnlyText(paramsArr[1])
                if (this._IsGraphStartCmd(cmd)) {
                    this._OpenGraphNodeEditor(GetCmdStr(paramsArr[1]), GetCmdSymbol(paramsArr[1]))
                    return
                }
                if (!this.SubGuiMap.Has(cmd))
                    return
                subGui := this.SubGuiMap[cmd]
                this.OnOpenSubGui(subGui, 2)
            }
            case "Skip":
            {
                selectedItems := this.GetMultiSelectedItems()

                ; 单条：沿用原逻辑，只处理右键项
                if (selectedItems.Length <= 1) {
                    if (SubStr(cleanItemText, 1, 1) == "⭐") {
                        MsgBox(GetLang("调试起点不能跳过"), "", "Owner" this.Gui.Hwnd)
                        return
                    }
                    IsToSkip := SubStr(cleanItemText, 1, 2) != "🚫"
                    CommandStr := IsToSkip ? "🚫" cleanItemText : SubStr(cleanItemText, 3)
                    this.OnModifyCmd(CommandStr)
                    return
                }

                ; 多选：跳过/取消跳过应用到所有选中项
                for itemID in selectedItems {
                    text := this.MacroTreeViewCon.GetText(itemID)
                    if (SubStr(StrReplace(text, "→", ""), 1, 1) == "⭐") {
                        MsgBox(GetLang("调试起点不能跳过"), "", "Owner" this.Gui.Hwnd)
                        return
                    }
                }

                this.ResetDebugState()
                ; 根据右键项决定跳过/取消跳过方向（与菜单文案一致）
                IsToSkip := SubStr(cleanItemText, 1, 2) != "🚫"
                parentID := this.MacroTreeViewCon.GetParent(selectedItems[1])

                ; 先逐项切换 🚫 前缀（跳过只是文本标记，改文本即可），再统一刷新父分支
                for itemID in selectedItems {
                    text := this.MacroTreeViewCon.GetText(itemID)
                    clean := StrReplace(text, "→", "")
                    hasSkip := SubStr(clean, 1, 2) == "🚫"
                    if (hasSkip == IsToSkip)
                        continue
                    newCmd := IsToSkip ? "🚫" clean : SubStr(clean, 3)
                    this.MacroTreeViewCon.Modify(itemID, , MySoftData.FormatCmdJoyDisplay(newCmd))
                }

                if (parentID == 0) {
                    ; 根层：对分支命令重建子节点（跳过则隐藏子项）
                    for itemID in selectedItems
                        this.RefreshTree(itemID)
                } else {
                    ; 容器层：把修改后的子宏统一写回父分支数据，再刷新
                    macroStr := this.GetTreeMacroStr(parentID)
                    realItemID := this.MacroTreeViewCon.GetParent(parentID)
                    realCommandStr := this.MacroTreeViewCon.GetText(realItemID)
                    this.SaveCommandData(realCommandStr, macroStr, parentID)
                    this.RefreshTree(realItemID)
                }
                this.ClearMultiSelection()
            }
            case "Debug":
                if (SubStr(cleanItemText, 1, 2) == "🚫") {
                    MsgBox(GetLang("跳过指令不可设置为调试起点"), "", "Owner" this.Gui.Hwnd)
                    return
                }
                IsToDebug := SubStr(cleanItemText, 1, 1) != "⭐"
                CommandStr := IsToDebug ? "⭐" cleanItemText : SubStr(cleanItemText, 2)
                ; ⭐是持久标记，由F6单步时FindDebugStartItem查找，不直接设DebugItemID
                this.OnModifyCmd(CommandStr)
            case GetLang("复制"):
            {
                selectedItems := this.GetMultiSelectedItems()
                if (selectedItems.Length <= 1) {
                    newCmd := FullCopyCmd(cleanItemText)
                    SetClipboard(newCmd)
                    Toast.Show(GetLang("已复制"))
                    return
                }

                ; 多選複製：依 TreeView 中的原始順序輸出，以逗號組成可再次 SplitMacro() 的宏字串。
                copyStr := ""
                for itemID in selectedItems {
                    try {
                        text := this.MacroTreeViewCon.GetText(itemID)
                    } catch {
                        continue
                    }
                    text := StrReplace(text, "⭐", "")
                    text := StrReplace(text, "→", "")
                    if (text == "" || SubStr(text, 1, 1) == "⎖")
                        continue
                    cmd := FullCopyCmd(text)
                    if (cmd != "")
                        copyStr .= (copyStr == "" ? "" : ",") cmd
                }
                if (copyStr != "")
                    SetClipboard(copyStr)
                Toast.Show(GetLang("已复制"))
            }
            case "SharedCopy":
            {
                ; 共享复制：原样复制指令文本，不重新分配内部序列号，方便分享到其他宏/其他设备
                selectedItems := this.GetMultiSelectedItems()
                if (selectedItems.Length <= 1) {
                    SetClipboard(cleanItemText)
                    Toast.Show(GetLang("已复制"))
                    return
                }

                copyStr := ""
                for itemID in selectedItems {
                    try {
                        text := this.MacroTreeViewCon.GetText(itemID)
                    } catch {
                        continue
                    }
                    text := StrReplace(text, "⭐", "")
                    text := StrReplace(text, "→", "")
                    if (text == "" || SubStr(text, 1, 1) == "⎖")
                        continue
                    if (text != "")
                        copyStr .= (copyStr == "" ? "" : ",") text
                }
                if (copyStr != "")
                    SetClipboard(copyStr)
                Toast.Show(GetLang("已复制"))
            }
            case GetLang("删除"):
            {
                this.OnDeleteCmd()
            }
        }
    }

    ; 重置调试状态（清除位置和→标记）
    ResetDebugState() {
        this.DebugItemID := 0
        this.ClearCurrentPosition()
    }

    ; 在指定项上加→前缀，表示当前位置（同时清除旧位置）
    MarkCurrentPosition(itemID) {
        ; 先清除旧的→标记
        if (this.CurrentItemID && this.CurrentItemID != itemID) {
            try {
                oldText := this.MacroTreeViewCon.GetText(this.CurrentItemID)
                if (SubStr(oldText, 1, 1) == "→") {
                    this.MacroTreeViewCon.Modify(this.CurrentItemID, , SubStr(oldText, 2))
                }
            } catch {
                ; 旧项可能已失效，忽略
            }
        }
        ; 在新项上加→（保留⭐标记）
        try {
            text := this.MacroTreeViewCon.GetText(itemID)
            hasStar := SubStr(text, 1, 1) == "⭐"
            cleanText := StrReplace(text, "⭐", "")
            cleanText := StrReplace(cleanText, "→", "")
            if (SubStr(cleanText, 1, 2) != "🚫" && SubStr(cleanText, 1, 1) != "⎖") {
                newText := hasStar ? "→⭐" cleanText : "→" cleanText
                this.MacroTreeViewCon.Modify(itemID, , newText)
            }
        } catch {
            ; 忽略
        }
        this.CurrentItemID := itemID
    }

    ; 清除当前项的→标记
    ClearCurrentPosition() {
        if (!this.CurrentItemID)
            return
        try {
            text := this.MacroTreeViewCon.GetText(this.CurrentItemID)
            if (SubStr(text, 1, 1) == "→") {
                this.MacroTreeViewCon.Modify(this.CurrentItemID, , SubStr(text, 2))
            }
        } catch {
            ; 忽略
        }
        this.CurrentItemID := 0
    }

    ; 推进到下一个可执行项，到达末尾时直接结束
    AdvanceToNext() {
        safeCount := 0
        loop {
            if (safeCount++ > 1000) {
                this.ResetDebugState()
                return
            }
            try
                nextID := this.MacroTreeViewCon.GetNext(this.DebugItemID)
            catch {
                this.ResetDebugState()
                MsgBox(GetLang("单步运行结束"), "", "Owner" this.Gui.Hwnd)
                return
            }
            if (!nextID) {
                ; 到达当前层级末尾，直接结束
                this.ResetDebugState()
                MsgBox(GetLang("单步运行结束"), "", "Owner" this.Gui.Hwnd)
                return
            }
            this.DebugItemID := nextID

            try {
                cmdNextStr := this.MacroTreeViewCon.GetText(this.DebugItemID)
            } catch {
                this.ResetDebugState()
                MsgBox(GetLang("单步运行结束"), "", "Owner" this.Gui.Hwnd)
                return
            }

            ; 跳过禁用项和特殊容器配置项
            if (SubStr(cmdNextStr, 1, 2) == "🚫" || SubStr(cmdNextStr, 1, 1) == "⎖")
                continue

            break
        }
        ; 到达下一个可执行项，标记为当前位置
        this.MarkCurrentPosition(this.DebugItemID)
    }

    ; 递归遍历整个TreeView（含子分支），查找带⭐的调试起点项
    FindDebugStartItem(startID := 0) {
        itemID := this.MacroTreeViewCon.GetNext(startID)
        while (itemID) {
            try
                text := this.MacroTreeViewCon.GetText(itemID)
            catch {
                try
                    itemID := this.MacroTreeViewCon.GetNext(itemID)
                catch
                    break
                continue
            }
            ; 当前项就是⭐起点
            if (SubStr(text, 1, 1) == "⭐")
                return itemID
            ; 递归检查子分支（支持任意层级嵌套）
            found := this._FindStarInChildren(itemID)
            if (found)
                return found
            try
                itemID := this.MacroTreeViewCon.GetNext(itemID)
            catch
                break
        }
        return 0
    }

    ; 在指定节点的所有后代中递归查找⭐
    _FindStarInChildren(parentID) {
        try
            childID := this.MacroTreeViewCon.GetChild(parentID)
        catch
            return 0
        while (childID) {
            try
                childText := this.MacroTreeViewCon.GetText(childID)
            catch {
                try
                    childID := this.MacroTreeViewCon.GetNext(childID)
                catch
                    break
                continue
            }
            if (SubStr(childText, 1, 1) == "⭐")
                return childID
            ; 递归深入子节点的子节点
            deeper := this._FindStarInChildren(childID)
            if (deeper)
                return deeper
            try
                childID := this.MacroTreeViewCon.GetNext(childID)
            catch
                break
        }
        return 0
    }

    InitTreeView(MacroStr) {
        this.ResetDebugState()
        this.ClearMultiSelection()
        this.MacroTreeViewCon.Visible := this.EditModeCon.Value == 1
        cmdArr := SplitMacro(MacroStr)
        this.MacroTreeViewCon.Opt("-Redraw")
        this.MacroTreeViewCon.Delete()
        this.LastItemID := 0
        for cmdStr in cmdArr {
            iconStr := this.GetCmdIconStr(cmdStr)
            displayStr := MySoftData.FormatCmdJoyDisplay(cmdStr)
            root := this.MacroTreeViewCon.Add(displayStr, 0, iconStr)
            this.LastItemID := root
            this.TreeAddBranch(root, cmdStr)
        }
        this.MacroTreeViewCon.Opt("+Redraw")
    }

    RefreshTree(itemID) {
        this.ClearMultiSelection()
        CommandStr := this.MacroTreeViewCon.GetText(itemID)
        paramsArr := StrSplit(CommandStr, "_")

        ; 重建分支时先禁用重绘，避免逐条删除/重建节点引起树形控件闪烁（与 InitTreeView 一致）
        this.MacroTreeViewCon.Opt("-Redraw")
        subItem := this.MacroTreeViewCon.GetChild(itemID)
        while (subItem) {
            this.MacroTreeViewCon.Delete(subItem)
            subItem := this.MacroTreeViewCon.GetChild(itemID)
        }
        this.TreeAddBranch(itemID, CommandStr)
        this.TreeExpand(itemID, 2)
        this.MacroTreeViewCon.Opt("+Redraw")
    }

    TreeAddBranch(root, cmdStr) {
        paramArr := StrSplit(cmdStr, "_")
        IsSkip := SubStr(paramArr[1], 1, 2) == "🚫"
        IsSearchPro := InStr(paramArr[1], GetLang("搜索Pro"))
        IsSearch := InStr(paramArr[1], GetLang("搜索")) && !IsSearchPro
        IsIfPro := InStr(paramArr[1], GetLang("如果Pro"))
        IsIf := InStr(paramArr[1], GetLang("如果")) && !IsIfPro
        IsLoop := InStr(paramArr[1], GetLang("循环"))
        Cmd := GetCmdOnlyText(paramArr[1])
        SerialStr := GetCmdStr(paramArr[1])
        if (IsSkip)
            return
        if (!IsSearch && !IsSearchPro && !IsIf && !IsLoop && !IsIfPro)
            return

        ParentID := this.MacroTreeViewCon.GetParent(root)
        while (ParentID != 0) {
            itemText := this.MacroTreeViewCon.GetText(ParentID)
            itemParamArr := StrSplit(itemText, "_")
            ParentID := this.MacroTreeViewCon.GetParent(ParentID)
            if (itemParamArr[1] == paramArr[1])
                return
        }

        Data := GetMacroCMDData(SerialStr)
        if (IsIf || IsSearch || IsSearchPro) {
            TrueMacro := GetLangMacro(Data.TrueMacro, 1)
            FalseMacro := GetLangMacro(Data.FalseMacro, 1)

            iconStr := this.GetCmdIconStr(GetLang("真"))
            trueRoot := this.MacroTreeViewCon.Add(GetLang("真"), root, iconStr)
            ControlType := IsIf ? Data.TrueControlType : "无"
            this.TreeAddSubTree(trueRoot, TrueMacro)
            this.TreeAddControl(trueRoot, ControlType)

            iconStr := this.GetCmdIconStr(GetLang("假"))
            falseRoot := this.MacroTreeViewCon.Add(GetLang("假"), root, iconStr)
            ControlType := IsIf ? Data.FalseControlType : "无"
            this.TreeAddSubTree(falseRoot, FalseMacro)
            this.TreeAddControl(falseRoot, ControlType)
        }
        else if (IsLoop) {
            iconStr := this.GetCmdIconStr(GetLang("循环次数"))
            countStr := Data.LoopCount == -1 ? GetLang("无限") : Data.LoopCount
            CountRoot := this.MacroTreeViewCon.Add(Format("{}:{}", GetLang("⎖循环次数"), countStr), root, iconStr)

            if (Data.CondiType != 1) {
                iconStr := this.GetCmdIconStr(GetLang("条件"))
                CondiStr := Data.CondiType == 2 ? GetLang("⎖继续条件：") : GetLang("⎖退出条件：")
                ItemStr := CondiStr . LoopData.GetCondiStr(Data)
                CondiRoot := this.MacroTreeViewCon.Add(ItemStr, root, iconStr)
            }

            iconStr := this.GetCmdIconStr(GetLang("循环体"))
            BodyRoot := this.MacroTreeViewCon.Add(GetLang("循环体"), root, iconStr)
            LoopBody := GetLangMacro(Data.LoopBody, 1)
            this.TreeAddSubTree(BodyRoot, LoopBody)
        }
        else if (IsIfPro) {
            iconStr := this.GetCmdIconStr(GetLang("条件"))
            loop Data.VariNameArr.Length {
                CondiStr := GetLang("条件：") CompareProData.GetCondiStr(Data, A_Index)
                CondiRoot := this.MacroTreeViewCon.Add(CondiStr, root, iconStr)
                MacroStr := GetLangMacro(Data.MacroArr[A_Index], 1)
                this.TreeAddSubTree(CondiRoot, MacroStr)
                this.TreeAddControl(CondiRoot, Data.ControlTypeArr[A_Index])
            }

            CondiStr := GetLang("条件：以上都不是")
            CondiRoot := this.MacroTreeViewCon.Add(CondiStr, root, iconStr)
            DefaultMacro := GetLangMacro(Data.DefaultMacro, 1)
            this.TreeAddSubTree(CondiRoot, DefaultMacro)
            this.TreeAddControl(CondiRoot, Data.DefaultControlType)
        }
    }

    TreeAddControl(root, ControlType) {
        if (ControlType == "无")
            return

        iconStr := this.GetCmdIconStr(GetLang("流程控制"))
        ItemStr := GetLang("⎖流程控制：") . GetLang(ControlType)
        this.MacroTreeViewCon.Add(ItemStr, root, iconStr)
    }

    TreeAddSubTree(root, CommandStr) {
        if (CommandStr == "")
            return

        cmdArr := SplitMacro(CommandStr)
        for cmdStr in cmdArr {
            iconStr := this.GetCmdIconStr(cmdStr)
            displayStr := MySoftData.FormatCmdJoyDisplay(cmdStr)
            subRoot := this.MacroTreeViewCon.Add(displayStr, root, iconStr)
            this.TreeAddBranch(subRoot, cmdStr)
        }
    }

    ; 子指令窗口是否正在显示（用于同类型多开判断）
    IsSubGuiVisible(subGui) {
        if (!IsObject(subGui) || !ObjHasOwnProp(subGui, "Gui") || subGui.Gui == "")
            return false
        try {
            return (WinGetStyle(subGui.Gui.Hwnd) & 0x10000000) != 0  ; WS_VISIBLE
        } catch {
            return false
        }
    }

    ; 收集某共享子 GUI 同类型的全部实例（共享 + 多开额外实例）
    GetSubGuiInstances(sharedGui) {
        list := [sharedGui]
        for g in this.OpenedSubGuis {
            if (IsObject(g) && Type(g) == Type(sharedGui))
                list.Push(g)
        }
        return list
    }

    ; 同一编辑上下文（类型+mode+节点）已打开则复用并前置；不同节点可多开
    ResolveSubGuiInstance(sharedGui, modeType, itemId) {
        for g in this.GetSubGuiInstances(sharedGui) {
            if (!this.IsSubGuiVisible(g))
                continue
            openType := ObjHasOwnProp(g, "_OpenEditType") ? g._OpenEditType : ""
            openItem := ObjHasOwnProp(g, "_OpenItemId") ? g._OpenItemId : ""
            if (openType == modeType && openItem == itemId)
                return g
        }
        for g in this.GetSubGuiInstances(sharedGui) {
            if (!this.IsSubGuiVisible(g))
                return g
        }
        guiClass := ""
        for config in this.SubGuiConfig {
            if (this.SubGuiMap[GetLang(config.name)] == sharedGui) {
                guiClass := config.class
                break
            }
        }
        if (guiClass == "")
            return sharedGui
        newGui := guiClass()
        this.OpenedSubGuis.Push(newGui)
        return newGui
    }

    ;打开子指令编辑器 modeType 1:默认行尾追加 2:编辑修改 3:上方插入 4:下方插入 5:真假节点添加
    OnOpenSubGui(subGui, modeType := 1) {
        this.CmdEditType := modeType
        editType := modeType
        itemId := this.CurItemID

        ; 同节点再开：复用并覆盖前置；不同节点：多开新实例
        subGui := this.ResolveSubGuiInstance(subGui, modeType, itemId)
        subGui._OpenEditType := modeType
        subGui._OpenItemId := itemId

        if ObjHasOwnProp(subGui, "ParentTile") {
            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            subGui.ParentTile := ParentTile "-"
        }

        if (MainSoftData.IsModalSubGui && this.Gui != "") {
            subGui.OwnerHwnd := this.Gui.Hwnd
        }
        else {
            subGui.OwnerHwnd := ""
        }

        ; 绑定打开时的编辑上下文，多开时互不干扰
        subGui.SureBtnAction := (CommandStr) => this.OnSubGuiSureBtnClick(CommandStr, editType, itemId)

        if (modeType == 2) {
            ItemText := this.MacroTreeViewCon.GetText(this.CurItemID)
            ; 清理→和⭐前缀
            ; 只清理位置标记→（前缀，不是方向箭头显示名）
            ItemText := StrReplace(ItemText, "⭐", "")
            if SubStr(ItemText, 1, 1) = "→"
                ItemText := SubStr(ItemText, 2)
            ; 还原显示名 + 转 BtnN → Joy* 后传给旧 GUI 编辑器
            ItemText := MySoftData.ParseCmdJoyDisplay(ItemText)
            ItemText := MySoftData.CmdJoyNToJoyFriendly(ItemText)
            CommandStr := GetCmdStr(ItemText)
            subGui.ShowGui(CommandStr)
            return
        }
        subGui.ShowGui("")
    }

    ;确定子指令编辑器（editType/itemId 为打开时捕获的上下文）
    OnSubGuiSureBtnClick(CommandStr, editType := 1, itemId := 0) {
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        savedType := this.CmdEditType
        savedItem := this.CurItemID
        this.CmdEditType := editType
        if (itemId != 0)
            this.CurItemID := itemId

        if (editType == 1) {
            this.OnAddCmd(CommandStr)
        }
        else if (editType == 2) {
            this.OnModifyCmd(CommandStr)
        }
        else if (editType == 3) {
            this.OnPreInsertCmd(CommandStr)
        }
        else if (editType == 4) {
            this.OnNextInsertCmd(CommandStr)
        }
        else if (editType == 5) {
            this.OnSubNodeAddCmd(CommandStr)
        }

        this.CmdEditType := savedType
        this.CurItemID := savedItem
        UIControls.RecordToggle := this.RecordMacroCon
        MainSoftData.MacroEditGui := this
    }

    ;添加指令
    OnAddCmd(CommandStr) {
        this.ResetDebugState()
        if (this.EditModeCon.Value == 1) {
            iconStr := this.GetCmdIconStr(CommandStr)
            displayStr := MySoftData.FormatCmdJoyDisplay(CommandStr)
            root := this.MacroTreeViewCon.Add(displayStr, 0, iconStr)
            this.TreeAddBranch(root, CommandStr)
            this.LastItemID := root
            this._SelectCurrent(root)
        }
        else {
            MacroStr := this.GetMacroStr()
            MacroStr .= "`n" CommandStr
            cmdArr := SplitMacro(MacroStr)
            MacroStr := GetMacroStrByCmdArr(cmdArr)

            ; 回到替换前的滑动值
            firstVisible := SendMessage(0xCE, 0, 0, this.MacroEditTextCon) ; EM_GETFIRSTVISIBLELINE = 0xCE
            this.InitMacroText(MacroStr)
            SendMessage(0xB6, 0, firstVisible, this.MacroEditTextCon) ; EM_LINESCROLL = 0xB6
        }
    }

    ;修改指令
    OnModifyCmd(CommandStr) {
        this.ResetDebugState()
        this.MacroTreeViewCon.Modify(this.CurItemID, , MySoftData.FormatCmdJoyDisplay(CommandStr))
        ParentID := this.MacroTreeViewCon.GetParent(this.CurItemID)
        if (ParentID == 0) {
            this.RefreshTree(this.CurItemID)
            return
        }

        macroStr := this.GetTreeMacroStr(ParentID)
        RealItemID := this.MacroTreeViewCon.GetParent(ParentID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)

        this.SaveCommandData(RealCommandStr, macroStr, ParentID)
        this.RefreshTree(RealItemID)
    }

    OnPreMoveCmd() {
        PreItemID := this.MacroTreeViewCon.GetPrev(this.CurItemID)
        if (PreItemID == 0) {
            MsgBox(GetLang("已经是第一个指令了，无法上移"))
            return
        }
        PreText := this.MacroTreeViewCon.GetText(PreItemID)
        if (PreText == "" || SubStr(PreText, 1, 1) == "⎖") {
            MsgBox(GetLang("不可与特殊指令进行交换"))
            return
        }
        this.OnSwitchCmd(PreItemID, this.CurItemID)
    }

    OnNextMoveCmd() {
        NextItemID := this.MacroTreeViewCon.GetNext(this.CurItemID)
        if (NextItemID == 0) {
            MsgBox(GetLang("已经是最后的指令了，无法下移"))
            return
        }
        NextText := this.MacroTreeViewCon.GetText(NextItemID)
        if (NextText == "" || SubStr(NextText, 1, 1) == "⎖") {
            MsgBox(GetLang("不可与特殊指令进行交换"))
            return
        }
        this.OnSwitchCmd(this.CurItemID, NextItemID)
    }

    OnSwitchCmd(ItemAID, ItemBID) {
        this.ResetDebugState()
        LastItemID := this.MacroTreeViewCon.GetPrev(ItemAID)
        ParentID := this.MacroTreeViewCon.GetParent(ItemAID)
        NewACmdStr := this.MacroTreeViewCon.GetText(ItemBID)
        NewBCmdStr := this.MacroTreeViewCon.GetText(ItemAID)
        NewAIconStr := this.GetCmdIconStr(NewACmdStr)
        NewBIconStr := this.GetCmdIconStr(NewBCmdStr)

        this.MacroTreeViewCon.Delete(ItemAID)
        this.MacroTreeViewCon.Delete(ItemBID)
        SortArg := LastItemID == 0 ? "First" : LastItemID
        NewItemAID := this.MacroTreeViewCon.Add(NewACmdStr, ParentID, SortArg " " NewAIconStr)
        NewItemBID := this.MacroTreeViewCon.Add(NewBCmdStr, ParentID, NewItemAID " " NewBIconStr)
        this.TreeAddBranch(NewItemAID, NewACmdStr)
        this.TreeAddBranch(NewItemBID, NewBCmdStr)
        if (ParentID == 0) {
            return
        }

        macroStr := this.GetTreeMacroStr(ParentID)
        RealItemID := this.MacroTreeViewCon.GetParent(ParentID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)

        this.SaveCommandData(RealCommandStr, macroStr, ParentID)
        this.RefreshTree(RealItemID)
    }

    ; Delete 熱鍵與右鍵「刪除」共用這個入口。
    ; 真／假／循環體／條件可以參與多選；刪除時不能直接刪掉容器，
    ; 而是依照單選的語義清空對應分支資料，再統一 RefreshTree。
    OnDeleteCmd() {
        this.ResetDebugState()

        selectedItems := this.GetMultiSelectedItems()
        if (selectedItems.Length == 0 && this.CurItemID)
            selectedItems.Push(this.CurItemID)
        if (selectedItems.Length == 0)
            return

        ; 單選：使用完整的分支刪除邏輯。
        if (selectedItems.Length == 1) {
            this.CurItemID := selectedItems[1]
            this._DeleteSingleCmd(this.CurItemID)
            return
        }

        ; 多選項目必須位於同一層級。
        parentID := this.MacroTreeViewCon.GetParent(selectedItems[1])
        for itemID in selectedItems {
            if (this.MacroTreeViewCon.GetParent(itemID) != parentID) {
                ; 舊狀態若存在跨層多選，退回目前項目的單選刪除。
                this.SetSingleMultiSelection(this.CurItemID ? this.CurItemID : selectedItems[1])
                this.CurItemID := this.CurItemID ? this.CurItemID : selectedItems[1]
                this._DeleteSingleCmd(this.CurItemID)
                return
            }
        }

        ; 根層沒有「真／假／循環體／條件」容器，正常倒序刪除。
        if (parentID == 0) {
            loop selectedItems.Length {
                itemID := selectedItems[selectedItems.Length - A_Index + 1]
                try this.MacroTreeViewCon.Delete(itemID)
            }
            firstID := 0
            try firstID := this.MacroTreeViewCon.GetNext(0)
            this._SelectCurrent(firstID)
            return
        }

        ; parentID 有兩種情況：
        ; 1. parentID 是「真／假／循環體／條件」容器：selectedItems 是其中的普通指令。
        ; 2. parentID 是根層的分支命令：selectedItems 是「真／假／循環體／條件」容器本身。
        parentText := this.MacroTreeViewCon.GetText(parentID)
        parentIsContainer := this.IsContainerNode(parentText)

        if (parentIsContainer) {
            realItemID := this.MacroTreeViewCon.GetParent(parentID)
            if (!realItemID) {
                firstID := 0
                try firstID := this.MacroTreeViewCon.GetNext(0)
                this._SelectCurrent(firstID)
                return
            }
            realCommandStr := this.MacroTreeViewCon.GetText(realItemID)
        } else {
            ; 分支命令本身就是 SaveCommandData 的 RealCommandStr，刷新它即可。
            realItemID := parentID
            realCommandStr := parentText
        }

        ; 同一 Parent 下若有「條件」容器，刪除前先保存原始 ItemNumber。
        ; IfPro 刪除分支時會移除陣列元素，因此必須從後往前處理。
        containerItems := []
        normalItems := []
        for itemID in selectedItems {
            try itemText := this.MacroTreeViewCon.GetText(itemID)
            catch
                continue

            if (this.IsContainerNode(itemText))
                containerItems.Push(itemID)
            else
                normalItems.Push(itemID)
        }

        ; 容器按 TreeView 順序由後往前處理，避免 IfPro 分支編號因前面刪除而位移。
        loop containerItems.Length {
            bestIndex := 1
            bestNumber := this.GetItemNumber(containerItems[1])
            idx := 2
            while (idx <= containerItems.Length) {
                number := this.GetItemNumber(containerItems[idx])
                if (number > bestNumber) {
                    bestIndex := idx
                    bestNumber := number
                }
                idx += 1
            }

            itemID := containerItems.RemoveAt(bestIndex)
            ; 如果Pro 条件分支：显式标记删除，避免与「空分支宏」混淆
            this.SaveCommandData(realCommandStr, "删除条件", itemID)
        }

        ; 一般子指令才直接 Delete；從後往前刪，避免 TreeView handle 互相影響。
        loop normalItems.Length {
            itemID := normalItems[normalItems.Length - A_Index + 1]
            try this.MacroTreeViewCon.Delete(itemID)
        }

        ; 如果 selectedItems 是容器本身，前面的 SaveCommandData 已逐個清空對應分支。
        ; 如果 selectedItems 是容器內普通指令，則需要把剩餘宏重新寫回該容器。
        if (parentIsContainer) {
            macroStr := this.GetTreeMacroStr(parentID)
            isCondi := SubStr(StrReplace(parentText, "→", ""), 1, StrLen(GetLang("条件"))) == GetLang("条件")
            macroStr := macroStr == "" && isCondi ? "空条件" : macroStr
            this.SaveCommandData(realCommandStr, macroStr, parentID)
        }

        this.RefreshTree(realItemID)
        this._SelectCurrent(realItemID)
    }

    ; 單一指令的刪除邏輯。容器節點不能直接 Delete，只能清空它所代表的分支。
    _DeleteSingleCmd(itemID) {
        if (!itemID)
            return

        try
            itemText := this.MacroTreeViewCon.GetText(itemID)
        catch {
            ; 節點已失效（例如剛被刪除）：清空選中，避免快捷鍵反覆報錯
            this._SelectCurrent(0)
            return
        }

        ; 刪除前記錄同層鄰居，供刪除後轉移選中
        nextID := 0
        prevID := 0
        try nextID := this.MacroTreeViewCon.GetNext(itemID)
        try prevID := this.MacroTreeViewCon.GetPrev(itemID)

        isContainer := this.IsContainerNode(itemText)
        ParentID := this.MacroTreeViewCon.GetParent(itemID)

        ; 理論上根層不會出現容器；即使狀態異常，也不要直接刪除容器。
        if (ParentID == 0) {
            if (!isContainer)
                this.MacroTreeViewCon.Delete(itemID)
            this._SelectAfterDelete(0, nextID, prevID)
            return
        }

        NodeItemID := itemID
        RealItemID := ParentID
        ; 容器节点（如果Pro 条件等）：删除分支本身，不是清空宏
        macroStr := isContainer ? "删除条件" : ""

        ; 普通指令：直接删除，再将同层剩余内容写回父容器。
        if (!isContainer) {
            this.MacroTreeViewCon.Delete(itemID)
            NodeItemID := ParentID
            RealItemID := this.MacroTreeViewCon.GetParent(NodeItemID)
            macroStr := this.GetTreeMacroStr(NodeItemID)

            NodeItemText := this.MacroTreeViewCon.GetText(NodeItemID)
            isCondi := SubStr(StrReplace(NodeItemText, "→", ""), 1, StrLen(GetLang("条件"))) == GetLang("条件")
            macroStr := macroStr == "" && isCondi ? "空条件" : macroStr
        }

        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)
        this.SaveCommandData(RealCommandStr, macroStr, NodeItemID)
        this.RefreshTree(RealItemID)

        ; RefreshTree 會重建分支，舊鄰居失效，改選中父分支節點
        this._SelectAfterDelete(RealItemID, 0, 0)
    }

    ; 刪除節點後轉移選中：優先下一個同層，其次上一個同層，最後父級；都沒有則清空
    _SelectAfterDelete(parentID, nextID, prevID) {
        target := 0
        for _, id in [nextID, prevID, parentID] {
            if (!id)
                continue
            try {
                txt := this.MacroTreeViewCon.GetText(id)
                if (txt != "" && SubStr(txt, 1, 1) != "⎖") {
                    target := id
                    break
                }
            } catch {
                continue
            }
        }
        this._SelectCurrent(target)
    }

    ; 把節點設為目前選中項（單選狀態 + 原生高亮）；itemID 為 0 時清空選中
    _SelectCurrent(itemID) {
        this.CurItemID := itemID
        if (!itemID) {
            this.ClearMultiSelection()
            return
        }
        this.SetSingleMultiSelection(itemID)
        try this.MacroTreeViewCon.Modify(itemID, "Select")
    }

    ;插入指令
    OnPreInsertCmd(CommandStr) {
        this.ResetDebugState()
        displayStr := MySoftData.FormatCmdJoyDisplay(CommandStr)
        ParentID := this.MacroTreeViewCon.GetParent(this.CurItemID)
        PreItemID := this.MacroTreeViewCon.GetPrev(this.CurItemID)
        Seq := PreItemID == 0 ? "First" : PreItemID
        iconStr := this.GetCmdIconStr(CommandStr)
        newItemID := this.MacroTreeViewCon.Add(displayStr, ParentID, Seq " " iconStr)
        if (ParentID == 0) {
            this.TreeAddBranch(newItemID, CommandStr)
            this._SelectCurrent(newItemID)
            return
        }

        macroStr := this.GetTreeMacroStr(ParentID)
        RealItemID := this.MacroTreeViewCon.GetParent(ParentID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)
        this.SaveCommandData(RealCommandStr, macroStr, ParentID)
        this.RefreshTree(RealItemID)
    }

    ; 插入一條指令；返回刷新後可繼續作為插入錨點的 TreeView ItemID。
    OnNextInsertCmd(CommandStr) {
        this.ResetDebugState()

        ; 防止多條指令誤傳進來，避免把「运行,输出,如果」當成一個 command key。
        cmds := SplitMacro(CommandStr)
        if (cmds.Length > 1) {
            this.PasteClipboardCommands(CommandStr)
            return 0
        }

        CommandStr := Trim(CommandStr, " `t`r`n")
        if (CommandStr == "")
            return 0

        anchorItemID := this.CurItemID
        ParentID := this.MacroTreeViewCon.GetParent(anchorItemID)
        insertNumber := 0
        if (ParentID != 0)
            insertNumber := this.GetItemNumber(anchorItemID) + 1

        displayStr := MySoftData.FormatCmdJoyDisplay(CommandStr)
        iconStr := this.GetCmdIconStr(CommandStr)
        newItemID := this.MacroTreeViewCon.Add(displayStr, ParentID, anchorItemID " " iconStr)
        if (anchorItemID == this.LastItemID)
            this.LastItemID := newItemID

        if (ParentID == 0) {
            this.TreeAddBranch(newItemID, CommandStr)
            this._SelectCurrent(newItemID)
            return newItemID
        }

        macroStr := this.GetTreeMacroStr(ParentID)
        RealItemID := this.MacroTreeViewCon.GetParent(ParentID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)
        this.SaveCommandData(RealCommandStr, macroStr, ParentID)
        this.RefreshTree(RealItemID)

        ; RefreshTree 會重建整個分支，舊的 newItemID 已失效。
        ; 依原本插入位置重新找回新節點，讓下一條指令可以繼續插在它後面。
        if (insertNumber > 0) {
            childID := this.MacroTreeViewCon.GetChild(ParentID)
            index := 1
            foundID := 0
            while (childID) {
                text := this.MacroTreeViewCon.GetText(childID)
                if (SubStr(text, 1, 1) != "⎖") {
                    if (index == insertNumber) {
                        foundID := childID
                        break
                    }
                    index += 1
                }
                childID := this.MacroTreeViewCon.GetNext(childID)
            }
            if (foundID) {
                this._SelectCurrent(foundID)
                return foundID
            }
        }

        this.CurItemID := 0
        return 0
    }

    ; 粘貼到真/假/循環體/條件容器節點內部：把指令追加到該分支末尾並回寫。
    ; 容器節點不能像普通指令一樣在同層級插入，否則 GetParent 取到根後 GetText(0) 報錯。
    PasteIntoContainer(containerID, cmds) {
        realItemID := this.MacroTreeViewCon.GetParent(containerID)
        if (!realItemID)
            return

        realCommandStr := this.MacroTreeViewCon.GetText(realItemID)
        macroStr := this.GetTreeMacroStr(containerID)

        for _, cmdStr in cmds {
            cmdStr := Trim(cmdStr, " `t`r`n")
            if (cmdStr == "")
                continue
            macroStr := (macroStr == "" ? "" : macroStr ",") cmdStr
        }

        this.SaveCommandData(realCommandStr, macroStr, containerID)
        this.RefreshTree(realItemID)
        this.CurItemID := 0
    }

    ; 將剪貼簿中的單條或多條宏指令逐條貼上。
    ; 無選中/空樹：追加到根層末尾（等同添加指令）。
    PasteClipboardCommands(ClipboardStr) {
        ClipboardStr := Trim(ClipboardStr, " `t`r`n")
        if (ClipboardStr == "")
            return

        cmds := SplitMacro(ClipboardStr)
        if (cmds.Length == 0)
            return

        anchorID := this.CurItemID
        anchorText := ""
        if (anchorID) {
            try anchorText := this.MacroTreeViewCon.GetText(anchorID)
            catch
                anchorID := 0
        }
        anchorText := StrReplace(anchorText, "→", "")

        ; 無有效錨點（空樹或刪光後）：逐條追加到根層
        if (!anchorID) {
            firstInserted := 0
            for _, cmdStr in cmds {
                cmdStr := Trim(cmdStr, " `t`r`n")
                if (cmdStr == "")
                    continue
                this.OnAddCmd(cmdStr)
                if (!firstInserted && this.CurItemID)
                    firstInserted := this.CurItemID
            }
            if (firstInserted)
                this._SelectCurrent(firstInserted)
            return
        }

        ; ⎖ 開頭的是資訊/控制顯示節點（循環次數、繼續/退出條件、流程控制），不允許粘貼。
        if (SubStr(anchorText, 1, 1) == "⎖")
            return

        ; 真/假/循環體/條件 容器節點：粘貼到容器內部（追加到該分支），而非與容器同層級。
        if (this.IsContainerNode(anchorText)) {
            this.PasteIntoContainer(anchorID, cmds)
            return
        }

        ; 單條直接走原本的插入流程。
        if (cmds.Length == 1) {
            this.OnNextInsertCmd(cmds[1])
            return
        }

        parentID := this.MacroTreeViewCon.GetParent(anchorID)

        ; 根層：逐條插入，OnNextInsertCmd 會把 CurItemID 推進到上一條新指令。
        if (parentID == 0) {
            firstInserted := 0
            for _, cmdStr in cmds {
                cmdStr := Trim(cmdStr, " `t`r`n")
                if (cmdStr == "")
                    continue

                insertedID := this.OnNextInsertCmd(cmdStr)
                if (!firstInserted && insertedID)
                    firstInserted := insertedID
            }
            if (firstInserted)
                this._SelectCurrent(firstInserted)
            return
        }

        ; 分支內：一次重建該分支宏，避免 RefreshTree 後舊 ItemID 失效。
        branchIndex := this.GetItemNumber(parentID)
        anchorIndex := this.GetItemNumber(anchorID)

        macroStr := this.GetTreeMacroStr(parentID)
        existingCmds := SplitMacro(macroStr)
        if (anchorIndex > existingCmds.Length)
            anchorIndex := existingCmds.Length

        mergedCmds := []
        for i, cmdStr in existingCmds {
            if (i == anchorIndex + 1) {
                for _, pasteCmd in cmds {
                    pasteCmd := Trim(pasteCmd, " `t`r`n")
                    if (pasteCmd != "")
                        mergedCmds.Push(pasteCmd)
                }
            }
            mergedCmds.Push(cmdStr)
        }

        ; 原本錨點在分支末尾時，插入內容要放到最後。
        if (anchorIndex >= existingCmds.Length) {
            for _, pasteCmd in cmds {
                pasteCmd := Trim(pasteCmd, " `t`r`n")
                if (pasteCmd != "")
                    mergedCmds.Push(pasteCmd)
            }
        }

        newMacroStr := ""
        for _, cmdStr in mergedCmds
            newMacroStr .= (newMacroStr == "" ? "" : ",") cmdStr

        realItemID := this.MacroTreeViewCon.GetParent(parentID)
        if (!realItemID)
            return
        realCommandStr := this.MacroTreeViewCon.GetText(realItemID)
        this.SaveCommandData(realCommandStr, newMacroStr, parentID)
        this.RefreshTree(realItemID)

        ; RefreshTree 後重新找回原本的分支節點。
        newParentID := this.GetNthChildItem(realItemID, branchIndex)
        if (!newParentID)
            return

        ; 找到插入區段最後一條，讓後續操作仍停在貼上的內容附近。
        targetIndex := anchorIndex + cmds.Length
        targetID := this.GetNthCommandChild(newParentID, targetIndex)
        if (targetID)
            this._SelectCurrent(targetID)
    }

    ; 取得 parent 的第 N 個直接子節點（1-based）。
    GetNthChildItem(parentID, wantedIndex) {
        if (!parentID || wantedIndex < 1)
            return 0

        childID := this.MacroTreeViewCon.GetChild(parentID)
        index := 1
        while (childID) {
            if (index == wantedIndex)
                return childID
            index += 1
            childID := this.MacroTreeViewCon.GetNext(childID)
        }
        return 0
    }

    ; 取得 branch 下第 N 條真正宏指令，忽略 ⎖ 控制項。
    GetNthCommandChild(parentID, wantedIndex) {
        if (!parentID || wantedIndex < 1)
            return 0

        childID := this.MacroTreeViewCon.GetChild(parentID)
        index := 1
        while (childID) {
            text := this.MacroTreeViewCon.GetText(childID)
            if (text != "" && SubStr(text, 1, 1) != "⎖") {
                if (index == wantedIndex)
                    return childID
                index += 1
            }
            childID := this.MacroTreeViewCon.GetNext(childID)
        }
        return 0
    }

    OnSubNodeAddCmd(CommandStr) {
        displayStr := MySoftData.FormatCmdJoyDisplay(CommandStr)
        iconStr := this.GetCmdIconStr(CommandStr)
        newItemID := this.MacroTreeViewCon.Add(displayStr, this.CurItemID, iconStr)
        macroStr := this.GetTreeMacroStr(this.CurItemID)

        RealItemID := this.MacroTreeViewCon.GetParent(this.CurItemID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)
        this.SaveCommandData(RealCommandStr, macroStr, this.CurItemID)
        this.RefreshTree(RealItemID)
    }

    OnSubNodeEdit(nodeItemID, macroStr) {
        RealItemID := this.MacroTreeViewCon.GetParent(nodeItemID)
        RealCommandStr := this.MacroTreeViewCon.GetText(RealItemID)
        macroStr := macroStr == "" ? " " : macroStr
        this.SaveCommandData(RealCommandStr, macroStr, nodeItemID)
        this.RefreshTree(RealItemID)
    }

    TreeExpand(ItemID, Num) {
        if (Num == 0)
            return

        rootItemID := this.MacroTreeViewCon.GetChild(ItemID)
        while (rootItemID) {
            this.MacroTreeViewCon.Modify(rootItemID, "Expand")
            this.TreeExpand(rootItemID, Num - 1)
            rootItemID := this.MacroTreeViewCon.GetNext(rootItemID)
        }
    }

    ExpandAll() {
        this.MacroTreeViewCon.Opt("-Redraw")
        rootItemID := this.MacroTreeViewCon.GetNext(0)
        while (rootItemID) {
            this.MacroTreeViewCon.Modify(rootItemID, "Expand")
            this.TreeExpandRecursive(rootItemID)
            rootItemID := this.MacroTreeViewCon.GetNext(rootItemID)
        }
        this.MacroTreeViewCon.Opt("+Redraw")
    }

    TreeExpandRecursive(ItemID) {
        childID := this.MacroTreeViewCon.GetChild(ItemID)
        while (childID) {
            this.MacroTreeViewCon.Modify(childID, "Expand")
            this.TreeExpandRecursive(childID)
            childID := this.MacroTreeViewCon.GetNext(childID)
        }
    }

    CollapseAll() {
        this.MacroTreeViewCon.Opt("-Redraw")
        itemID := this.MacroTreeViewCon.GetNext(0)
        while (itemID) {
            this.TreeCollapse(itemID)
            itemID := this.MacroTreeViewCon.GetNext(itemID)
        }
        this.MacroTreeViewCon.Opt("+Redraw")
    }

    TreeCollapse(ItemID) {
        childID := this.MacroTreeViewCon.GetChild(ItemID)
        while (childID) {
            this.TreeCollapse(childID)
            childID := this.MacroTreeViewCon.GetNext(childID)
        }
        if (this.MacroTreeViewCon.GetChild(ItemID))
            SendMessage(0x1102, 0x1, ItemID, this.MacroTreeViewCon)
    }

    GetTreeMacroStr(ItemID) {
        macroStr := ""
        rootItemID := this.MacroTreeViewCon.GetChild(ItemID)
        while (rootItemID) {
            cmdStr := this.MacroTreeViewCon.GetText(rootItemID)
            if (cmdStr != "" && SubStr(cmdStr, 1, 1) != "⎖")
                macroStr .= MySoftData.ParseCmdJoyDisplay(cmdStr) ","

            rootItemID := this.MacroTreeViewCon.GetNext(rootItemID)
        }
        macroStr := Trim(macroStr, ",")
        return macroStr
    }

    ; ==================== 多選複製 ====================

    SetSingleMultiSelection(itemID) {
        this.ClearMultiSelection()
        if (!itemID)
            return
        this.SetMultiSelected(itemID, true)
        this.MultiSelectAnchor := itemID
    }

    SetMultiSelected(itemID, isSelected) {
        if (!itemID)
            return

        if (isSelected) {
            try this.MacroTreeViewCon.Modify(itemID, "Check")
            catch
                return
            this.MultiSelectItems[itemID] := true
        } else {
            try this.MacroTreeViewCon.Modify(itemID, "-Check")
            this.MultiSelectItems.Delete(itemID)
        }
    }

    ClearMultiSelection() {
        if (!IsObject(this.MultiSelectItems))
            this.MultiSelectItems := Map()

        for itemID in this.MultiSelectItems {
            try this.MacroTreeViewCon.Modify(itemID, "-Check")
        }
        this.MultiSelectItems.Clear()
        this.MultiSelectAnchor := 0
    }

    ToggleMultiSelection(itemID) {
        if (!itemID)
            return

        ; 多選必須維持在同一層級。
        ; 不同 Parent 的 Ctrl+Click 直接改成單選，避免刪除時 RefreshTree 讓其他 ItemID 失效。
        if (!this.MultiSelectItems.Has(itemID)
            && this.MultiSelectAnchor
            && this.MacroTreeViewCon.GetParent(this.MultiSelectAnchor) != this.MacroTreeViewCon.GetParent(itemID)) {
            this.SetSingleMultiSelection(itemID)
            return
        }

        if (this.MultiSelectItems.Has(itemID))
            this.SetMultiSelected(itemID, false)
        else
            this.SetMultiSelected(itemID, true)
        this.MultiSelectAnchor := itemID
    }

    SelectMultiRange(anchorID, itemID) {
        if (!anchorID || !itemID) {
            this.SetSingleMultiSelection(itemID)
            return
        }

        if (this.MacroTreeViewCon.GetParent(anchorID) != this.MacroTreeViewCon.GetParent(itemID)) {
            this.SetSingleMultiSelection(itemID)
            return
        }

        this.ClearMultiSelection()
        cur := anchorID
        reached := false
        while (cur) {
            this.SetMultiSelected(cur, true)
            if (cur == itemID) {
                reached := true
                break
            }
            cur := this.MacroTreeViewCon.GetNext(cur)
        }

        if (!reached) {
            this.ClearMultiSelection()
            cur := anchorID
            while (cur) {
                this.SetMultiSelected(cur, true)
                if (cur == itemID)
                    break
                cur := this.MacroTreeViewCon.GetPrev(cur)
            }
        }
        this.MultiSelectAnchor := anchorID
    }

    GetMultiSelectedItems() {
        result := []
        this._CollectCheckedItems(0, &result)
        return result
    }

    _CollectCheckedItems(parentID, &result) {
        itemID := parentID == 0 ? this.MacroTreeViewCon.GetNext(0) : this.MacroTreeViewCon.GetChild(parentID)
        while (itemID) {
            if (this.MultiSelectItems.Has(itemID))
                result.Push(itemID)
            this._CollectCheckedItems(itemID, &result)
            itemID := this.MacroTreeViewCon.GetNext(itemID)
        }
    }

    GetCmdIconStr(cmdStr) {
        paramArr := StrSplit(cmdStr, "_")
        paramArr[1] := GetCmdStr(paramArr[1])

        textOnly := RegExReplace(paramArr[1], "\d+")
        if (this.IconMap.Has(textOnly)) {
            return this.IconMap.Get(textOnly)
        }
        return ""
    }

    SaveCommandData(RealCommandStr, macroStr, nodeItemID) {
        paramArr := StrSplit(RealCommandStr, "_")
        cmd := RegExReplace(paramArr[1], "\d+")

        ; 映射表：命令 → 文件名
        fileMap := Map(
            GetLang("搜索"), SearchFile,
            GetLang("搜索Pro"), SearchProFile,
            GetLang("抓图"), ScreenShotFile,
            GetLang("如果"), CompareFile,
            GetLang("如果Pro"), CompareProFile,
            GetLang("循环"), LoopFile
        )
        if (!fileMap.Has(cmd))
            return

        ItemNumber := this.GetItemNumber(nodeItemID)
        Data := GetMacroCMDData(paramArr[1])
        macroStr := GetLangMacro(macroStr, 2)
        if (cmd == GetLang("循环")) {
            Data.LoopBody := macroStr
        }
        else if (cmd == GetLang("如果Pro")) {
            if (ItemNumber > Data.VariNameArr.Length) {
                ; 兜底分支不可删除，仅允许清空指令
                if (macroStr == "删除条件" || macroStr == "")
                    MsgBox(GetLang("最后的分支不能删除，若无需该分支请清空分支指令"))
                Data.DefaultMacro := (macroStr == "空条件" || macroStr == "删除条件") ? "" : Trim(macroStr)
            }
            else {
                ; 删除条件：显式删除该分支；空条件/空串：仅清空分支宏，保留条件本身
                if (macroStr == "删除条件") {
                    if (Data.ControlTypeArr.Length >= ItemNumber)
                        Data.ControlTypeArr.RemoveAt(ItemNumber)
                    Data.VariNameArr.RemoveAt(ItemNumber)
                    Data.CompareTypeArr.RemoveAt(ItemNumber)
                    Data.VariableArr.RemoveAt(ItemNumber)
                    Data.LogicTypeArr.RemoveAt(ItemNumber)
                    Data.MacroArr.RemoveAt(ItemNumber)
                }
                else if (macroStr == "空条件" || macroStr == "") {
                    Data.MacroArr[ItemNumber] := ""
                }
                else {
                    Data.MacroArr[ItemNumber] := Trim(macroStr)
                }
            }
        }
        else {
            if (ItemNumber == 1)    ;真
                Data.TrueMacro := macroStr
            else
                Data.FalseMacro := macroStr
        }

        SaveMacroCMDData(Data)
    }

    GetItemNumber(nodeItemID) {
        ItemNumber := 1
        PreItemID := this.MacroTreeViewCon.GetPrev(nodeItemID)
        while (PreItemID != 0) {
            ItemNumber += 1
            PreItemID := this.MacroTreeViewCon.GetPrev(PreItemID)
        }
        return ItemNumber
    }

    _OnLButtonDown(wParam, lParam, msg, hwnd) {
        if (!this.Gui)
            return
        ; 控件可能在保存/重载期间被销毁，访问 .Hwnd 会抛 "The control is destroyed."
        try
            guiHwnd := this.Gui.Hwnd
        catch
            return
        if (!WinActive("ahk_id " guiHwnd))
            return

        try
            hwndTV := this.MacroTreeViewCon.Hwnd
        catch
            return
        isFromLeft := this.DragSourceMap.Has(hwnd)
        isFromTV := (hwnd == hwndTV)

        if (!isFromLeft && !isFromTV)
            return

        dragInfo := ""
        sourceItem := 0
        CoordMode("Mouse", "Screen")
        MouseGetPos(&startX, &startY)

        if (isFromLeft) {
            dragInfo := this.DragSourceMap[hwnd]
        } else {
            hitFlags := 0
            sourceItem := this.TreeViewHitTest(this.MacroTreeViewCon, startX, startY, &hitFlags)
            if (sourceItem == 0)
                return
            ; 点到展开/折叠按钮：不拦截，交给 TreeView 正常处理
            if (hitFlags & 0x0010)  ; TVHT_ONITEMBUTTON
                return

            itemText := this.MacroTreeViewCon.GetText(sourceItem)
            cleanText := StrReplace(itemText, "→", "")

            ; ⎖ 開頭的是資訊/控制節點，不參與多選。
            ; 真／假／循環體／條件是可選取的容器節點。
            if (SubStr(cleanText, 1, 1) == "⎖")
                return 1

            ; Ctrl+Click / Shift+Click：進入多選模式，不啟動拖曳。
            ; 使用 Check 狀態作為可視化的多選標記。
            if (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P")) {
                if (GetKeyState("Shift", "P"))
                    this.SelectMultiRange(this.MultiSelectAnchor, sourceItem)
                else
                    this.ToggleMultiSelection(sourceItem)

                this.CurItemID := sourceItem
                this.MacroTreeViewCon.Modify(sourceItem, "Select")
                return 1
            }

            ; 一般單擊：清掉舊多選，只保留目前項目。
            this.SetSingleMultiSelection(sourceItem)
            this.CurItemID := sourceItem
            this.MacroTreeViewCon.Modify(sourceItem, "Select")

            ; 容器可以被選取，但不當成可拖曳的一般指令。
            if (this.IsContainerNode(itemText))
                return 1

            dragInfo := {name: itemText, gui: "", isMove: true, sourceItem: sourceItem}
        }

        dragStarted := false
        lastTargetItem := -1
        lastMode := 0
        plannedMode := 1
        plannedTarget := 0

        actionVerb := dragInfo.isMove ? GetLang("移动") : GetLang("拖动插入")

        while GetKeyState("LButton", "P") {
            MouseGetPos(&curX, &curY, &curWin, &curCtrlHwnd, 2)
            if (!dragStarted) {
                if (Abs(curX - startX) > 8 || Abs(curY - startY) > 8) {
                    dragStarted := true
                    ; 捕捉滑鼠到 TreeView，防止 WM_LBUTTONUP 流向編輯器造成焦點偷換
                    DllCall("SetCapture", "Ptr", hwndTV)
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", 0)
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", 0)
                }
            }
            if (dragStarted) {
                if (curCtrlHwnd == hwndTV) {
                    targetItem := this.TreeViewHitTest(this.MacroTreeViewCon, curX, curY)

                    mode := 1
                    after := 0

                    if (targetItem == 0) {
                        mode := 1
                    } else {
                        itemText := this.MacroTreeViewCon.GetText(targetItem)
                        cleanText := StrReplace(itemText, "→", "")

                        if (SubStr(cleanText, 1, 1) == "⎖" || (dragInfo.isMove && targetItem == dragInfo.sourceItem)) {
                            mode := -1
                        } else if (dragInfo.isMove && this.IsDescendantOrSelf(this.MacroTreeViewCon, dragInfo.sourceItem, targetItem)) {
                            mode := -1
                        } else if (this.IsContainerNode(itemText)) {
                            mode := 5
                        } else {
                            rect := this.GetItemRect(this.MacroTreeViewCon, targetItem)
                            if (rect) {
                                pt := Buffer(8)
                                NumPut("Int", curX, pt, 0)
                                NumPut("Int", curY, pt, 4)
                                DllCall("ScreenToClient", "Ptr", hwndTV, "Ptr", pt)
                                clientY := NumGet(pt, 4, "Int")

                                midY := rect.top + (rect.bottom - rect.top) / 2
                                if (clientY < midY) {
                                    mode := 3
                                    after := 0
                                } else {
                                    mode := 4
                                    after := 1
                                }
                            } else {
                                mode := 4
                                after := 1
                            }
                        }
                    }

                    if (targetItem != lastTargetItem || mode != lastMode) {
                        lastTargetItem := targetItem
                        lastMode := mode

                        DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", 0)
                        DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", 0)

                        plannedMode := mode
                        plannedTarget := targetItem

                        if (mode == -1) {
                            ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("提示: 无法移动到此位置"))
                        } else if (mode == 1) {
                            ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("目标: 追加到末尾"))
                        } else if (mode == 5) {
                            DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", targetItem)
                            itemText := this.MacroTreeViewCon.GetText(targetItem)
                            ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("目标: 插入到 ") itemText GetLang(" 内部"))
                        } else if (mode == 3) {
                            DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", targetItem)
                            itemText := this.MacroTreeViewCon.GetText(targetItem)
                            ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("目标: 插入到 ") itemText GetLang(" 上方"))
                        } else if (mode == 4) {
                            DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 1, "Ptr", targetItem)
                            itemText := this.MacroTreeViewCon.GetText(targetItem)
                            ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("目标: 插入到 ") itemText GetLang(" 下方"))
                        }
                    }
                } else if (curCtrlHwnd == this.MacroEditTextCon.Hwnd) {
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", 0)
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", 0)
                    lastTargetItem := -1
                    lastMode := 0

                    ToolTip(actionVerb ": " dragInfo.name "`n" GetLang("目标: 文本末尾"))
                    plannedMode := 1
                    plannedTarget := 0
                } else {
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", 0)
                    DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", 0)
                    lastTargetItem := -1
                    lastMode := 0

                    ToolTip(actionVerb ": " dragInfo.name)
                    plannedMode := -1
                }
            }
            Sleep(30)
        }

        ToolTip() ; Clear tooltip
        DllCall("ReleaseCapture")  ; 釋放滑鼠捕捉
        DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x111A, "Ptr", 0, "Ptr", 0)
        DllCall("SendMessage", "Ptr", hwndTV, "UInt", 0x110B, "Ptr", 8, "Ptr", 0)

        if (isFromLeft) {
            if (!dragStarted) {
                ; 沒有拖曳：模擬正常按鈕點擊，追加到末尾
                this.OnOpenSubGui(dragInfo.gui, 1)
            } else if (plannedMode != -1) {
                ; 拖曳並在 TreeView 或 Edit 中釋放
                MouseGetPos(&releaseX, &releaseY, &releaseWin, &releaseCtrlHwnd, 2)
                if (releaseCtrlHwnd == hwndTV || releaseCtrlHwnd == this.MacroEditTextCon.Hwnd) {
                    this.CurItemID := plannedTarget
                    if (this.CurItemID != 0) {
                        this.MacroTreeViewCon.Modify(this.CurItemID, "Select")
                    }
                    this.OnOpenSubGui(dragInfo.gui, plannedMode)
                }
                ; TreeView 外釋放：什麼都不做
            }
            ; 攔截原始 WM_LBUTTONDOWN，防止按鈕的 Click 事件重複觸發
            return 1
        } else {
            ; isFromTV：TreeView 內部指令移動；未拖动时已在按下时完成选中
            if (dragStarted && plannedMode != -1) {
                MouseGetPos(&releaseX, &releaseY, &releaseWin, &releaseCtrlHwnd, 2)
                if (releaseCtrlHwnd == hwndTV) {
                    destParent := 0
                    if (plannedMode == 5) {
                        destParent := plannedTarget
                    } else if (plannedMode == 3 || plannedMode == 4) {
                        destParent := this.MacroTreeViewCon.GetParent(plannedTarget)
                    }
                    this.MoveTreeViewItem(dragInfo.sourceItem, destParent, plannedTarget, plannedMode)
                }
            }
            ; 消费消息，避免过期的 WM_LBUTTONDOWN 再交给 TreeView 破坏选中
            return 1
        }
    }

    ; TreeView 多選視覺高亮：被選中的指令整行都會突出顯示。
    _OnNotify(wParam, lParam, msg, hwnd) {
        if (!this.Gui || !this.MacroTreeViewCon || !lParam)
            return

        ; 控件可能在保存/重载期间被销毁，访问 .Hwnd 会抛 "The control is destroyed."
        try
            treeHwnd := this.MacroTreeViewCon.Hwnd
        catch
            return
        if (!treeHwnd)
            return

        ; WM_NOTIFY / NMCUSTOMDRAW / NMTVCUSTOMDRAW
        ; 32 位與 64 位結構的對齊方式不同，這裡使用固定的正確欄位偏移。
        if (A_PtrSize == 8) {
            hdrHwndOffset := 0
            codeOffset := 16
            drawStageOffset := 24
            itemSpecOffset := 56
            clrTextOffset := 80
            clrTextBkOffset := 84
        } else {
            hdrHwndOffset := 0
            codeOffset := 8
            drawStageOffset := 12
            itemSpecOffset := 36
            clrTextOffset := 48
            clrTextBkOffset := 52
        }

        hwndFrom := NumGet(lParam, hdrHwndOffset, "Ptr")
        if (hwndFrom != treeHwnd)
            return

        code := NumGet(lParam, codeOffset, "Int")
        if (code != -12) ; NM_CUSTOMDRAW
            return

        drawStage := NumGet(lParam, drawStageOffset, "UInt")

        ; CDDS_PREPAINT：要求下一階段的 ITEMPREPAINT 通知。
        if (drawStage == 0x00000001)
            return 0x00000020 ; CDRF_NOTIFYITEMDRAW

        ; CDDS_ITEMPREPAINT：針對每個 TreeView item 設定顏色。
        if (drawStage != 0x00010001)
            return

        itemID := NumGet(lParam, itemSpecOffset, "Ptr")
        if (!itemID || !this.MultiSelectItems.Has(itemID))
            return

        ; 多選項目：整行高亮，而不是只靠 CheckBox。
        ; 使用橙色背景 + 白色文字，滑鼠移開後仍保持。
        NumPut("UInt", 0xFFFFFF, lParam, clrTextOffset)
        NumPut("UInt", 0x2D6CDF, lParam, clrTextBkOffset)

        return 0x00000002 ; CDRF_NEWFONT
    }

    TreeViewHitTest(TVCon, mouseX, mouseY, &flags := 0) {
        hwnd := TVCon.Hwnd
        pt := Buffer(8)
        NumPut("Int", mouseX, pt, 0)
        NumPut("Int", mouseY, pt, 4)
        DllCall("ScreenToClient", "Ptr", hwnd, "Ptr", pt)
        clientX := NumGet(pt, 0, "Int")
        clientY := NumGet(pt, 4, "Int")

        structSize := A_PtrSize == 8 ? 24 : 16
        tvhti := Buffer(structSize, 0)
        NumPut("Int", clientX, tvhti, 0)
        NumPut("Int", clientY, tvhti, 4)

        hItem := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x1111, "Ptr", 0, "Ptr", tvhti, "Ptr")
        flags := NumGet(tvhti, 8, "UInt")
        return hItem
    }

    IsContainerNode(itemText) {
        cleanItemText := StrReplace(itemText, "→", "")
        isCondi := SubStr(cleanItemText, 1, StrLen(GetLang("条件"))) == GetLang("条件")
        return (
            cleanItemText == GetLang("真")
            || cleanItemText == GetLang("假")
            || cleanItemText == GetLang("循环体")
            || isCondi
        )
    }

    GetItemRect(TVCon, hItem) {
        hwnd := TVCon.Hwnd
        rect := Buffer(16, 0)
        NumPut("UPtr", hItem, rect, 0)
        if DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x1104, "Ptr", 0, "Ptr", rect, "Ptr") {
            return {
                left: NumGet(rect, 0, "Int"),
                top: NumGet(rect, 4, "Int"),
                right: NumGet(rect, 8, "Int"),
                bottom: NumGet(rect, 12, "Int")
            }
        }
        return ""
    }

    MoveTreeViewItem(sourceItem, destParent, relativeToItem, mode) {
        this.ResetDebugState()
        this.ClearMultiSelection()

        sourceText := this.MacroTreeViewCon.GetText(sourceItem)
        sourceIcon := this.GetCmdIconStr(sourceText)
        sourceParent := this.MacroTreeViewCon.GetParent(sourceItem)

        if (mode == 3) {
            prev := this.MacroTreeViewCon.GetPrev(relativeToItem)
            seq := prev == 0 ? "First" : prev
        } else if (mode == 4) {
            seq := relativeToItem
        } else if (mode == 5) {
            seq := "First"
        } else {
            seq := ""
        }

        newItem := this.MacroTreeViewCon.Add(sourceText, destParent, seq " " sourceIcon)
        this.TreeAddBranch(newItem, sourceText)

        this.MacroTreeViewCon.Delete(sourceItem)

        if (sourceParent != 0) {
            macroStrSource := this.GetTreeMacroStr(sourceParent)
            RealSourceItemID := this.MacroTreeViewCon.GetParent(sourceParent)
            RealSourceCommandStr := this.MacroTreeViewCon.GetText(RealSourceItemID)
            this.SaveCommandData(RealSourceCommandStr, macroStrSource, sourceParent)
        }

        if (destParent != 0) {
            macroStrDest := this.GetTreeMacroStr(destParent)
            RealDestItemID := this.MacroTreeViewCon.GetParent(destParent)
            RealDestCommandStr := this.MacroTreeViewCon.GetText(RealDestItemID)
            this.SaveCommandData(RealDestCommandStr, macroStrDest, destParent)
        }

        if (sourceParent != 0) {
            this.RefreshTree(RealSourceItemID)
        }
        if (destParent != 0 && destParent != sourceParent) {
            this.RefreshTree(RealDestItemID)
        }

        if (destParent != 0) {
            child := this.MacroTreeViewCon.GetChild(destParent)
            while (child) {
                if (this.MacroTreeViewCon.GetText(child) == sourceText) {
                    this.MacroTreeViewCon.Modify(child, "Select")
                    break
                }
                child := this.MacroTreeViewCon.GetNext(child)
            }
        } else {
            this.MacroTreeViewCon.Modify(newItem, "Select")
        }

        return newItem
    }

    IsDescendantOrSelf(TVCon, item, potentialParent) {
        if (potentialParent == 0)
            return false
        if (potentialParent == item)
            return true
        parent := TVCon.GetParent(potentialParent)
        while (parent != 0) {
            if (parent == item)
                return true
            parent := TVCon.GetParent(parent)
        }
        return false
    }
}

CreateSubGuiClickHandler(self, guiInstance) {
    clickHandler(*) {
        if (self._dragCancelled) {
            self._dragCancelled := false
            return
        }
        self.OnOpenSubGui(guiInstance)
    }
    return clickHandler
}