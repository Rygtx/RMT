#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 运行时节点注入 / 连线管理
;
; 完整节点 / 摘要节点的运行时注入、画布坐标同步，以及连线捕获 / 启停 / 归一 /
; 重绑 / 加粗等连线管理。方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphConnectionsMixin {
    ; 运行时注入一个完整可内联编辑的节点（不重建窗口）：
    ;   片段 XAML → AddXamlItem；登记 g.nodes；补绑引擎拖动/选中事件 + 本类事件；启用拖动。
    _InjectFullNode(id, node) {
        g := this.graph
        this._NodeFragments(id, node, &nodeXaml, &portInXaml, &portOutXaml)
        g.ui.Update(g.id, "AddXamlItem", nodeXaml)
        ; 端口已嵌入 nodeXaml 中，无需单独注入

        p := this.pos[id]
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        nodeTitle := this._Parse(node.CurCMD).type
        g.nodes.Push({ Id: id, Title: nodeTitle, X: x, Y: y, W: (nodeTitle == GetLang("搜索Pro")) ? 380 : 200, H: 60, Type: "Process" })

        ; 引擎拖动/选中处理（移动端口与连线、整体拖拽、高亮）
        g.ui.OnEvent("Node_" id, "DragMove", ObjBindMethod(g, "OnNodeMoved", id))
        g.ui.OnEvent("Node_" id, "SelectNode", ObjBindMethod(g, "OnSelectNode", id))
        g.ui.OnEvent("Node_" id, "CtrlSelectNode", ObjBindMethod(g, "OnCtrlSelectNode", id))
        ; 本类事件（双击编辑 + 内联字段），runtime=true 同步向引擎补绑事件与采集
        this._RegisterMyNodeEvents(id, node, true)
        ; 启用该节点拖动（稍后，待元素就绪）
        SetTimer(() => g.ui.Update("Node_" id, "EnableDrag", "grid=20"), -150)
    }

    ; 从引擎节点(g.nodes，含框选整体拖拽后更新的坐标)同步回 this.pos（逻辑坐标，去画布偏移）
    _SyncPositionsFromGraph() {
        if (this.graph == "")
            return
        ox := this.graph.offsetX, oy := this.graph.offsetY
        for n in this.graph.nodes {
            if (this.pos.Has(n.Id))
                this.pos[n.Id] := { x: n.X - ox, y: n.Y - oy }
        }
    }

    ; 运行时注入一个简要节点（标题 + 摘要 + 提示），双击可进完整编辑器
    _InjectSummaryNode(id, node) {
        g := this.graph
        p := this.pos[id]
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        d := this._Parse(node.CurCMD)
        ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"'
        title := this._XmlEsc(d.type)
        detail := this._XmlEsc(this._Summary(d))
        tip := this._XmlEsc(GetLang("双击编辑"))

        nodeXaml := '<Border ' ns ' x:Name="Node_' id '" Background="{DynamicResource DropdownBg}" BorderBrush="{DynamicResource ControlBorder}" BorderThickness="1" CornerRadius="6" Width="200" Canvas.Left="' x '" Canvas.Top="' y '"><Border.Effect><DropShadowEffect BlurRadius="8" ShadowDepth="2" Opacity="0.4" Direction="270" Color="Black"/></Border.Effect><Grid><Grid.RowDefinitions><RowDefinition Height="30"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><Border Grid.Row="0" Background="#3E3E50" CornerRadius="5,5,0,0" Cursor="SizeAll"><TextBlock Text="' title '" Foreground="White" FontWeight="Bold" FontSize="12" VerticalAlignment="Center" Margin="10,0"/></Border><StackPanel Grid.Row="1" Margin="10,6,10,8"><TextBlock Text="' detail '" Foreground="#DDDDDD" FontSize="12" TextWrapping="Wrap"/><TextBlock Text="' tip '" Foreground="#888888" FontSize="10" Margin="0,4,0,0"/></StackPanel></Grid>'
        ; 端口放在内容行(Row1)顶部，向上伸出标题栏下方
        ; 入点：左边距-15（左移），上边距-5（上伸到标题栏下方），出点：右边距-15（右移）
        portIn := '<Ellipse ' ns ' x:Name="Port_In_' id '" Width="14" Height="14" Fill="#4CAF50" Stroke="#333" StrokeThickness="1" Grid.Row="1" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="-7,-7,0,0" Panel.ZIndex="10" IsHitTestVisible="True" Cursor="Hand"/>'
        portOut := '<Ellipse ' ns ' x:Name="Port_Out_' id '" Width="14" Height="14" Fill="#FF5722" Stroke="#333" StrokeThickness="1" Grid.Row="1" VerticalAlignment="Top" HorizontalAlignment="Right" Margin="0,-7,-7,0" Panel.ZIndex="10" IsHitTestVisible="True" Cursor="Hand"/>'
        nodeXaml := StrReplace(nodeXaml, "</Grid>", portIn portOut "</Grid>")
        g.ui.Update(g.id, "AddXamlItem", nodeXaml)

        g.nodes.Push({ Id: id, Title: d.type, X: x, Y: y, W: 200, H: 60, Type: "Process" })

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

    _Summary(d) {
        if (d.type == GetLang("间隔")) {
            if (d.itype == GetLang("随机"))
                return d.time "~" d.time2 " ms"
            return d.time " ms"
        }
        if (d.type == GetLang("按键")) {
            s := d.key " " d.ktype
            if (d.ktype == GetLang("点击") && d.count != "1" && d.count != 1)
                s .= "  x" d.count
            return s
        }
        if (d.type == GetLang("移动"))
            return "(" d.posx ", " d.posy ")  " GetLang("移动速度：") d.speed
        if (d.type == GetLang("搜索") || d.type == GetLang("搜索Pro")) {
            typeNames := [GetLang("屏幕图片"), GetLang("屏幕颜色"), GetLang("屏幕文本"), GetLang("窗口图片"), GetLang("窗口颜色"), GetLang("窗口文本")]
            st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= 6) ? d.searchType : 1
            typeStr := typeNames[st]
            cls := this._SearchTypeClass(st)
            if (cls.isColor)
                return typeStr "  #" d.searchColor
            if (cls.isText) {
                q := Chr(34)
                return typeStr "  " q d.searchText q
            }
            imgName := d.HasOwnProp("searchImagePath") ? RegExReplace(d.searchImagePath, ".*\\", "") : GetLang("未设置")
            return typeStr "  " imgName
        }
        return d.raw
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
        seen := Map()
        for conn in this.graph.connections {
            ; 跳过已停用（折叠隐藏）的连线，它们在画面上不可见、逻辑上也不是当前后继
            if (conn.HasOwnProp("Active") && !conn.Active)
                continue
            from := conn.From
            to := conn.To
            ; 「分支 → X」翻译回「搜索 → X」（分支出点即搜索的后继出点）
            bi := this._BranchInfo(from)
            if (bi != "")
                from := bi.searchId
            ; 「X → 分支」翻译为「X → 分支所属搜索节点」（逻辑上汇入该搜索节点）
            bt := this._BranchInfo(to)
            if (bt != "")
                to := bt.searchId
            ; 丢弃「搜索 → 分支节点」的强制连线（显示用，逻辑上不是真正后继）
            if (this._IsBranchId(conn.To) || from == to)
                continue
            k := from "|" to
            if (seen.Has(k))
                continue
            seen[k] := true
            newLinks.Push({ from: from, to: to })
        }
        this.links := newLinks
    }

    ; 用户新建连线后：纠正展开搜索的连线（搜索→X 改走双分支、补对称分支），再加粗并补绑点击
    _OnConnectionsChanged() {
        this._NormalizeBranchConnections()
        this._ThickenConnections()
        this._RebindPathClicks()
    }

    ; 展开态搜索节点的连线纠正：
    ; ①用户把「展开搜索 → X」直连后续 → 改成「真分支→X」「假分支→X」（搜索只能连分支）
    ; ②用户把「某分支 → X」 → 自动补上「另一分支 → X」，对称表达"分支择一后汇合到 X"
    _NormalizeBranchConnections() {
        g := this.graph
        if (g == "")
            return
        toDeactivate := []
        toActivate := []
        for conn in g.connections {
            if (conn.HasOwnProp("Active") && !conn.Active)
                continue
            ; ① 展开搜索的出点被直连到非分支节点：拆成双分支连线
            if (this._IsExpandedSearch(conn.From) && !this._IsBranchId(conn.To)) {
                toDeactivate.Push(conn)
                toActivate.Push({ from: this._BranchId(conn.From, true), to: conn.To })
                toActivate.Push({ from: this._BranchId(conn.From, false), to: conn.To })
                continue
            }
            ; ② 分支连到后续节点：补对称的另一分支
            bi := this._BranchInfo(conn.From)
            if (bi != "" && !this._IsBranchId(conn.To))
                toActivate.Push({ from: this._BranchId(bi.searchId, !bi.isTrue), to: conn.To })
        }
        for conn in toDeactivate
            this._DeactivateConnection(conn)
        for a in toActivate
            this._ActivateConnection(a.from, a.to)
    }

    ; 激活（新建或重新显示）一条连线，并标记为有效后继
    _ActivateConnection(from, to) {
        g := this.graph
        if (g == "")
            return
        g.AddConnection(from, to)   ; 不存在则新建；已存在则重新置为可见并刷新路径
        pathId := g.id "_Path_" from "_" to
        for conn in g.connections {
            if (conn.PathId == pathId) {
                conn.Active := true
                break
            }
        }
        this.ui.Update(pathId, "StrokeThickness", "4")
        this.ui.OnEvent(pathId, "MouseLeftButtonDown", ObjBindMethod(g, "OnPathClicked", pathId))
    }

    ; 停用一条连线：仅隐藏路径并标记失效（不从画布移除，避免桥接器 NameScope 残留导致重建冲突）
    _DeactivateConnection(conn) {
        conn.Active := false
        this.ui.Update(conn.PathId, "Visibility", "Collapsed")
    }

    ; 重新绑定所有连线的点击事件（连线集合变动后调用）
    _RebindPathClicks() {
        if (this.graph == "")
            return
        for conn in this.graph.connections
            this.ui.OnEvent(conn.PathId, "MouseLeftButtonDown", ObjBindMethod(this.graph, "OnPathClicked", conn.PathId))
    }

    ; 判断某连线是否牵涉到指定搜索节点的真/假分支（强制连线或分支出线）
    _ConnInvolvesSearchBranch(conn, searchId) {
        bf := this._BranchInfo(conn.From)
        bt := this._BranchInfo(conn.To)
        if (bf != "" && bf.searchId == searchId)
            return true
        if (bt != "" && bt.searchId == searchId)
            return true
        return false
    }

    ; 出点拖拽连线到空白处松开：记录源端口和位置，直接弹出指令菜单（不再经过右键菜单子菜单）
    _OnConnectionDropped(state, *) {
        if (!state.Has("ConnectionDropped"))
            return
        parts := StrSplit(state["ConnectionDropped"], ",")
        if (parts.Length >= 3) {
            this._pendingConnectionFrom := RegExReplace(parts[1], "^Port_(Out|In)2?_", "")
            this.graph.lastRightClickX := Number(parts[2])
            this.graph.lastRightClickY := Number(parts[3])
        }
        ; 连线拖放到空白处：直接弹出指令菜单（延迟一帧避开 mouse up 冲突）
        SetTimer(() => this.ui.Update("MG_DropCM", "IsOpen", "True"), -50)
        ; 监听菜单关闭：如果用户没有选择指令，清除 pending 状态
        this.ui.OnEvent("MG_DropCM", "Closed", (*) => (this._pendingConnectionFrom := ""))
    }

    ; 把所有连线加粗，增大命中区域以便单击选中（默认 2.5px 太细难以点中）
    _ThickenConnections() {
        if (this.graph == "" || this.ui == "")
            return
        for conn in this.graph.connections
            this.ui.Update(conn.PathId, "StrokeThickness", "4")
    }
}

_GraftMacroGraphMixin(MacroGraphConnectionsMixin)
