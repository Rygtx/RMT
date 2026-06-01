#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui —— 蓝图式（节点化）宏指令编辑器
;
; 交互：
;   - 表格行"编辑"按钮右键进入（左键仍为旧的顺序编辑器）。
;   - 右上角"保存"按钮：保存并关闭界面。
;   - 画布空白处右键：弹出若梦兔全部指令菜单，点击生成对应节点。
;       · 间隔 / 按键：生成可内联编辑的完整节点。
;       · 其它指令：先生成临时节点（占位，后续完善）。
;   - 节点参数可直接在节点面板上内联编辑：
;       · 间隔节点：直接编辑时间(ms)
;       · 按键节点：下拉选择按键类型；类型为"点击"时显示点击时长/点击次数；
;                   点击次数>1 时再显示每次间隔。
;   - 双击间隔/按键节点：打开对应完整编辑器（IntervalGui / KeyGui）。
;   - 关闭窗口或任何内联修改时，按连线顺序重建宏并实时回写。
;
; 架构：维护数据模型 cmdNodes(数据) + order(存在列表) + pos(各节点位置) + links(连线)。
;       新增节点时重建窗口(_Render)，但保留各节点位置与连线、窗口始终最大化，
;       从而避免窗口大小被重置；新节点放在右键位置且不自动连线。
; ============================================================================

class MacroGraphGui {
    __New() {
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this.ui := ""
        this.graph := ""
        this.cmdNodes := Map()        ; nodeId -> 解析后的指令对象 { type, raw, ... }
        this.order := []              ; 指令节点 id 列表（存在性，不决定连线）
        this.pos := Map()             ; nodeId(含Start/End) -> { x, y } 逻辑坐标(不含画布偏移)
        this.links := []              ; 连线 [{ from, to }]，跨重建保留
        this.seq := 0
        this.startId := "Start"
        this.endId := "End"
        this._readyTimer := this._EnableWhenReady.Bind(this)
        this._lastClickId := ""
        this._lastClickTime := 0
        this._oldUi := ""             ; 双缓冲：重建时暂存旧窗口，待新窗口就绪后再关闭
        this.injected := Map()        ; 运行时注入(简要)的节点 id；这类节点编辑后需重建为完整内联节点

        ; 若梦兔全部指令
        this.CmdList := GetLangArr(["间隔", "按键", "搜索", "搜索Pro", "移动", "移动Pro", "输入", "输出", "循环", "宏操作",
            "变量", "变量提取", "如果", "如果Pro", "运算", "运行", "文件读写", "文本处理", "数组", "RMT指令", "后台鼠标",
            "后台按键", "窗口管理", "按键检测"])

        ; 复用现有子编辑器（双击节点时打开）
        this.IntervalGui := IntervalGui()
        this.KeyGui := KeyGui()
    }

    ; ----------------------------------------------------------------- 入口

    ShowGui(macroStr) {
        this._CloseUI()
        this.cmdNodes := Map()
        this.order := []
        this.pos := Map()
        this.links := []
        this.seq := 0

        baseY := 220, step := 240, x := 60
        this.pos[this.startId] := { x: x, y: baseY }
        prevId := this.startId
        x += step
        for cmd in SplitMacro(macroStr) {
            id := this._NewId()
            this.cmdNodes[id] := this._ParseCmd(cmd)
            this.order.Push(id)
            this.pos[id] := { x: x, y: baseY }
            this.links.Push({ from: prevId, to: id })
            prevId := id
            x += step
        }
        this.pos[this.endId] := { x: x, y: baseY }
        this.links.Push({ from: prevId, to: this.endId })
        this._Render()
    }

