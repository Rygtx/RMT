#Requires AutoHotkey v2.0

class RMTCMDGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.CmdCategories := Map(
            GetLang("图像"), [
                GetLang("截图"),
                GetLang("截图提取文本"),
                GetLang("自由贴")
            ],
            GetLang("调试"), [
                GetLang("开启变量监视"),
                GetLang("关闭变量监视"),
                GetLang("开启指令显示"),
                GetLang("关闭指令显示"),
            ],
            GetLang("输入控制"), [
                GetLang("启用键鼠"),
                GetLang("禁用键鼠")
            ],
            GetLang("菜单宏"), [
                GetLang("显示菜单"),
                GetLang("关闭菜单")
            ],
            GetLang("宏控制"), [
                GetLang("暂停所有宏"),
                GetLang("恢复所有宏"),
                GetLang("终止所有宏")
            ],
            GetLang("软件自身"), [
                GetLang("关闭软件"),
                GetLang("休眠"),
                GetLang("重载")
            ],
            GetLang("窗口"), [
                ;GetLang("是否鼠标穿透"),
                GetLang("置顶或取消"),
                GetLang("不透明度")
            ]
        )

        this.CmdStrArr := this.BuildCmdDDLArray(this.CmdCategories)
        this.OperTypeCon := ""
        this.LastValidValue := 0

        this.MenuRelateArrCon := []
        this.MenuDLCon := ""
        this.TransparencyRelateArrCon := []
        this.TransparencyDLCon := ""
    }

    ; 构建 操作类型 DropDownList 数组
    BuildCmdDDLArray(categories) {
        arr := []
        for title, items in categories {
            arr.Push("[ " title " ]")
            for _, cmd in items
                arr.Push(cmd)
            arr.Push("────────────")
        }
        arr.Pop()
        return arr
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
        this.OnChangeType()
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        cmdStr := cmdArr.Length >= 2 ? cmdArr[2] : GetLang("截图")
        menuDLIndex := cmdStr == GetLang("显示菜单") && cmdArr.Length >= 3 ? cmdArr[3] : 1

        ; 设置 OperTypeCon 当前值
        for i, text in this.CmdStrArr {
            if (text == cmdStr) {
                this.OperTypeCon.Value := i
                this.LastValidValue := i
                break
            }
        }

        FoldInfo := MySoftData.TableInfo[3].FoldInfo
        this.MenuDLCon.Delete()
        DropDownArr := []
        loop FoldInfo.RemarkArr.Length {
            DropDownArr.Push(A_Index ". " FoldInfo.RemarkArr[A_Index])
        }
        this.MenuDLCon.Add(DropDownArr)
        this.MenuDLCon.Value := menuDLIndex
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("RMT指令编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 15
        PosY := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("操作类型："))
        PosX += 80
        this.OperTypeCon := MyGui.Add(
            "DropDownList",
            Format("x{} y{} w160 R16", PosX, PosY - 3),
            this.CmdStrArr
        )
        this.OperTypeCon.OnEvent("Change", this.OnChangeType.Bind(this))

        PosX := 15
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 90), GetLang("菜单序号："))
        this.MenuRelateArrCon.Push(con)

        PosX += 80
        this.MenuDLCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R5", PosX, PosY - 5, 160), [])
        this.MenuRelateArrCon.Push(this.MenuDLCon)

        PosX := 15
        PosY += 40
        con := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 90), GetLang("不透明度："))
        this.TransparencyRelateArrCon.Push(con)

        PosX += 80
        this.TransparencyDLCon := MyGui.Add(
            "DropDownList",
            Format("x{} y{} w{} R6", PosX, PosY - 5, 160),
            ["100%", "90%", "80%", "70%", "60%","50%", "40%"]
        )
        this.TransparencyDLCon.Value := 1
        this.TransparencyRelateArrCon.Push(this.TransparencyDLCon)

        PosX := 100
        PosY += 40
        con := MyGui.Add("Button", Format("x{} y{} w100 h40", PosX, PosY), GetLang("确定"))
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.Show("w300 h200")
    }

    ; 操作类型 DropDownList Change 处理
    OnChangeType(*) {
        text := this.OperTypeCon.Text

        ; 分类标题 or 分割线，禁止选择
        if (text ~= "^\[.*\]$" || text ~= "^─+$") {
            if (this.LastValidValue)
                this.OperTypeCon.Value := this.LastValidValue
            return
        }

        this.LastValidValue := this.OperTypeCon.Value

        IsShowMenuDL := text == GetLang("显示菜单")
        for _, con in this.MenuRelateArrCon
            con.Visible := IsShowMenuDL

        IsShowTransparencyDL := text == GetLang("不透明度")
        for _, con in this.TransparencyRelateArrCon
            con.Visible := IsShowTransparencyDL
    }

    OnSureBtnClick() {
        if (!this.CheckIfValid())
            return

        CommandStr := this.GetCommandStr()
        this.SureBtnAction.Call(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        if (this.OperTypeCon.Text == GetLang("禁用键鼠")) {
            tipStr := (
                Format("{}`n{}`n{}`n{}`n{}", GetLang("此操作将 立即禁用键盘和鼠标输入，您将无法通过键鼠操作计算机！"), GetLang("重要须知："), GetLang(
                    "- 以管理员身份运行本软件，否则该指令无效。"), GetLang("- 务必后续执行 *启用键鼠*，否则输入设备将保持禁用状态！"), GetLang("是否确认禁用？"))
            )
            if (MsgBox(tipStr, GetLang("禁用键鼠（需管理员权限）"), "4") == "No")
                return false
        }

        if (this.OperTypeCon.Text == GetLang("启用键鼠")) {
            MsgBox(
                GetLang("- 必须 以管理员身份运行本软件，否则该指令无效。"),
                GetLang("启用键鼠（需管理员权限）")
            )
        }
        return true
    }

    GetCommandStr() {
        CommandStr := Format("{}_{}", GetLang("RMT指令"), this.OperTypeCon.Text)
        if (this.OperTypeCon.Text == GetLang("显示菜单")) {
            CommandStr .= "_" this.MenuDLCon.Value
        }
        else if (this.OperTypeCon.Text == GetLang("不透明度")) {
            CommandStr .= "_" StrReplace(this.TransparencyDLCon.Text, "%")
        }
        return CommandStr
    }
}