    ; 根据数据模型构建并显示窗口（始终最大化；节点用保存的坐标，连线用 links）
    _Render() {
        ; 双缓冲：先创建并显示新窗口，待其就绪后再关闭旧窗口，避免新增节点时窗口闪缩
        oldUi := this.ui
        this.graph := ""
        this.injected := Map()        ; 重建后所有节点均为完整内联节点

        win := XAML_Generator("Window")
        win.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation")
        win.SetProp("xmlns:x", "http://schemas.microsoft.com/winfx/2006/xaml")
        win.Title(GetLang("节点编辑器")).Width(1100).Height(700).WindowStartupLocation("CenterScreen").WindowState("Maximized").Background("#1E1E1E")
        iconPath := StrReplace(A_WorkingDir "\Images\Soft\rabit.ico", "\", "/")
        if (FileExist(iconPath))
            win.Icon(iconPath)

        root := win.Add("Grid")
        this.graph := root.NodeGraph("RMTGraph")

        ; 右上角保存按钮（覆盖在画布之上）
        root.Add("Button").Name("MG_BtnSave").Content(GetLang("保存")).HorizontalAlignment("Right").VerticalAlignment("Top").Margin("0,12,16,0").Width("90").Height("32").Background("#2E6E3E").Foreground("White").BorderThickness("0").FontSize("13").Cursor("Hand")

        ; 节点（使用各自保存的坐标）
        this._BuildBaseNode(this.startId, GetLang("开始"), "Input")
        for id in this.order
            this._BuildCmdNode(id, this.cmdNodes[id])
        this._BuildBaseNode(this.endId, GetLang("结束"), "Output")

        ; 连线（来自 links，跨重建保留）
        for link in this.links {
            if (this._NodeExists(link.from) && this._NodeExists(link.to))
                this.graph.AddConnection(link.from, link.to)
        }

        ; 右键菜单必须放在所有画布内容子元素之后构建，
        ; 否则 ContextMenu 属性元素会夹在 Children 内容之间，导致 WPF 报 Children 重复设置
        this._BuildContextMenu()

        ; ---- 宿主 ----
        ownerHwnd := this.OwnerHwnd != "" ? this.OwnerHwnd : 0
        this.ui := XAMLHost(win.ToString(), "", ownerHwnd)
        this.graph.Bind(this.ui)
        this._RegisterNodeEvents()
        ; 为所有连线补绑点击事件（XNodeGraph 仅给运行时新增连线绑定，构建期连线需手动补）
        for conn in this.graph.connections
            this.ui.OnEvent(conn.PathId, "MouseLeftButtonDown", ObjBindMethod(this.graph, "OnPathClicked", conn.PathId))
        ; Start/End 也跟踪拖动位置
        this.ui.OnEvent("Node_" this.startId, "DragMove", this._OnNodeDrag.Bind(this, this.startId))
        this.ui.OnEvent("Node_" this.endId, "DragMove", this._OnNodeDrag.Bind(this, this.endId))
        for i, name in this.CmdList
            this.ui.OnEvent("MG_Add_" i, "Click", this.OnAddCmd.Bind(this, name))
        this.ui.OnEvent("MG_BtnSave", "Click", (*) => this._OnSave())
        this.ui.OnEvent("Window", "KeyDown", this._OnKeyDown.Bind(this))
        this.ui.OnEvent("Window", "Closed", (*) => this.OnWindowClosed())

        this.ui.Show()
        this._oldUi := oldUi
        SetTimer(this._readyTimer, 50)
    }

    _NodeExists(id) {
        return id == this.startId || id == this.endId || this.cmdNodes.Has(id)
    }

    _EnableWhenReady() {
        if (this.ui == "" || !this.ui.wpfHwnd)
            return
        SetTimer(this._readyTimer, 0)
        this.graph.EnableDrag(this.ui, true)
        ; 将窗口激活置前（避免显示在主界面下方）
        try {
            WinShow("ahk_id " this.ui.wpfHwnd)
            WinActivate("ahk_id " this.ui.wpfHwnd)
        }
        ; 新窗口就绪后再关闭旧窗口（双缓冲，消除闪缩）
        if (this._oldUi != "") {
            try this._oldUi.Update("Window", "Close", "")
            try this._oldUi.Dispose()
            this._oldUi := ""
        }
    }

    ; 保存并关闭
    _OnSave() {
        this._Apply()
        if (this.ui != "")
            this.ui.Update("Window", "Close", "")
    }

    OnWindowClosed(*) {
        SetTimer(this._readyTimer, 0)
        this._Apply()
        this.ui := ""
        this.graph := ""
    }

    _CloseUI() {
        SetTimer(this._readyTimer, 0)
        if (this._oldUi != "") {
            try this._oldUi.Dispose()
            this._oldUi := ""
        }
        if (this.ui != "") {
            try this.ui.Update("Window", "Close", "")
            try this.ui.Dispose()
            this.ui := ""
        }
        this.graph := ""
    }

    ; ----------------------------------------------------------------- 节点事件注册

    _RegisterNodeEvents() {
        for id, obj in this.cmdNodes {
            ; 双击节点打开完整编辑器（节点是 Border，无原生双击，用 SelectNode 计时判定）
            this.ui.OnEvent("Node_" id, "SelectNode", this._OnNodeClick.Bind(this, id))
            this.ui.OnEvent("Node_" id, "CtrlSelectNode", this._OnNodeClick.Bind(this, id))
            this.ui.OnEvent("Node_" id, "DragMove", this._OnNodeDrag.Bind(this, id))

            if (obj.type == GetLang("间隔")) {
                this.ui.Track("Time_" id)
                this.ui.OnEvent("Time_" id, "LostFocus", this._OnField.Bind(this, id, "time"))
            }
            else if (obj.type == GetLang("按键")) {
                this.ui.Track("TypeCmb_" id)
                this.ui.Track("Hold_" id)
                this.ui.Track("Count_" id)
                this.ui.Track("Inter_" id)
                this.ui.OnEvent("TypeCmb_" id, "SelectionChanged", this._OnKeyType.Bind(this, id))
                this.ui.OnEvent("Hold_" id, "LostFocus", this._OnField.Bind(this, id, "hold"))
                this.ui.OnEvent("Count_" id, "LostFocus", this._OnField.Bind(this, id, "count"))
                this.ui.OnEvent("Inter_" id, "LostFocus", this._OnField.Bind(this, id, "inter"))
            }
        }
    }

    ; 拖动节点时记录其逻辑坐标（DragCoords 为画布坐标，需减去画布偏移）
    _OnNodeDrag(id, state, *) {
        if (!state.Has("DragCoords") || !this.pos.Has(id) || this.graph == "")
            return
        parts := StrSplit(state["DragCoords"], ",")
        if (parts.Length >= 2) {
            this.pos[id].x := Number(parts[1]) - this.graph.offsetX
            this.pos[id].y := Number(parts[2]) - this.graph.offsetY
        }
    }

    ; 窗口按键：选中节点/连线后按 Delete 删除（事件名形如 KeyDown:Delete，第三参为 {Key}）
    _OnKeyDown(state, ctrl, info) {
        key := (IsObject(info) && info.HasProp("Key")) ? info.Key : ""
        if (key == "Delete" || key == "Back")
            this._DeleteSelected()
    }

    ; 删除当前选中的节点与连线（就地隐藏，不重建窗口）
    _DeleteSelected() {
        if (this.graph == "")
            return
        this.graph.DeleteSelectedConnections()
        this._DeleteSelectedNodes()
        this._CaptureLinks()
        this._Apply()
    }

    _DeleteSelectedNodes() {
        g := this.graph
        ids := []
        for id in g.selectedNodes
            ids.Push(id)
        for id in ids {
            if (id == this.startId || id == this.endId || !this.cmdNodes.Has(id))
                continue
            g.ui.Update("Node_" id, "Visibility", "Collapsed")
            g.ui.Update("Port_In_" id, "Visibility", "Collapsed")
            g.ui.Update("Port_Out_" id, "Visibility", "Collapsed")
            ; 删除并隐藏相关连线
            keep := []
            for conn in g.connections {
                if (conn.From == id || conn.To == id)
                    g.ui.Update(conn.PathId, "Visibility", "Collapsed")
                else
                    keep.Push(conn)
            }
            g.connections := keep
            ; 从节点表移除
            nkeep := []
            for n in g.nodes {
                if (n.Id != id)
                    nkeep.Push(n)
            }
            g.nodes := nkeep
            this.cmdNodes.Delete(id)
            this._RemoveFromOrder(id)
            if (this.pos.Has(id))
                this.pos.Delete(id)
            if (this.injected.Has(id))
                this.injected.Delete(id)
            if (g.selectedNodes.Has(id))
                g.selectedNodes.Delete(id)
        }
    }

    _RemoveFromOrder(id) {
        no := []
        for x in this.order {
            if (x != id)
                no.Push(x)
        }
        this.order := no
    }

    ; ----------------------------------------------------------------- 右键添加节点

    _BuildContextMenu() {
        ; MaxHeight 触发主题 ContextMenu 模板内置的 ScrollViewer 滚动；MinWidth 加宽弹窗
        cm := this.graph.canvas.Add("FrameworkElement.ContextMenu").Add("ContextMenu").MinWidth("220").MaxHeight("420").Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness(1).Foreground("{DynamicResource TextMain}")
        for i, name in this.CmdList
            cm.Add("MenuItem").Name("MG_Add_" i).Header(name)
    }

    OnAddCmd(cmdName, *) {
        if (this.ui == "" || !this.ui.wpfHwnd || this.graph == "")
            return
        ; 运行时注入新节点（不重建窗口，避免闪烁）；放在右键位置，不自动连线
        this._CaptureLinks()
        id := this._NewId()
        this.cmdNodes[id] := this._DefaultObj(cmdName)
        this.order.Push(id)
        ox := this.graph.HasProp("lastRightClickX") ? this.graph.lastRightClickX - this.graph.offsetX : 200
        oy := this.graph.HasProp("lastRightClickY") ? this.graph.lastRightClickY - this.graph.offsetY : 200
        this.pos[id] := { x: ox, y: oy }
        this.injected[id] := true
        this._InjectSummaryNode(id, this.cmdNodes[id])
    }

    ; 运行时注入一个简要节点（标题 + 摘要 + 提示），双击可进完整编辑器
    _InjectSummaryNode(id, obj) {
        g := this.graph
        p := this.pos[id]
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"'
        title := this._XmlEsc(obj.type)
        detail := this._XmlEsc(this._Summary(obj))
        tip := this._XmlEsc(GetLang("双击编辑"))

        nodeXaml := '<Border ' ns ' x:Name="Node_' id '" Background="{DynamicResource DropdownBg}" BorderBrush="{DynamicResource ControlBorder}" BorderThickness="1" CornerRadius="6" Width="160" Canvas.Left="' x '" Canvas.Top="' y '"><Border.Effect><DropShadowEffect BlurRadius="8" ShadowDepth="2" Opacity="0.4" Direction="270" Color="Black"/></Border.Effect><Grid><Grid.RowDefinitions><RowDefinition Height="30"/><RowDefinition Height="*"/></Grid.RowDefinitions><Border Grid.Row="0" Background="#3E3E50" CornerRadius="5,5,0,0" Cursor="SizeAll"><TextBlock Text="' title '" Foreground="White" FontWeight="Bold" FontSize="11" VerticalAlignment="Center" Margin="10,0"/></Border><StackPanel Grid.Row="1" Margin="10,6,10,8"><TextBlock Text="' detail '" Foreground="#DDDDDD" FontSize="11" TextWrapping="Wrap"/><TextBlock Text="' tip '" Foreground="#888888" FontSize="9" Margin="0,4,0,0"/></StackPanel></Grid></Border>'
        g.ui.Update(g.id, "AddXamlItem", nodeXaml)

        portIn := '<Ellipse ' ns ' x:Name="Port_In_' id '" Width="10" Height="10" Fill="#4CAF50" Stroke="#333" StrokeThickness="1" Canvas.Left="' (x - 5) '" Canvas.Top="' (y + 30) '" IsHitTestVisible="True" Cursor="Hand"/>'
        g.ui.Update(g.id, "AddXamlItem", portIn)
        portOut := '<Ellipse ' ns ' x:Name="Port_Out_' id '" Width="10" Height="10" Fill="#FF5722" Stroke="#333" StrokeThickness="1" Canvas.Left="' (x + 155) '" Canvas.Top="' (y + 30) '" IsHitTestVisible="True" Cursor="Hand"/>'
        g.ui.Update(g.id, "AddXamlItem", portOut)

        g.nodes.Push({ Id: id, Title: obj.type, X: x, Y: y, W: 160, H: 60, Type: "Process" })

        ; XNodeGraph 的拖动/选中处理（移动端口与连线、高亮）
        g.ui.OnEvent("Node_" id, "DragMove", ObjBindMethod(g, "OnNodeMoved", id))
        g.ui.OnEvent("Node_" id, "SelectNode", ObjBindMethod(g, "OnSelectNode", id))
        g.ui.OnEvent("Node_" id, "CtrlSelectNode", ObjBindMethod(g, "OnCtrlSelectNode", id))
        ; 本类的位置记录与双击编辑
        g.ui.OnEvent("Node_" id, "DragMove", this._OnNodeDrag.Bind(this, id))
        g.ui.OnEvent("Node_" id, "SelectNode", this._OnNodeClick.Bind(this, id))
        g.ui.OnEvent("Node_" id, "CtrlSelectNode", this._OnNodeClick.Bind(this, id))
        SetTimer(() => g.ui.Update("Node_" id, "EnableDrag", "grid=20"), -150)
    }

    _Summary(obj) {
        if (obj.type == GetLang("间隔"))
            return obj.time " ms"
        if (obj.type == GetLang("按键")) {
            s := obj.key " " obj.ktype
            if (obj.ktype == GetLang("点击") && obj.count != "1" && obj.count != 1)
                s .= "  x" obj.count
            return s
        }
        return obj.raw
    }

    _XmlEsc(s) {
        s := StrReplace(s, "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }

    ; 把当前画布连线快照到 this.links（供重建时还原）
    _CaptureLinks() {
        if (this.graph == "")
            return
        newLinks := []
        for conn in this.graph.connections
            newLinks.Push({ from: conn.From, to: conn.To })
        this.links := newLinks
    }

    _DefaultObj(cmdName) {
        if (cmdName == GetLang("间隔"))
            return this._ParseCmd(GetLang("间隔") "_500")
        if (cmdName == GetLang("按键"))
            return this._ParseCmd(GetLang("按键") "_a_" GetLang("点击") "_100")
        ; 其它指令：临时节点占位
        return { type: cmdName, raw: cmdName, temp: true }
    }

    ; ----------------------------------------------------------------- 内联编辑回调

    _OnKeyType(id, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        key := "TypeCmb_" id
        if (state.Has(key) && state[key] != "")
            this.cmdNodes[id].ktype := state[key]
        this._RefreshKeyVisibility(id)
        this._SyncNode(id)
    }

    _OnField(id, field, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        nameMap := Map("time", "Time_", "hold", "Hold_", "count", "Count_", "inter", "Inter_")
        key := nameMap[field] id
        if (state.Has(key))
            this.cmdNodes[id].%field% := state[key]
        if (field == "count")
            this._RefreshKeyVisibility(id)
        this._SyncNode(id)
    }

    ; 重算按键节点 点击时长/次数/间隔 行的显隐
    _RefreshKeyVisibility(id) {
        obj := this.cmdNodes[id]
        if (obj.type != GetLang("按键") || this.ui == "")
            return
        isClick := obj.ktype == GetLang("点击")
        showInter := isClick && IsNumber(obj.count) && (obj.count + 0) > 1
        this.ui.Update("HoldRow_" id, "Visibility", isClick ? "Visible" : "Collapsed")
        this.ui.Update("CountRow_" id, "Visibility", isClick ? "Visible" : "Collapsed")
        this.ui.Update("InterRow_" id, "Visibility", showInter ? "Visible" : "Collapsed")
    }

    ; 重建该节点指令字符串并实时回写
    _SyncNode(id) {
        if (!this.cmdNodes.Has(id))
            return
        this.cmdNodes[id].raw := this._BuildCmd(this.cmdNodes[id])
        this._Apply()
    }

    ; ----------------------------------------------------------------- 双击打开编辑器

    _OnNodeClick(id, *) {
        now := A_TickCount
        if (this._lastClickId == id && now - this._lastClickTime < 400) {
            this._lastClickId := ""
            this._lastClickTime := 0
            this.OpenNodeEditor(id)
        }
        else {
            this._lastClickId := id
            this._lastClickTime := now
        }
    }

    OpenNodeEditor(id) {
        if (!this.cmdNodes.Has(id))
            return
        obj := this.cmdNodes[id]
        editor := ""
        if (obj.type == GetLang("间隔"))
            editor := this.IntervalGui
        else if (obj.type == GetLang("按键"))
            editor := this.KeyGui
        if (editor == "")
            return

        editor.OwnerHwnd := (this.ui != "" && this.ui.wpfHwnd) ? this.ui.wpfHwnd : ""
        editor.SureBtnAction := (cmd) => this.OnEditorSure(id, cmd)
        editor.ShowGui(obj.raw)
    }

    ; 完整编辑器确定后：回写数据并刷新节点显示
    OnEditorSure(id, cmd) {
        if (!this.cmdNodes.Has(id))
            return
        obj := this._ParseCmd(cmd)
        this.cmdNodes[id] := obj
        ; 注入的简要节点无法就地刷新内部文字 → 重建为完整内联节点
        if (this.injected.Has(id)) {
            this._CaptureLinks()
            this._Render()
            return
        }
        if (this.ui != "") {
            this.ui.Update("Title_" id, "Text", obj.type)
            if (obj.type == GetLang("间隔")) {
                this.ui.Update("Time_" id, "Text", obj.time)
            }
            else if (obj.type == GetLang("按键")) {
                this.ui.Update("KeyName_" id, "Text", obj.key)
                this.ui.Update("TypeCmb_" id, "Text", obj.ktype)
                this.ui.Update("Hold_" id, "Text", obj.hold)
                this.ui.Update("Count_" id, "Text", obj.count)
                this.ui.Update("Inter_" id, "Text", obj.inter)
                this._RefreshKeyVisibility(id)
            }
        }
        this._Apply()
    }

    ; ----------------------------------------------------------------- 生成/回写

    _Apply() {
        if (this.SureBtnAction == "")
            return
        macro := this._BuildMacro()
        action := this.SureBtnAction
        action(macro)
    }

    _BuildMacro() {
        g := this.graph
        if (g == "")
            return ""
        nextMap := Map()
        for conn in g.connections
            nextMap[conn.From] := conn.To

        result := []
        cur := this.startId
        visited := Map()
        loop {
            if (!nextMap.Has(cur))
                break
            nxt := nextMap[cur]
            if (visited.Has(nxt))
                break
            visited[nxt] := true
            if (nxt == this.endId)
                break
            if (this.cmdNodes.Has(nxt))
                result.Push(this.cmdNodes[nxt].raw)
            cur := nxt
        }

        macroStr := ""
        for i, c in result
            macroStr .= (i > 1 ? "," : "") c
        return macroStr
    }

    ; ----------------------------------------------------------------- 指令解析/重建

    _ParseCmd(cmd) {
        paramArr := SplitCommand(cmd)
        name := paramArr.Length >= 1 ? paramArr[1] : cmd
        obj := { type: name, raw: cmd }

        if (name == GetLang("间隔")) {
            obj.time := paramArr.Length >= 2 ? paramArr[2] : "500"
        }
        else if (name == GetLang("按键")) {
            obj.key := paramArr.Length >= 2 ? paramArr[2] : ""
            obj.ktype := paramArr.Length >= 3 ? paramArr[3] : GetLang("点击")
            obj.hold := paramArr.Length >= 4 ? paramArr[4] : "100"
            obj.count := paramArr.Length >= 5 ? paramArr[5] : "1"
            obj.inter := paramArr.Length >= 6 ? paramArr[6] : "200"
        }
        return obj
    }

    _BuildCmd(obj) {
        if (obj.type == GetLang("间隔"))
            return GetLang("间隔") "_" obj.time

        if (obj.type == GetLang("按键")) {
            isClick := obj.ktype == GetLang("点击")
            hasHold := isClick
            hasCount := hasHold && (obj.count != "1" && obj.count != 1)
            hasInter := hasCount && (obj.inter != "0" && obj.inter != 0)
            cmd := GetLang("按键") "_" obj.key "_" obj.ktype
            if (hasHold)
                cmd .= "_" obj.hold
            if (hasCount)
                cmd .= "_" obj.count
            if (hasInter)
                cmd .= "_" obj.inter
            return cmd
        }
        return obj.raw
    }

    ; ----------------------------------------------------------------- 节点构建

    ; 开始/结束等无内联控件的节点
    _BuildBaseNode(id, title, nodeType) {
        node := this._NewNodeShell(id, title, nodeType, &body)
        return node
    }

    ; 指令节点（含内联编辑控件）
    _BuildCmdNode(id, obj) {
        this._NewNodeShell(id, obj.type, "Process", &body)

        if (obj.type == GetLang("间隔")) {
            body.Add("TextBlock").Text(GetLang("时间(毫秒)：")).Foreground("#DDDDDD").FontSize("11")
            this._MakeTextBox(body, "Time_" id, obj.time, "136").Margin("0,2,0,0")
        }
        else if (obj.type == GetLang("按键")) {
            body.Add("TextBlock").Name("KeyName_" id).Text(obj.key).Foreground("#FFD27F").FontWeight("Bold").FontSize("12").TextWrapping("Wrap")

            body.Add("TextBlock").Text(GetLang("按键类型")).Foreground("#DDDDDD").FontSize("11").Margin("0,4,0,0")
            cmb := body.Add("ComboBox").Name("TypeCmb_" id).Width("136").Height("22").MinHeight("0").FontSize("11").SelectedIndex(this._TypeIndex(obj.ktype))
            cmb.Add("ComboBoxItem").Content(GetLang("按下"))
            cmb.Add("ComboBoxItem").Content(GetLang("松开"))
            cmb.Add("ComboBoxItem").Content(GetLang("点击"))

            isClick := obj.ktype == GetLang("点击")
            showInter := isClick && IsNumber(obj.count) && (obj.count + 0) > 1

            this._AddFieldRow(body, "HoldRow_" id, GetLang("点击时长:"), "Hold_" id, obj.hold, isClick)
            this._AddFieldRow(body, "CountRow_" id, GetLang("点击次数："), "Count_" id, obj.count, isClick)
            this._AddFieldRow(body, "InterRow_" id, GetLang("每次间隔："), "Inter_" id, obj.inter, showInter)
        }
        else {
            ; 临时节点占位
            body.Add("TextBlock").Text(GetLang("临时节点")).Foreground("#FF9E9E").FontSize("11")
            body.Add("TextBlock").Text(obj.raw).Foreground("#DDDDDD").FontSize("10").TextWrapping("Wrap")
        }
    }

    ; 创建节点外壳（Border + 头部标题 + 端口），body 通过引用返回供填充
    _NewNodeShell(id, title, nodeType, &body) {
        g := this.graph
        p := this.pos.Has(id) ? this.pos[id] : { x: 200, y: 200 }
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        headerColor := nodeType == "Input" ? "#2E5A2E" : (nodeType == "Output" ? "#5A2E2E" : "#3E3E50")

        node := g.canvas.Add("Border").Name("Node_" id).Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("6").Width("160").SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        node.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").Color("Black")

        grid := node.Add("Grid")
        grid.Rows("30", "*")

        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background(headerColor).CornerRadius("5,5,0,0")
        header.Add("TextBlock").Name("Title_" id).Text(title).Foreground("White").FontWeight("Bold").FontSize("11").VerticalAlignment("Center").Margin("10,0")

        body := grid.Add("StackPanel").Grid_Row(1).Margin("10,6,10,8")

        if (nodeType != "Input")
            g.canvas.Add("Ellipse").Width("10").Height("10").Fill("#4CAF50").Stroke("#333").StrokeThickness("1").SetProp("Canvas.Left", String(x - 5)).SetProp("Canvas.Top", String(y + 30)).Name("Port_In_" id).IsHitTestVisible("True").Cursor("Hand")
        if (nodeType != "Output")
            g.canvas.Add("Ellipse").Width("10").Height("10").Fill("#FF5722").Stroke("#333").StrokeThickness("1").SetProp("Canvas.Left", String(x + 155)).SetProp("Canvas.Top", String(y + 30)).Name("Port_Out_" id).IsHitTestVisible("True").Cursor("Hand")

        nodeObj := { Id: id, Title: title, X: x, Y: y, UI: node, W: 160, H: 60, Type: nodeType }
        g.nodes.Push(nodeObj)
        return node
    }

    ; 一行 "标签 + 文本框"，visible 控制初始显隐
    _AddFieldRow(body, rowName, labelText, boxName, boxValue, visible) {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,3,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize("11").Width("62").VerticalAlignment("Center")
        this._MakeTextBox(row, boxName, boxValue, "66")
        return row
    }

    ; 统一的小高度文本框（MinHeight=0 覆盖主题默认的 36，否则高度不生效）
    _MakeTextBox(parent, name, value, width) {
        return parent.Add("TextBox").Name(name).Text(value).Width(width).Height("20").MinHeight("0").FontSize("11").Padding("4,0").VerticalContentAlignment("Center")
    }

    ; ----------------------------------------------------------------- 辅助

    _TypeIndex(ktype) {
        if (ktype == GetLang("按下"))
            return 0
        if (ktype == GetLang("松开"))
            return 1
        return 2   ; 点击
    }

    _NewId() {
        this.seq += 1
        return "Cmd" this.seq
    }
}
