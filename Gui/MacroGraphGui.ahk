#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui —— 蓝图式（节点化）宏指令编辑器
;
; 说明：节点数据对象 MacroGraphNode 已在 Main\DataClass.Ahk 中定义
;       （字段 SerialStr / CurCMD / NextNodeArr）。本编辑器中每个节点仅持有
;       完整指令字符串 CurCMD，其余信息（类型/时间/按键/点击时长…）全部通过
;       解析 CurCMD 实时获得（见 _Parse）。
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
        this.cmdNodes := Map()        ; nodeId -> MacroGraphNode 实例（仅持有 CurCMD）
        this.order := []              ; 指令节点 id 列表（存在性，不决定连线）
        this.pos := Map()             ; nodeId(含Start) -> { x, y } 逻辑坐标(不含画布偏移)
        this.links := []              ; 连线 [{ from, to }]，跨重建保留
        this.seq := 0
        this.startId := "Start"
        this._readyTimer := this._EnableWhenReady.Bind(this)
        this._lastClickId := ""
        this._lastClickTime := 0
        this._oldUi := ""             ; 双缓冲：重建时暂存旧窗口，待新窗口就绪后再关闭
        this.injected := Map()        ; 运行时注入(简要)的节点 id；这类节点编辑后需重建为完整内联节点
        this.startSerial := ""        ; 本图开始节点(MacroGraphStartNode)的 SerialStr；保存后回写 MacroArr 即此值
        this._sessionId := 0          ; 每次打开自增；用于忽略旧窗口迟到的异步关闭事件，避免覆盖写空

        ; 若梦兔全部指令
        this.CmdList := GetLangArr(["间隔", "按键", "搜索", "搜索Pro", "移动", "移动Pro", "输入", "输出", "循环", "宏操作",
            "变量", "变量提取", "如果", "如果Pro", "运算", "运行", "文件读写", "文本处理", "数组", "RMT指令", "后台鼠标",
            "后台按键", "窗口管理", "按键检测"])

        ; 各指令对应图标（顺序与 CmdList 一一对应，复用 MacroEditGui 的图标资源）
        this.CmdIconArr := ["Images\Soft\Interval.png", "Images\Soft\Key.png",
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
            "Images\Soft\WindowManage.png", "Images\Soft\KeyCheck.png"]

        ; 复用现有子编辑器（双击节点时打开）
        this.IntervalGui := IntervalGui()
        this.KeyGui := KeyGui()
        this.MouseGui := MouseMoveGui()
        this.SearchGui := SearchGui()
        this.SearchProGui := SearchProGui()
        this.MMProGui := MMProGui()
        this.BranchGraphGui := ""     ; 搜索真/假分支的「嵌套节点编辑器」（懒加载，编辑分支子图）
        this._branchExpanded := Map() ; 分支节点是否展开显示全部指令（key=分支合成ID）
        this._branchInjected := Map() ; 本窗口生命周期内已注入过分支节点的搜索ID（折叠/展开时只显隐不重建）
        this._foldShift := Map()      ; 展开时为腾出分支空间而对后继子树施加的右移量（key=搜索ID），收起时据此还原
        this.OnClosedAction := ""     ; 窗口关闭后回调（嵌套分支编辑器用于通知父图刷新）
        this._shotNodeId := ""        ; 正在执行截图取色的搜索节点ID（截图剪贴板回调用）
        this._searchClipAction := ObjBindMethod(this, "_SearchCheckClipboard") ; 截图剪贴板轮询回调（稳定引用，便于 SetTimer 开关）
    }

    ; 指令图标的绝对路径（正斜杠，供 WPF Image.Source 使用）；不存在则返回空
    _IconUri(idx) {
        if (idx < 1 || idx > this.CmdIconArr.Length)
            return ""
        full := A_WorkingDir "\" this.CmdIconArr[idx]
        if (!FileExist(full))
            return ""
        return StrReplace(full, "\", "/")
    }

    ; ----------------------------------------------------------------- 入口

    ShowGui(macroStr, key := "") {
        this._sessionId += 1
        this._CloseUI()
        this.startSerial := ""
        this.cmdNodes := Map()
        this.order := []
        this.pos := Map()
        this.links := []
        this.seq := 0

        ; 优先从已保存的图结构复原：macroStr 此时即开始节点(MacroGraphStartNode)的 SerialStr。
        ; 复原成功直接显示；否则按线性宏铺开（首次打开或旧的线性宏）。
        if (this._LoadGraph(macroStr)) {
            this._Render()
            return
        }

        ; 线性铺开（首次/旧数据）：开始节点 + 各指令节点依次串联，无结束节点
        this.startSerial := GetCMDSerialStr("图形开始节点")
        baseY := 220, step := 240, x := 60
        this.pos[this.startId] := { x: x, y: baseY }
        prevId := this.startId
        x += step
        for cmd in SplitMacro(macroStr) {
            id := this._NewId()
            this.cmdNodes[id] := this._MakeNode(cmd)
            this.order.Push(id)
            this.pos[id] := { x: x, y: baseY }
            this.links.Push({ from: prevId, to: id })
            prevId := id
            x += step
        }
        this._Render()
    }

    ; 根据数据模型构建并显示窗口（始终最大化；节点用保存的坐标，连线用 links）
    _Render() {
        ; 双缓冲：先创建并显示新窗口，待其就绪后再关闭旧窗口，避免新增节点时窗口闪缩
        oldUi := this.ui
        this.graph := ""
        this.injected := Map()        ; 重建后所有节点均为完整内联节点
        this._branchInjected := Map() ; 新窗口：分支节点注入记录清零（NameScope 全新）
        this._foldShift := Map()      ; 新窗口：折叠展开位移记录清零（坐标以画布保存值为准）

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
        root.Add("Button").Name("MG_BtnSave").Content(GetLang("保存")).HorizontalAlignment("Right").VerticalAlignment("Top").Margin("0,12,16,0").Width("90").Height("32").Background("#2E6E3E").Foreground("White").BorderThickness("0").FontSize("14").Cursor("Hand")

        ; 节点（使用各自保存的坐标）
        this._BuildBaseNode(this.startId, GetLang("开始"), "Input")
        for id in this.order
            this._BuildCmdNode(id, this.cmdNodes[id])

        ; 搜索节点（展开态）：构建强制绑定的真/假分支节点
        for id in this.order {
            if (this._IsExpandedSearch(id)) {
                this._BuildBranchPair(id)
                this._branchInjected[id] := true
            }
        }

        ; 连线（来自 links，跨重建保留）。展开的搜索节点：其后继经真/假分支节点转发，
        ; 表达「执行分支后再执行后续节点」；折叠时搜索直连后续。
        for link in this.links {
            if (!this._NodeExists(link.from) || !this._NodeExists(link.to))
                continue
            if (this._IsExpandedSearch(link.from)) {
                this.graph.AddConnection(this._BranchId(link.from, true), link.to)
                this.graph.AddConnection(this._BranchId(link.from, false), link.to)
            } else {
                this.graph.AddConnection(link.from, link.to)
            }
        }

        ; 右键菜单（_BuildContextMenu 内部会把 ContextMenu 属性元素移到画布子元素最前，
        ; 保证属性元素先于内容，避免 WPF 报 Canvas Children 重复设置）
        this._BuildContextMenu()

        ; ---- 宿主 ----
        ownerHwnd := this.OwnerHwnd != "" ? this.OwnerHwnd : 0
        this.ui := XAMLHost(win.ToString(), "", ownerHwnd)
        this.graph.Bind(this.ui)
        this._RegisterNodeEvents()
        ; 为所有连线补绑点击事件（XNodeGraph 仅给运行时新增连线绑定，构建期连线需手动补）
        for conn in this.graph.connections
            this.ui.OnEvent(conn.PathId, "MouseLeftButtonDown", ObjBindMethod(this.graph, "OnPathClicked", conn.PathId))
        ; 用户新建连线后，对新连线加粗并补绑点击（便于单击选中）
        this.ui.OnEvent(this.graph.id, "ConnectPorts", (*) => this._OnConnectionsChanged())
        ; 出点拖拽连线到空白处松开：记录源端口和位置，弹出指令菜单
        this.ui.OnEvent(this.graph.id, "ConnectionDropped", this._OnConnectionDropped.Bind(this))
        ; Start 跟踪拖动位置
        this.ui.OnEvent("Node_" this.startId, "DragMove", this._OnNodeDrag.Bind(this, this.startId))
        for i, name in this.CmdList
            this.ui.OnEvent("MG_Add_" i, "Click", this.OnAddCmd.Bind(this, name))
        ; 出点连线到空白处：直接弹出指令菜单项事件（共用 OnAddCmd，内部已有 _pendingConnectionFrom 检测）
        for i, name in this.CmdList
            this.ui.OnEvent("MG_Drop_" i, "Click", this.OnAddCmd.Bind(this, name))
        this.ui.OnEvent("MG_Copy", "Click", (*) => this._CopySelected())
        this.ui.OnEvent("MG_Paste", "Click", (*) => this._PasteNodes())
        this.ui.OnEvent("MG_Delete", "Click", (*) => this._DeleteSelected())
        this.ui.OnEvent("MG_Edit", "Click", (*) => this._EditSelected())
        ; 右键菜单打开前更新菜单项状态
        this.ui.OnEvent(this.graph.id, "ContextMenuOpened", (*) => this._UpdateMenuState())
        this.ui.OnEvent("MG_BtnSave", "Click", (*) => this._OnSave())
        this.ui.OnEvent("Window", "PreviewKeyDown", this._OnKeyDown.Bind(this))
        sid := this._sessionId
        this.ui.OnEvent("Window", "Closed", (*) => this.OnWindowClosed(sid))

        ; 为所有内联编辑 TextBox 绑定回车事件（输入完成后刷新节点数据）
        this._BindTextBoxEnterEvents()

        this.ui.Show()
        this._oldUi := oldUi
        SetTimer(this._readyTimer, 50)
    }

    _NodeExists(id) {
        return id == this.startId || this.cmdNodes.Has(id)
    }

    _EnableWhenReady() {
        if (this.ui == "" || !this.ui.wpfHwnd)
            return
        SetTimer(this._readyTimer, 0)
        this.graph.EnableDrag(this.ui, true)
        this._ThickenConnections()    ; 加粗连线，增大命中区域便于单击选中
        ; 启用画布"框选"模式：左键在空白处拖拽即可框选多个节点（C# 引擎已实现，默认 Pan 不生效）
        this.ui.Update(this.graph.id, "SetCanvasMode", "Select")
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

    ; 保存：仅持久化图结构并回写线性宏（从第一个节点开始），不关闭编辑界面
    _OnSave() {
        this._SaveGraph()
        this._Apply()
    }

    OnWindowClosed(sid := -1, *) {
        ; 仅处理当前会话窗口的关闭；旧窗口迟到的异步关闭事件直接忽略，避免覆盖写空
        if (sid != this._sessionId)
            return
        SetTimer(this._readyTimer, 0)
        this._SaveGraph()
        this._Apply()
        this.ui := ""
        this.graph := ""
        if (this.OnClosedAction != "") {
            cb := this.OnClosedAction
            cb()
        }
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
        for id, node in this.cmdNodes
            this._RegisterMyNodeEvents(id, node, false)
        ; 展开搜索节点的真/假分支节点事件（双击进编辑器 + 展开按钮）
        for id in this.order {
            if (this._IsExpandedSearch(id)) {
                this._RegisterBranchEvents(id, true)
                this._RegisterBranchEvents(id, false)
            }
        }
    }

    ; 注册单个分支节点的事件：选中（用于双击判定）+ 展开/收起按钮。runtime=true 时为运行时注入控件补绑。
    _RegisterBranchEvents(searchId, isTrue, runtime := false) {
        brId := this._BranchId(searchId, isTrue)
        this.ui.OnEvent("Node_" brId, "SelectNode", this._OnBranchClick.Bind(this, searchId, isTrue))
        this.ui.OnEvent("Node_" brId, "CtrlSelectNode", this._OnBranchClick.Bind(this, searchId, isTrue))
        this._BindCtrl("SBExpand_" brId, "Click", this._OnBranchToggleExpand.Bind(this, searchId, isTrue), runtime)
    }

    ; 注册单个节点的"本类"事件（双击编辑 + 内联字段）。runtime=true 时同时向引擎补绑/补采集
    ; （运行时注入的控件不在启动期的事件/采集清单里，需用 BindEvent/Track 命令动态补上）。
    _RegisterMyNodeEvents(id, node, runtime := false) {
        ; 双击节点打开完整编辑器（节点是 Border，无原生双击，用 SelectNode 计时判定）
        ; SelectNode/CtrlSelectNode/DragMove 由引擎 EnableDrag 主动下发，仅需本地 OnEvent 接收
        this.ui.OnEvent("Node_" id, "SelectNode", this._OnNodeClick.Bind(this, id))
        this.ui.OnEvent("Node_" id, "CtrlSelectNode", this._OnNodeClick.Bind(this, id))
        this.ui.OnEvent("Node_" id, "DragMove", this._OnNodeDrag.Bind(this, id))

        d := this._Parse(node.CurCMD)
        if (d.type == GetLang("间隔")) {
            this._TrackCtrl("ITypeCmb_" id, runtime)
            this._TrackCtrl("Time_" id, runtime)
            this._TrackCtrl("Time2_" id, runtime)
            this._BindCtrl("ITypeCmb_" id, "SelectionChanged", this._OnIntervalType.Bind(this, id), runtime)
            this._BindCtrl("Time_" id, "LostFocus", this._OnField.Bind(this, id, "time"), runtime)
            this._BindCtrl("Time_" id, "SelectionChanged", this._OnField.Bind(this, id, "time"), runtime)
            this._BindCtrl("Time2_" id, "LostFocus", this._OnField.Bind(this, id, "time2"), runtime)
            this._BindCtrl("Time2_" id, "SelectionChanged", this._OnField.Bind(this, id, "time2"), runtime)
        }
        else if (d.type == GetLang("按键")) {
            this._TrackCtrl("TypeCmb_" id, runtime)
            this._TrackCtrl("Hold_" id, runtime)
            this._TrackCtrl("Count_" id, runtime)
            this._TrackCtrl("Inter_" id, runtime)
            this._BindCtrl("TypeCmb_" id, "SelectionChanged", this._OnKeyType.Bind(this, id), runtime)
            this._BindCtrl("Hold_" id, "LostFocus", this._OnField.Bind(this, id, "hold"), runtime)
            this._BindCtrl("Count_" id, "LostFocus", this._OnField.Bind(this, id, "count"), runtime)
            this._BindCtrl("Inter_" id, "LostFocus", this._OnField.Bind(this, id, "inter"), runtime)
        }
        else if (d.type == GetLang("移动")) {
            this._TrackCtrl("PosX_" id, runtime)
            this._TrackCtrl("PosY_" id, runtime)
            this._TrackCtrl("Speed_" id, runtime)
            this._TrackCtrl("ModeCmb_" id, runtime)
            this._BindCtrl("PosX_" id, "LostFocus", this._OnField.Bind(this, id, "posx"), runtime)
            this._BindCtrl("PosY_" id, "LostFocus", this._OnField.Bind(this, id, "posy"), runtime)
            this._BindCtrl("Speed_" id, "LostFocus", this._OnField.Bind(this, id, "speed"), runtime)
            this._BindCtrl("ModeCmb_" id, "SelectionChanged", this._OnMoveMode.Bind(this, id), runtime)
        }
        else if (d.type == GetLang("移动Pro")) {
            this._TrackCtrl("MPPosX_" id, runtime)
            this._TrackCtrl("MPPosY_" id, runtime)
            this._TrackCtrl("MPSpeed_" id, runtime)
            this._TrackCtrl("MPActionCmb_" id, runtime)
            this._TrackCtrl("MPModeCmb_" id, runtime)
            this._TrackCtrl("MPHuman_" id, runtime)
            this._TrackCtrl("MPCount_" id, runtime)
            this._TrackCtrl("MPInterval_" id, runtime)
            this._BindCtrl("MPPosX_" id, "LostFocus", this._OnMMProField.Bind(this, id, "PosVarX"), runtime)
            this._BindCtrl("MPPosX_" id, "SelectionChanged", this._OnMMProField.Bind(this, id, "PosVarX"), runtime)
            this._BindCtrl("MPPosY_" id, "LostFocus", this._OnMMProField.Bind(this, id, "PosVarY"), runtime)
            this._BindCtrl("MPPosY_" id, "SelectionChanged", this._OnMMProField.Bind(this, id, "PosVarY"), runtime)
            this._BindCtrl("MPSpeed_" id, "LostFocus", this._OnMMProField.Bind(this, id, "Speed"), runtime)
            this._BindCtrl("MPSpeed_" id, "KeyDown:Return", this._OnMMProField.Bind(this, id, "Speed"), runtime)
            this._BindCtrl("MPActionCmb_" id, "SelectionChanged", this._OnMMProAction.Bind(this, id), runtime)
            this._BindCtrl("MPModeCmb_" id, "SelectionChanged", this._OnMMProMode.Bind(this, id), runtime)
            this._BindCtrl("MPHuman_" id, "Click", this._OnMMProHuman.Bind(this, id), runtime)
            this._BindCtrl("MPCount_" id, "LostFocus", this._OnMMProField.Bind(this, id, "Count"), runtime)
            this._BindCtrl("MPCount_" id, "KeyDown:Return", this._OnMMProField.Bind(this, id, "Count"), runtime)
            this._BindCtrl("MPInterval_" id, "LostFocus", this._OnMMProField.Bind(this, id, "Interval"), runtime)
            this._BindCtrl("MPInterval_" id, "KeyDown:Return", this._OnMMProField.Bind(this, id, "Interval"), runtime)
        }
        else if (d.type == GetLang("搜索") || d.type == GetLang("搜索Pro")) {
            isPro := (d.type == GetLang("搜索Pro"))
            this._TrackCtrl("STypeCmb_" id, runtime)
            this._TrackCtrl("SColor_" id, runtime)
            this._TrackCtrl("SText_" id, runtime)
            this._TrackCtrl("SSim_" id, runtime)
            this._TrackCtrl("SStartX_" id, runtime)
            this._TrackCtrl("SStartY_" id, runtime)
            this._TrackCtrl("SEndX_" id, runtime)
            this._TrackCtrl("SEndY_" id, runtime)
            this._TrackCtrl("SActCmb_" id, runtime)
            this._BindCtrl("STypeCmb_" id, "SelectionChanged", this._OnSearchType.Bind(this, id), runtime)
            this._BindCtrl("SColor_" id, "LostFocus", this._OnSearchField.Bind(this, id, "SearchColor"), runtime)
            this._BindCtrl("SText_" id, "LostFocus", this._OnSearchField.Bind(this, id, "SearchText"), runtime)
            this._BindCtrl("SSim_" id, "LostFocus", this._OnSearchField.Bind(this, id, "Similar"), runtime)
            this._BindCtrl("SStartX_" id, "LostFocus", this._OnSearchField.Bind(this, id, "StartPosX"), runtime)
            this._BindCtrl("SStartY_" id, "LostFocus", this._OnSearchField.Bind(this, id, "StartPosY"), runtime)
            this._BindCtrl("SEndX_" id, "LostFocus", this._OnSearchField.Bind(this, id, "EndPosX"), runtime)
            this._BindCtrl("SEndY_" id, "LostFocus", this._OnSearchField.Bind(this, id, "EndPosY"), runtime)
            this._BindCtrl("SActCmb_" id, "SelectionChanged", this._OnSearchAction.Bind(this, id), runtime)
            ; 操作按钮：截图 / 选择图片 / 定位取色器 / 框选范围
            this._BindCtrl("SShot_" id, "Click", this._OnSearchShot.Bind(this, id), runtime)
            this._BindCtrl("SPic_" id, "Click", this._OnSearchPic.Bind(this, id), runtime)
            this._BindCtrl("SPick_" id, "Click", this._OnSearchPick.Bind(this, id), runtime)
            this._BindCtrl("SArea_" id, "Click", this._OnSearchArea.Bind(this, id), runtime)
            ; 标题栏折叠/展开按钮（控制真/假分支节点显隐）
            this._BindCtrl("SFold_" id, "Click", this._OnToggleFold.Bind(this, id), runtime)
            ; 搜索Pro 专属控件：坐标可编辑下拉(补 SelectionChanged) + 更多参数 + 结果/目标点保存
            if (isPro) {
                this._BindCtrl("SStartX_" id, "SelectionChanged", this._OnSearchField.Bind(this, id, "StartPosX"), runtime)
                this._BindCtrl("SStartY_" id, "SelectionChanged", this._OnSearchField.Bind(this, id, "StartPosY"), runtime)
                this._BindCtrl("SEndX_" id, "SelectionChanged", this._OnSearchField.Bind(this, id, "EndPosX"), runtime)
                this._BindCtrl("SEndY_" id, "SelectionChanged", this._OnSearchField.Bind(this, id, "EndPosY"), runtime)
                for nm in ["SWin_", "SCount_", "SInterval_", "SClick_", "SSpeed_", "SResName_", "SResTrue_", "SResFalse_", "SCoordX_", "SCoordY_"]
                    this._TrackCtrl(nm id, runtime)
                this._TrackCtrl("SResTog_" id, runtime)
                this._TrackCtrl("SCoordTog_" id, runtime)
                this._BindCtrl("SWin_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "WinInfo"), runtime)
                this._BindCtrl("SWinEdit_" id, "Click", this._OnSearchWinEdit.Bind(this, id), runtime)
                this._BindCtrl("SCount_" id, "LostFocus", this._OnSearchCount.Bind(this, id), runtime)
                this._BindCtrl("SCount_" id, "SelectionChanged", this._OnSearchCount.Bind(this, id), runtime)
                this._BindCtrl("SInterval_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "SearchInterval"), runtime)
                this._BindCtrl("SClick_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "ClickCount"), runtime)
                this._BindCtrl("SSpeed_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "Speed"), runtime)
                this._BindCtrl("SResTog_" id, "Click", this._OnSearchResultToggle.Bind(this, id), runtime)
                this._BindCtrl("SResName_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "ResultSaveName"), runtime)
                this._BindCtrl("SResName_" id, "SelectionChanged", this._OnSearchProField.Bind(this, id, "ResultSaveName"), runtime)
                this._BindCtrl("SResTrue_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "TrueValue"), runtime)
                this._BindCtrl("SResFalse_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "FalseValue"), runtime)
                this._BindCtrl("SCoordTog_" id, "Click", this._OnSearchCoordToggle.Bind(this, id), runtime)
                this._BindCtrl("SCoordX_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "CoordXName"), runtime)
                this._BindCtrl("SCoordX_" id, "SelectionChanged", this._OnSearchProField.Bind(this, id, "CoordXName"), runtime)
                this._BindCtrl("SCoordY_" id, "LostFocus", this._OnSearchProField.Bind(this, id, "CoordYName"), runtime)
                this._BindCtrl("SCoordY_" id, "SelectionChanged", this._OnSearchProField.Bind(this, id, "CoordYName"), runtime)
            }
        }
    }

    ; 采集控件值：本地登记（启动期清单用）；运行时再用 Track 命令通知引擎纳入状态采集
    _TrackCtrl(name, runtime) {
        this.ui.Track(name)
        if (runtime)
            this.ui.Update(name, "Track", "")
    }

    ; 绑定控件事件：本地登记回调；运行时再用 BindEvent 命令让引擎为该控件挂上真实 WPF 事件
    _BindCtrl(name, evt, cb, runtime) {
        this.ui.OnEvent(name, evt, cb)
        if (runtime)
            this.ui.Update(name, "BindEvent", evt)
    }

    ; 拖动节点时记录其逻辑坐标（DragCoords 为画布坐标，需减去画布偏移）
    _OnNodeDrag(id, state, *) {
        if (!state.Has("DragCoords") || !this.pos.Has(id) || this.graph == "")
            return
        parts := StrSplit(state["DragCoords"], ",")
        if (parts.Length >= 2) {
            this.pos[id].x := Number(parts[1]) - this.graph.offsetX
            this.pos[id].y := Number(parts[2]) - this.graph.offsetY
            ; 注：搜索节点拖动时不再联动真/假分支节点（分支可独立摆放），仅引擎自动刷新相关连线
        }
    }

    ; 窗口按键：选中节点/连线后按 Delete 删除（事件名形如 KeyDown:Delete，第三参为 {Key} 或字符串）
    _OnKeyDown(state, ctrl, info) {
        key := ""
        ctrlDown := false
        if (IsObject(info)) {
            try key := info.Key
        } else if (Type(info) == "String") {
            parts := StrSplit(info, ":")
            key := parts.Length >= 2 ? parts[2] : ""
            ctrlDown := parts.Length >= 3 && (Number(parts[3]) & 2)
        }
        if (key == "Delete" || key == "Back")
            this._DeleteSelected()
        else if (ctrlDown && (key == "C" || key == "c"))
            this._CopySelected()
        else if (ctrlDown && (key == "V" || key == "v"))
            this._PasteNodes()
    }

    ; 删除当前选中的节点与连线（就地隐藏，不重建窗口）
    _DeleteSelected() {
        if (this.graph == "")
            return
        ; 记录被删搜索节点（其强制绑定的真/假分支节点需随之清理）
        searchIds := []
        for sid in this.graph.selectedNodes {
            if (this._IsSearchNodeId(sid))
                searchIds.Push(sid)
        }
        this.graph.DeleteSelectedConnections()
        this._DeleteSelectedNodes()
        ; 运行时隐藏并移除分支节点（避免整窗重建闪烁）
        for sid in searchIds
            this._RemoveBranchNodesRuntime(sid)
        this._CaptureLinks()
        this._Apply()
    }

    ; 运行时清理一个搜索节点的真/假分支节点（隐藏 UI、移除节点表与连线），不重建窗口
    _RemoveBranchNodesRuntime(searchId) {
        g := this.graph
        if (g == "")
            return
        for isTrue in [true, false] {
            brId := this._BranchId(searchId, isTrue)
            g.ui.Update("Node_" brId, "Visibility", "Collapsed")
            g.ui.Update("Port_In_" brId, "Visibility", "Collapsed")
            g.ui.Update("Port_Out_" brId, "Visibility", "Collapsed")
            keep := []
            for conn in g.connections {
                if (conn.From == brId || conn.To == brId)
                    g.ui.Update(conn.PathId, "Visibility", "Collapsed")
                else
                    keep.Push(conn)
            }
            g.connections := keep
            nkeep := []
            for n in g.nodes {
                if (n.Id != brId)
                    nkeep.Push(n)
            }
            g.nodes := nkeep
            if (this.pos.Has(brId))
                this.pos.Delete(brId)
            if (g.selectedNodes.Has(brId))
                g.selectedNodes.Delete(brId)
        }
        if (this._branchInjected.Has(searchId))
            this._branchInjected.Delete(searchId)
    }

    _DeleteSelectedNodes() {
        g := this.graph
        ids := []
        for id in g.selectedNodes
            ids.Push(id)
        for id in ids {
            if (id == this.startId || !this.cmdNodes.Has(id))
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

    ; 编辑选中的单个节点（打开对应编辑器）
    _EditSelected() {
        if (this.graph == "")
            return
        g := this.graph
        if (g.selectedNodes.Count != 1)
            return
        for id in g.selectedNodes {
            this.OpenNodeEditor(id)
            break
        }
    }

    ; 复制当前选中的节点（保存 CurCMD 和相对偏移到剪贴板）
    _CopySelected() {
        if (this.graph == "")
            return
        g := this.graph
        if (g.selectedNodes.Count == 0)
            return
        ; 收集选中节点数据
        copyData := []
        firstX := "", firstY := ""
        selIds := []
        for id in g.selectedNodes {
            if (id == this.startId || !this.cmdNodes.Has(id))
                continue
            node := this.cmdNodes[id]
            p := this.pos.Has(id) ? this.pos[id] : { x: 0, y: 0 }
            if (firstX == "") {
                firstX := p.x
                firstY := p.y
            }
            copyData.Push({ cmd: node.CurCMD, dx: p.x - firstX, dy: p.y - firstY, srcId: id })
            selIds.Push(id)
        }
        if (copyData.Length == 0)
            return
        ; 收集选中节点之间的连线
        copyLinks := []
        selSet := Map()
        for id in selIds
            selSet[id] := true
        for conn in g.connections {
            if (selSet.Has(conn.From) && selSet.Has(conn.To))
                copyLinks.Push({ from: conn.From, to: conn.To })
        }
        this._clipboard := { nodes: copyData, links: copyLinks }
    }

    ; 粘贴剪贴板中的节点
    _PasteNodes() {
        if (this.graph == "" || this.ui == "" || !this.ui.wpfHwnd)
            return
        if (!this.HasOwnProp("_clipboard") || !this._clipboard || !this._clipboard.nodes)
            return
        this._CaptureLinks()
        this._SyncPositionsFromGraph()
        g := this.graph
        ; 粘贴位置：右键位置或画布中心
        ox := g.HasProp("lastRightClickX") ? g.lastRightClickX - g.offsetX : 300
        oy := g.HasProp("lastRightClickY") ? g.lastRightClickY - g.offsetY : 300
        ; 创建 id 映射（旧 id -> 新 id）
        idMap := Map()
        newIds := []
        for cd in this._clipboard.nodes {
            id := this._NewId()
            ; 移动Pro 的参数存于 INI，复制时需克隆出独立序列码与数据，避免与源节点共享同一份配置
            pasteCmd := cd.cmd
            pasteHead := SplitCommand(pasteCmd)
            if (pasteHead.Length >= 1 && this._IsMMProName(pasteHead[1]))
                pasteCmd := this._CloneMMPro(pasteCmd)
            else if (pasteHead.Length >= 1 && (this._IsSearchName(pasteHead[1]) || this._IsSearchProName(pasteHead[1])))
                pasteCmd := this._CloneSearch(pasteCmd)
            node := this._MakeNode(pasteCmd)
            this.cmdNodes[id] := node
            this.order.Push(id)
            this.pos[id] := { x: ox + cd.dx + 40, y: oy + cd.dy + 40 }
            idMap[cd.srcId] := id
            newIds.Push(id)
        }
        ; 恢复选中节点之间的连线（记录到 links，供重建/路由统一处理）
        for link in this._clipboard.links {
            newFrom := idMap.Has(link.from) ? idMap[link.from] : ""
            newTo := idMap.Has(link.to) ? idMap[link.to] : ""
            if (newFrom != "" && newTo != "" && newFrom != newTo)
                this.links.Push({ from: newFrom, to: newTo })
        }
        ; 含搜索节点需建分支节点 → 整体重建；否则普通重建即可（统一走 _Render，保证路由一致）
        this._Render()
        this._Apply()
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
        canvas := this.graph.canvas
        cmEl := canvas.Add("FrameworkElement.ContextMenu")
        cm := cmEl.Add("ContextMenu").Name("MG_CM").MinWidth("180").Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness(1).Foreground("{DynamicResource TextMain}")

        ; 注入局部资源：仅 MenuItem 子菜单模板（一级菜单不需要 ScrollViewer）
        cm.InjectResources(this._MenuItemSubmenuStyle())

        ; 1. 编辑（仅选中单个节点时可交互）
        cm.Add("MenuItem").Name("MG_Edit").Header(GetLang("编辑"))

        ; 2. 新增指令（有子菜单）
        miAdd := cm.Add("MenuItem").Name("MG_AddRoot").Header(GetLang("新增指令"))
        for i, name in this.CmdList {
            mi := miAdd.Add("MenuItem").Name("MG_Add_" i).Header(name)
            iconUri := this._IconUri(i)
            if (iconUri != "")
                mi.Add("MenuItem.Icon").Add("Image").SetProp("Source", iconUri).Width("16").Height("16")
        }

        ; 3. 复制（快捷键提示）
        cm.Add("MenuItem").Name("MG_Copy").Header(GetLang("复制")).InputGestureText("Ctrl+C")

        ; 4. 粘贴（快捷键提示）
        cm.Add("MenuItem").Name("MG_Paste").Header(GetLang("粘贴")).InputGestureText("Ctrl+V")

        ; 5. 删除（快捷键提示）
        cm.Add("MenuItem").Name("MG_Delete").Header(GetLang("删除")).InputGestureText("Delete")

        ; ---- 出点连线到空白处用的指令弹出菜单（挂在隐藏 Border 上，与右键菜单独立） ----
        dropHost := canvas.Add("Border").Name("MG_DropHost").Width("0").Height("0").Visibility("Collapsed")
        dm := dropHost.Add("Border.ContextMenu").Add("ContextMenu").Name("MG_DropCM").MinWidth("180").MaxHeight("400").Placement("MousePoint").Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness(1).Foreground("{DynamicResource TextMain}")
        dm.InjectResources(this._ContextMenuScrollStyle())
        for i, name in this.CmdList {
            mi := dm.Add("MenuItem").Name("MG_Drop_" i).Header(name)
            iconUri := this._IconUri(i)
            if (iconUri != "")
                mi.Add("MenuItem.Icon").Add("Image").SetProp("Source", iconUri).Width("16").Height("16")
        }

        ; 将 ContextMenu 属性元素移到画布子元素最前
        ch := canvas._Children
        idx := 0
        for i, c in ch {
            if (c == cmEl) {
                idx := i
                break
            }
        }
        if (idx > 1) {
            ch.RemoveAt(idx)
            ch.InsertAt(1, cmEl)
        }
    }

    ; 支持子菜单的 MenuItem 模板（含 ▸ 箭头列 + 右向弹出 Popup）。
    ; 作为 ContextMenu 局部资源注入，覆盖全局主题中可能缺失子菜单支持的旧模板。
    ; 悬停蓝色高亮 + 仅父级菜单项悬停时展开子菜单（叶子项不展空 Popup，避免右侧水平条出现）。
    _MenuItemSubmenuStyle() {
        return ''
            . '<Style TargetType="MenuItem">'
            .   '<Setter Property="Background" Value="Transparent"/>'
            .   '<Setter Property="Foreground" Value="{DynamicResource TextMain}"/>'
            .   '<Setter Property="Padding" Value="10,8"/>'
            .   '<Setter Property="Template"><Setter.Value>'
            .     '<ControlTemplate TargetType="MenuItem">'
            .       '<Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}" CornerRadius="4">'
            .         '<Grid>'
            .           '<Grid.ColumnDefinitions>'
            .             '<ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/>'
            .           '</Grid.ColumnDefinitions>'
            .           '<ContentPresenter ContentSource="Icon" Margin="0,0,8,0" VerticalAlignment="Center"/>'
            .           '<ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>'
            .           '<TextBlock Grid.Column="2" Text="{TemplateBinding InputGestureText}" Foreground="{DynamicResource TextSub}" Margin="15,0,0,0" VerticalAlignment="Center"/>'
            .           '<Path Grid.Column="3" x:Name="ArrowPath" Data="M0,0 L4,4 L0,8 Z" Fill="{DynamicResource TextMain}" Margin="8,0,2,0" VerticalAlignment="Center" Visibility="Collapsed"/>'
            .           '<Popup x:Name="PART_Popup" AllowsTransparency="True" Placement="Right" HorizontalOffset="-3" PlacementTarget="{Binding RelativeSource={RelativeSource TemplatedParent}}" IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" Focusable="False">'
            .             '<Border Background="{DynamicResource DropdownBg}" BorderBrush="{DynamicResource ControlBorder}" BorderThickness="1" CornerRadius="6" Padding="4" MinWidth="180">'
            .               '<ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="400" Margin="4"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer>'
            .             '</Border>'
            .           '</Popup>'
            .         '</Grid>'
            .       '</Border>'
            .       '<ControlTemplate.Triggers>'
            .         '<Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="#0078D4"/><Setter Property="Foreground" Value="White"/></Trigger>'
            .         '<Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Bd" Property="Background" Value="#0078D4"/><Setter Property="Foreground" Value="White"/></Trigger>'
            .         '<Trigger Property="IsEnabled" Value="False"><Setter Property="Foreground" Value="{DynamicResource TextSub}"/></Trigger>'
            .         '<Trigger Property="HasItems" Value="True"><Setter TargetName="ArrowPath" Property="Visibility" Value="Visible"/></Trigger>'
            .         '<MultiTrigger><MultiTrigger.Conditions><Condition Property="IsMouseOver" Value="True"/><Condition Property="HasItems" Value="True"/></MultiTrigger.Conditions><Setter Property="IsSubmenuOpen" Value="True"/></MultiTrigger>'
            .       '</ControlTemplate.Triggers>'
            .     '</ControlTemplate>'
            .   '</Setter.Value></Setter>'
            . '</Style>'
    }

    ; 支持滚轮滑动的 ContextMenu 模板（ItemsPresenter 包裹在 ScrollViewer 中，修复无法通过滚轮滚动内容的问题）
    _ContextMenuScrollStyle() {
        return ''
            . '<Style TargetType="ContextMenu">'
            .   '<Setter Property="Template"><Setter.Value>'
            .     '<ControlTemplate TargetType="ContextMenu">'
            .       '<Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="4">'
            .         '<ScrollViewer VerticalScrollBarVisibility="Auto" CanContentScroll="False">'
            .           '<ItemsPresenter/>'
            .         '</ScrollViewer>'
            .       '</Border>'
            .     '</ControlTemplate>'
            .   '</Setter.Value></Setter>'
            . '</Style>'
    }

    ; 右键菜单打开前：根据当前选中状态更新菜单项的可用性
    _UpdateMenuState() {
        if (this.ui == "" || this.graph == "")
            return
        g := this.graph
        isBlank := this._IsRightClickOnBlank()
        ; 右键空白处时自动取消选中（含"选中节点后再右键空白处"场景）
        if (isBlank) {
            g.selectedNodes.Clear()
            for n in g.nodes
                this.ui.Update("Node_" n.Id, "BorderBrush", "{DynamicResource ControlBorder}")
            for conn in g.connections {
                if (conn.Selected) {
                    conn.Selected := false
                    this.ui.Update(conn.PathId, "Stroke", "#60A0FF")
                }
            }
        } else {
            ; 右键命中节点：若该节点尚未在选区中，则将其设为唯一选中（标准编辑器行为），
            ; 这样"编辑/复制/删除"可直接作用于右键的节点（无需先左键选中）
            hitId := this._NodeIdAtRightClick()
            if (hitId != "" && !g.selectedNodes.Has(hitId)) {
                g.selectedNodes.Clear()
                for n in g.nodes
                    this.ui.Update("Node_" n.Id, "BorderBrush", "{DynamicResource ControlBorder}")
                for conn in g.connections {
                    if (conn.Selected) {
                        conn.Selected := false
                        this.ui.Update(conn.PathId, "Stroke", "#60A0FF")
                    }
                }
                g.selectedNodes[hitId] := true
                this.ui.Update("Node_" hitId, "BorderBrush", "#60A0FF")
            }
        }
        hasSelection := g.selectedNodes.Count > 0
        hasSingleSelection := g.selectedNodes.Count == 1
        hasConnection := false
        for conn in g.connections {
            if (conn.Selected) {
                hasConnection := true
                break
            }
        }
        hasClipboard := this.HasOwnProp("_clipboard") && this._clipboard && this._clipboard.nodes && this._clipboard.nodes.Length > 0

        ; 编辑：仅选中单个节点时可交互
        this.ui.Update("MG_Edit", "IsEnabled", hasSingleSelection ? "True" : "False")
        ; 复制：选中节点或连线时可交互
        this.ui.Update("MG_Copy", "IsEnabled", (hasSelection || hasConnection) ? "True" : "False")
        ; 粘贴：有剪贴板且未选中节点/连线时可交互
        this.ui.Update("MG_Paste", "IsEnabled", (hasClipboard && !hasSelection && !hasConnection) ? "True" : "False")
        ; 删除：选中节点或连线时可交互
        this.ui.Update("MG_Delete", "IsEnabled", (hasSelection || hasConnection) ? "True" : "False")

        ; 新增指令：仅在右键空白处时可用；右键命中节点时禁用
        this.ui.Update("MG_AddRoot", "IsEnabled", isBlank ? "True" : "False")

        ; 右键空白处或连线拖放时：自动展开"新增指令"子菜单；右键命中节点时收起
        forceOpen := this.HasOwnProp("_forceOpenSubmenu") && this._forceOpenSubmenu
        this._forceOpenSubmenu := false  ; 重置标记
        this.ui.Update("MG_AddRoot", "IsSubmenuOpen", (forceOpen || isBlank) ? "True" : "False")
    }

    ; 依据最近一次右键坐标判断是否点在空白处（未命中任何节点矩形）
    _IsRightClickOnBlank() {
        g := this.graph
        if (g == "" || !g.HasProp("lastRightClickX"))
            return true
        rx := g.lastRightClickX, ry := g.lastRightClickY
        for n in g.nodes {
            if (rx >= n.X && rx <= n.X + n.W && ry >= n.Y && ry <= n.Y + n.H)
                return false
        }
        return true
    }

    ; 返回最近一次右键坐标命中的节点 Id（命中多个时取最后一个，即最上层）；未命中返回 ""
    _NodeIdAtRightClick() {
        g := this.graph
        if (g == "" || !g.HasProp("lastRightClickX"))
            return ""
        rx := g.lastRightClickX, ry := g.lastRightClickY
        hitId := ""
        for n in g.nodes {
            if (rx >= n.X && rx <= n.X + n.W && ry >= n.Y && ry <= n.Y + n.H)
                hitId := n.Id
        }
        return hitId
    }

    OnAddCmd(cmdName, *) {
        if (this.ui == "" || !this.ui.wpfHwnd || this.graph == "")
            return
        ; 在右键位置运行时注入完整内联节点（不重建窗口，避免闪烁）；不自动连线
        this._CaptureLinks()
        this._SyncPositionsFromGraph()
        id := this._NewId()
        node := this._DefaultObj(cmdName)
        this.cmdNodes[id] := node
        this.order.Push(id)
        ox := this.graph.HasProp("lastRightClickX") ? this.graph.lastRightClickX - this.graph.offsetX : 200
        oy := this.graph.HasProp("lastRightClickY") ? this.graph.lastRightClickY - this.graph.offsetY : 200
        this.pos[id] := { x: ox, y: oy }

        ; 取出本次（若有）的待连线源端口
        pendingFrom := (this.HasOwnProp("_pendingConnectionFrom") && this._pendingConnectionFrom != "") ? this._pendingConnectionFrom : ""
        this._pendingConnectionFrom := ""
        fromIsBranch := this._IsBranchId(pendingFrom)
        logicalFrom := this._LogicalNodeId(pendingFrom)

        ; ---- 统一走运行时注入（不重建窗口，避免闪烁；亦修复添加搜索后无法继续添加节点的问题）----
        this._InjectFullNode(id, node)
        ; 搜索节点：强制绑定真/假分支节点（新建默认展开）
        if (this._IsExpandedSearch(id))
            this._InjectBranchPair(id)
        ; 由出点拖拽触发的添加：自动连线（源可能是分支节点；展开搜索的直连会被规范化为双分支）
        if (pendingFrom != "" && pendingFrom != id) {
            srcOk := fromIsBranch ? this._branchInjected.Has(logicalFrom) : this._NodeExists(pendingFrom)
            if (srcOk) {
                this._ActivateConnection(pendingFrom, id)
                this._NormalizeBranchConnections()
            }
        }
        this._ThickenConnections()
        this._RebindPathClicks()
        this._Apply()
    }

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
            ; 丢弃「搜索 → 分支节点」的强制连线（显示用，逻辑上不是真正后继）
            if (this._IsBranchId(to))
                continue
            ; 「分支 → X」翻译回「搜索 → X」（分支出点即搜索的后继出点）
            bi := this._BranchInfo(from)
            if (bi != "")
                from := bi.searchId
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

    _DefaultObj(cmdName) {
        if (cmdName == GetLang("间隔"))
            return this._MakeNode(GetLang("间隔") "_500")
        if (cmdName == GetLang("按键"))
            return this._MakeNode(GetLang("按键") "_a_" GetLang("点击") "_100")
        if (cmdName == GetLang("移动"))
            return this._MakeNode(GetLang("移动") "_0_0_90")
        if (cmdName == GetLang("移动Pro")) {
            ; 移动Pro 走 INI 持久化（参数存 MMProFile.ini，CurCMD 仅为序列码引用，与执行引擎一致）
            serial := GetCMDSerialStr("移动Pro")
            data := MMProData()
            data.SerialStr := serial
            SaveMacroCMDData(data)
            return this._MakeNode(serial)
        }
        if (cmdName == GetLang("搜索") || cmdName == GetLang("搜索Pro")) {
            ; 搜索/搜索Pro 走 INI 持久化（参数存 SearchFile.ini，CurCMD 仅为序列码引用，与执行引擎一致）
            serial := GetCMDSerialStr(cmdName == GetLang("搜索Pro") ? "搜索Pro" : "搜索")
            data := SearchData()
            data.SerialStr := serial
            SaveMacroCMDData(data)
            return this._MakeNode(serial)
        }
        ; 其它指令：临时节点占位（仍只存 CurCMD，类型由解析判定）
        return this._MakeNode(cmdName)
    }

    ; ----------------------------------------------------------------- 内联编辑回调

    _OnKeyType(id, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        key := "TypeCmb_" id
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (state.Has(key) && state[key] != "")
            d.ktype := state[key]
        this.cmdNodes[id].CurCMD := this._BuildCmd(d)
        this._RefreshKeyVisibility(id)
        this._Apply()
    }

    ; 间隔类型下拉变更：固定/随机；切换时保留当前已填的时间值，并切换第二时间行显隐
    _OnIntervalType(id, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        key := "ITypeCmb_" id
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (state.Has("Time_" id) && state["Time_" id] != "")
            d.time := state["Time_" id]
        if (state.Has("Time2_" id) && state["Time2_" id] != "")
            d.time2 := state["Time2_" id]
        if (state.Has(key) && state[key] != "")
            d.itype := this._IntervalTypeFromText(state[key])
        this.cmdNodes[id].CurCMD := this._BuildCmd(d)
        this._RefreshIntervalVisibility(id)
        this._Apply()
    }

    ; 随机模式显示第二时间行，固定模式隐藏
    _RefreshIntervalVisibility(id) {
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (d.type != GetLang("间隔") || this.ui == "")
            return
        isRandom := d.itype == GetLang("随机")
        this.ui.Update("Time2Row_" id, "Visibility", isRandom ? "Visible" : "Collapsed")
    }

    ; 间隔类型 -> 下拉项索引
    _IntervalTypeIndex(itype) {
        return (itype == GetLang("随机")) ? 1 : 0
    }

    ; 下拉项文本 -> 间隔类型（与显示项使用同一 GetLang，确保中英文一致匹配）
    _IntervalTypeFromText(text) {
        return (text == GetLang("随机")) ? GetLang("随机") : GetLang("固定")
    }

    ; 移动方式下拉变更：映射为模式编号(0/1/2)；游戏视角(2)强制速度100
    _OnMoveMode(id, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        key := "ModeCmb_" id
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (state.Has(key) && state[key] != "")
            d.mode := this._MoveModeFromText(state[key])
        if (d.mode == "2")
            d.speed := "100"
        this.cmdNodes[id].CurCMD := this._BuildCmd(d)
        this._RefreshMoveVisibility(id)
        this._Apply()
    }

    ; 游戏视角模式下速度固定100且禁用编辑；其余模式恢复可编辑
    _RefreshMoveVisibility(id) {
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (d.type != GetLang("移动") || this.ui == "")
            return
        isGameView := (d.mode == "2" || d.mode == 2)
        if (isGameView) {
            this.ui.Update("Speed_" id, "Text", "100")
            this.ui.Update("Speed_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("Speed_" id, "IsEnabled", "True")
        }
    }

    ; 模式编号 -> 下拉项索引
    _MoveModeIndex(mode) {
        if (mode == "1" || mode == 1)
            return 1
        if (mode == "2" || mode == 2)
            return 2
        return 0
    }

    ; 下拉项文本 -> 模式编号（与显示项使用同一 GetLang，确保中英文一致匹配）
    _MoveModeFromText(text) {
        if (text == GetLang("相对移动"))
            return "1"
        if (text == GetLang("游戏视角"))
            return "2"
        return "0"
    }

    ; ----------------------------------------------------------------- 移动Pro

    ; 判断某 CurCMD 首段是否为「移动Pro」序列码（去掉结尾数字后等于「移动Pro」）
    _IsMMProName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("移动Pro")
    }

    ; 搜索序列码判定（如 "搜索1"）：去掉结尾数字后与「搜索」完全匹配
    _IsSearchName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("搜索")
    }

    ; 搜索Pro序列码判定（如 "搜索Pro2"）：去掉结尾数字后与「搜索Pro」完全匹配
    _IsSearchProName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("搜索Pro")
    }

    ; 鼠标动作编号(1/2/3) -> 下拉项索引
    _MMProActionIndex(at) {
        if (at == "2" || at == 2)
            return 1
        if (at == "3" || at == 3)
            return 2
        return 0
    }

    ; 下拉项文本 -> 鼠标动作编号(1=移动 2=移动点击1次 3=移动点击2次)
    _MMProActionFromText(text) {
        if (text == GetLang("移动点击1次"))
            return 2
        if (text == GetLang("移动点击2次"))
            return 3
        return 1
    }

    ; 取 X/Y 坐标变量的显示文本（存储为 Key 形式，显示用 GetLang；数字原样返回）
    _MMProVarText(d, prop) {
        if (!d.HasOwnProp(prop))
            return "100"
        v := d.%prop%
        return (v == "") ? "" : GetLang(v)
    }

    ; 读取节点对应的 MMProData（CurCMD 首段即其 SerialStr，可能带 "_备注" 后缀，需取首段）
    _MMProData(id) {
        if (!this.cmdNodes.Has(id))
            return ""
        arr := SplitCommand(this.cmdNodes[id].CurCMD)
        serial := arr.Length >= 1 ? arr[1] : this.cmdNodes[id].CurCMD
        try {
            data := GetMacroCMDData(serial)
            return IsObject(data) ? data : ""
        }
        return ""
    }

    ; X/Y 坐标(可编辑下拉) 与 速度(文本框) 变更：写回 MMProFile.ini
    _OnMMProField(id, field, state, ctrl, event) {
        data := this._MMProData(id)
        if (data == "")
            return
        nameMap := Map("PosVarX", "MPPosX_", "PosVarY", "MPPosY_", "Speed", "MPSpeed_", "Count", "MPCount_", "Interval", "MPInterval_")
        key := nameMap[field] id
        if (state.Has(key)) {
            val := state[key]
            if (field == "Speed" || field == "Count" || field == "Interval") {
                ; 数值字段（速度/移动次数/每次间隔）：忽略空值，最小为 1
                if (val == "")
                    return
                if (IsNumber(val) && val + 0 < 1)
                    val := "1"
                data.%field% := val
            }
            else {
                ; 坐标支持「下拉变量名」或「手输数值」：统一以 Key 形式存储
                ; 忽略下拉初始化阶段的空值，避免覆盖已有坐标
                if (val == "")
                    return
                data.%field% := GetLangKey(val)
            }
            SaveMacroCMDData(data)
        }
        this._MMProApply()
    }

    ; 鼠标动作下拉变更
    _OnMMProAction(id, state, ctrl, event) {
        data := this._MMProData(id)
        if (data == "")
            return
        key := "MPActionCmb_" id
        if (state.Has(key) && state[key] != "")
            data.ActionType := this._MMProActionFromText(state[key])
        SaveMacroCMDData(data)
        this._MMProApply()
    }

    ; 移动方式下拉变更：游戏视角时动作固定移动、速度100、关闭拟真轨迹，并显示移动次数/每次间隔
    _OnMMProMode(id, state, ctrl, event) {
        data := this._MMProData(id)
        if (data == "")
            return
        key := "MPModeCmb_" id
        if (state.Has(key) && state[key] != "")
            data.MouseMoveMode := Integer(this._MoveModeFromText(state[key]))
        if (data.MouseMoveMode == 2) {
            data.ActionType := 1
            data.Speed := 100
            data.IsHumanMouse := 0
        }
        SaveMacroCMDData(data)
        this._RefreshMMProVisibility(id)
        this._MMProApply()
    }

    ; 启用拟真轨迹勾选：勾选后强制动作=移动并禁用动作/方式下拉（与 MMProGui 一致）；若处于游戏视角则切回相对移动
    _OnMMProHuman(id, state, ctrl, event) {
        data := this._MMProData(id)
        if (data == "")
            return
        key := "MPHuman_" id
        if (state.Has(key)) {
            v := state[key]
            data.IsHumanMouse := (v == "True" || v == 1 || v == "1") ? 1 : 0
            if (data.IsHumanMouse == 1) {
                ; 拟真轨迹与游戏视角互斥：游戏视角时切回相对移动
                if (data.MouseMoveMode == 2) {
                    data.MouseMoveMode := 1
                    this.ui.Update("MPModeCmb_" id, "SelectedIndex", this._MoveModeIndex(1))
                }
                data.ActionType := 1
            }
            SaveMacroCMDData(data)
        }
        this._RefreshMMProVisibility(id)
        this._MMProApply()
    }

    ; 依据 游戏视角 / 拟真轨迹 状态联动刷新各控件的可用性与可见性（与 MMProGui.OnTypeChange / OnHumanMouseTogClick 一致）
    _RefreshMMProVisibility(id) {
        if (this.ui == "")
            return
        data := this._MMProData(id)
        if (data == "")
            return
        isGameView := (data.MouseMoveMode == 2 || data.MouseMoveMode == "2")
        isHuman := (ObjHasOwnProp(data, "IsHumanMouse") && (data.IsHumanMouse == 1 || data.IsHumanMouse == "1"))

        ; 移动速度：游戏视角固定 100 且禁用
        if (isGameView) {
            this.ui.Update("MPSpeed_" id, "Text", "100")
            this.ui.Update("MPSpeed_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("MPSpeed_" id, "IsEnabled", "True")
        }

        ; 鼠标动作：游戏视角或拟真轨迹下强制「移动」且禁用
        if (isGameView || isHuman) {
            this.ui.Update("MPActionCmb_" id, "SelectedIndex", 0)
            this.ui.Update("MPActionCmb_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("MPActionCmb_" id, "IsEnabled", "True")
        }

        ; 移动方式：拟真轨迹开启时禁用
        this.ui.Update("MPModeCmb_" id, "IsEnabled", isHuman ? "False" : "True")

        ; 拟真轨迹：游戏视角下取消勾选并禁用
        if (isGameView) {
            this.ui.Update("MPHuman_" id, "IsChecked", "False")
            this.ui.Update("MPHuman_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("MPHuman_" id, "IsEnabled", "True")
        }

        ; 移动次数 / 每次间隔：仅游戏视角显示
        this.ui.Update("MPCountRow_" id, "Visibility", isGameView ? "Visible" : "Collapsed")
        this.ui.Update("MPIntervalRow_" id, "Visibility", isGameView ? "Visible" : "Collapsed")
    }

    _MMProApply() {
        this._CaptureLinks()
        this._Apply()
    }

    ; ----------------------------------------------------------------- 搜索节点内联编辑

    ; 读取节点对应的 SearchData（CurCMD 首段即其 SerialStr，可能带 "_备注" 后缀，取首段）
    _SearchData(id) {
        if (!this.cmdNodes.Has(id))
            return ""
        arr := SplitCommand(this.cmdNodes[id].CurCMD)
        serial := arr.Length >= 1 ? arr[1] : this.cmdNodes[id].CurCMD
        try {
            data := GetMacroCMDData(serial)
            return IsObject(data) ? data : ""
        }
        return ""
    }

    ; 下拉文本 -> 搜索类型编号（1屏幕图片 2屏幕颜色 3屏幕文本 4窗口图片 5窗口颜色 6窗口文本）
    _SearchTypeFromText(text) {
        if (text == GetLang("屏幕颜色"))
            return 2
        if (text == GetLang("屏幕文本"))
            return 3
        if (text == GetLang("窗口图片"))
            return 4
        if (text == GetLang("窗口颜色"))
            return 5
        if (text == GetLang("窗口文本"))
            return 6
        return 1
    }

    ; 下拉文本 -> 鼠标动作编号（搜索：1无动作 2移动至目标 3移动点击1次 4移动点击2次；搜索Pro：1无动作 2移动至目标 3移动至目标点击）
    _SearchActionFromText(text) {
        if (text == GetLang("移动至目标"))
            return 2
        if (text == GetLang("移动至目标点击1次"))
            return 3
        if (text == GetLang("移动至目标点击2次"))
            return 4
        if (text == GetLang("移动至目标点击"))
            return 3
        return 1
    }

    ; 节点是否为 搜索Pro
    _IsNodePro(id) {
        if (!this.cmdNodes.Has(id))
            return false
        arr := SplitCommand(this.cmdNodes[id].CurCMD)
        serial := arr.Length >= 1 ? arr[1] : this.cmdNodes[id].CurCMD
        return this._IsSearchProName(serial)
    }

    ; 搜索类型分类（同时适配 搜索 1-3 与 搜索Pro 1-6）
    _SearchTypeClass(st) {
        return { isImage: (st == 1 || st == 4), isColor: (st == 2 || st == 5), isText: (st == 3 || st == 6), isWin: (st >= 4) }
    }

    ; 搜索类型变更：写回数据并切换类型相关行的显隐
    _OnSearchType(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "STypeCmb_" id
        if (state.Has(key) && state[key] != "")
            data.SearchType := this._SearchTypeFromText(state[key])
        SaveMacroCMDData(data)
        this._RefreshSearchVisibility(id)
        this._Apply()
    }

    ; 按搜索类型切换 颜色/文本/图片+相似度 行的显隐（兼容 搜索 与 搜索Pro）
    _RefreshSearchVisibility(id) {
        data := this._SearchData(id)
        if (data == "" || this.ui == "")
            return
        st := data.SearchType
        c := this._SearchTypeClass(st)
        this.ui.Update("SColorRow_" id, "Visibility", c.isColor ? "Visible" : "Collapsed")
        this.ui.Update("STextRow_" id, "Visibility", c.isText ? "Visible" : "Collapsed")
        this.ui.Update("SImgRow_" id, "Visibility", c.isImage ? "Visible" : "Collapsed")
        this.ui.Update("SSimRow_" id, "Visibility", c.isImage ? "Visible" : "Collapsed")
        ; 操作按钮按类型显隐
        this.ui.Update("SShot_" id, "Visibility", c.isImage ? "Visible" : "Collapsed")
        this.ui.Update("SPic_" id, "Visibility", c.isImage ? "Visible" : "Collapsed")
        this.ui.Update("SPick_" id, "Visibility", c.isColor ? "Visible" : "Collapsed")
        ; 搜索Pro 专属行显隐
        if (this._IsNodePro(id)) {
            this.ui.Update("SWinRow_" id, "Visibility", c.isWin ? "Visible" : "Collapsed")
            cnt := data.SearchCount
            isCount := (cnt == -1 || (IsNumber(cnt) && cnt + 0 > 1))
            this.ui.Update("SIntervalRow_" id, "Visibility", isCount ? "Visible" : "Collapsed")
            act := data.MouseActionType
            this.ui.Update("SSpeedRow_" id, "Visibility", (act != 1 && !c.isWin) ? "Visible" : "Collapsed")
            this.ui.Update("SClickRow_" id, "Visibility", (act == 3 && !c.isWin) ? "Visible" : "Collapsed")
            ; 结果保存 / 目标点保存：开关控制内部字段显隐
            this.ui.Update("SResFields_" id, "Visibility", (data.ResultToggle == 1 || data.ResultToggle == "1") ? "Visible" : "Collapsed")
            this.ui.Update("SCoordFields_" id, "Visibility", (data.CoordToogle == 1 || data.CoordToogle == "1") ? "Visible" : "Collapsed")
        }
        ; 标题预览（缩略图/色块）
        this._RefreshSearchTitlePreview(id)
    }

    ; 刷新预览：标题栏色块（颜色搜索）+ 浮动大图预览（图片搜索），其余隐藏
    _RefreshSearchTitlePreview(id) {
        data := this._SearchData(id)
        if (data == "" || this.ui == "")
            return
        st := data.SearchType
        c := this._SearchTypeClass(st)
        imgPath := data.HasOwnProp("SearchImagePath") ? data.SearchImagePath : ""
        color := data.HasOwnProp("SearchColor") ? data.SearchColor : "FFFFFF"
        ; 颜色搜索：标题栏色块
        showColor := (c.isColor && RegExMatch(color, "^[0-9A-Fa-f]{6}$"))
        this.ui.Update("STitleColor_" id, "Visibility", showColor ? "Visible" : "Collapsed")
        if (showColor)
            this.ui.Update("STitleColor_" id, "Background", "#" color)
        ; 图片搜索：主体大图预览
        showImg := (c.isImage && imgPath != "" && FileExist(imgPath))
        this.ui.Update("SImgPrevRow_" id, "Visibility", showImg ? "Visible" : "Collapsed")
        if (showImg)
            this.ui.Update("SImgPrev_" id, "Source", StrReplace(imgPath, "\", "/"))
    }

    ; 搜索字段（颜色/文本/相似度/起止坐标）变更：写回 SearchData
    _OnSearchField(id, field, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        nameMap := Map("SearchColor", "SColor_", "SearchText", "SText_", "Similar", "SSim_"
            , "StartPosX", "SStartX_", "StartPosY", "SStartY_", "EndPosX", "SEndX_", "EndPosY", "SEndY_")
        key := nameMap[field] id
        if (state.Has(key)) {
            val := state[key]
            if (field == "SearchText") {
                data.SearchText := val
            }
            else if (field == "SearchColor") {
                data.SearchColor := val
            }
            else if (field == "Similar") {
                ; 相似度：限制 1~100，手动输入超界时夹紧并回写输入框
                if (val == "" || !IsNumber(val))
                    return
                v := val + 0
                if (v < 1)
                    v := 1
                else if (v > 100)
                    v := 100
                if (v != val + 0)
                    this.ui.Update("SSim_" id, "Text", v)
                data.Similar := v
            }
            else {
                ; 坐标字段：搜索Pro 允许变量名（原样存）；普通搜索仅接受数值
                isCoord := (field == "StartPosX" || field == "StartPosY" || field == "EndPosX" || field == "EndPosY")
                if (isCoord && this._IsNodePro(id)) {
                    if (val == "")
                        return
                    data.%field% := val
                }
                else {
                    if (val == "" || !IsNumber(val))
                        return
                    data.%field% := val + 0
                }
            }
            SaveMacroCMDData(data)
        }
        this._Apply()
    }

    ; 鼠标动作变更：写回 SearchData
    _OnSearchAction(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SActCmb_" id
        if (state.Has(key) && state[key] != "")
            data.MouseActionType := this._SearchActionFromText(state[key])
        SaveMacroCMDData(data)
        ; 搜索Pro：动作变更联动 移动速度/点击次数 的显隐
        this._RefreshSearchVisibility(id)
        this._Apply()
    }

    ; 搜索Pro 数值/文本字段（窗口信息/间隔/点击次数/速度/结果变量/真假值/坐标变量名）写回
    _OnSearchProField(id, field, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        nameMap := Map("WinInfo", "SWin_", "SearchInterval", "SInterval_", "ClickCount", "SClick_"
            , "Speed", "SSpeed_", "ResultSaveName", "SResName_", "TrueValue", "SResTrue_", "FalseValue", "SResFalse_"
            , "CoordXName", "SCoordX_", "CoordYName", "SCoordY_")
        if (!nameMap.Has(field))
            return
        key := nameMap[field] id
        if (!state.Has(key))
            return
        val := state[key]
        if (field == "WinInfo") {
            data.WinInfo := val
        }
        else if (field == "ResultSaveName") {
            if (val == "")
                return
            data.ResultSaveName := GetVarName(val)
            if (data.ResultToggle == 1 || data.ResultToggle == "1")
                MySoftData.GlobalVariMap[data.ResultSaveName] := true
        }
        else if (field == "CoordXName" || field == "CoordYName") {
            if (val == "")
                return
            data.%field% := val
            if (data.CoordToogle == 1 || data.CoordToogle == "1")
                MySoftData.GlobalVariMap[val] := true
        }
        else if (field == "TrueValue" || field == "FalseValue") {
            data.%field% := val
        }
        else {
            ; 数值字段（间隔/点击次数/速度）：忽略空值，最小为 1
            if (val == "")
                return
            if (IsNumber(val) && val + 0 < 1)
                val := 1
            data.%field% := val
        }
        SaveMacroCMDData(data)
        this._Apply()
    }

    ; 搜索次数变更：支持「无限」或数值；联动 每次间隔 显隐
    _OnSearchCount(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SCount_" id
        if (state.Has(key)) {
            val := state[key]
            if (val == GetLang("无限"))
                data.SearchCount := -1
            else if (val != "" && IsNumber(val) && val + 0 >= 1)
                data.SearchCount := val + 0
            SaveMacroCMDData(data)
        }
        this._RefreshSearchVisibility(id)
        this._Apply()
    }

    ; 结果保存开关：写回并显隐内部字段
    _OnSearchResultToggle(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SResTog_" id
        if (state.Has(key)) {
            v := state[key]
            data.ResultToggle := (v == "True" || v == 1 || v == "1") ? 1 : 0
            if (data.ResultToggle == 1 && data.ResultSaveName != "")
                MySoftData.GlobalVariMap[data.ResultSaveName] := true
            SaveMacroCMDData(data)
        }
        this._RefreshSearchVisibility(id)
        this._Apply()
    }

    ; 目标点保存开关：写回并显隐内部字段
    _OnSearchCoordToggle(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SCoordTog_" id
        if (state.Has(key)) {
            v := state[key]
            data.CoordToogle := (v == "True" || v == 1 || v == "1") ? 1 : 0
            if (data.CoordToogle == 1) {
                if (data.CoordXName != "")
                    MySoftData.GlobalVariMap[data.CoordXName] := true
                if (data.CoordYName != "")
                    MySoftData.GlobalVariMap[data.CoordYName] := true
            }
            SaveMacroCMDData(data)
        }
        this._RefreshSearchVisibility(id)
        this._Apply()
    }

    ; 高级编辑：打开完整搜索编辑器（双击节点也可打开）
    _OnSearchAdv(id, *) {
        this.OpenNodeEditor(id)
    }

    ; 刷新搜索节点全部内联显示（操作改动数据后调用）并回写
    _RefreshSearchInline(id) {
        if (!this.cmdNodes.Has(id))
            return
        this._RefreshSearchNode(id, this._Parse(this.cmdNodes[id].CurCMD))
        this._Apply()
    }

    ; 截图（图片搜索）：按软件截图方式设置图片与搜索范围，与搜索编辑器行为一致
    _OnSearchShot(id, *) {
        this._shotNodeId := id
        if (MySoftData.ScreenShotTypeCtrl.Value == 1) {
            SetClipboard("")
            Run("ms-screenclip:")
            SetTimer(this._searchClipAction, 500)
            TogGetSelectArea(true, this._OnSearchShotArea.Bind(this, id))
        }
        else if (MySoftData.ScreenShotTypeCtrl.Value == 3) {
            RunScreenCapture(this._searchClipAction)
            TogGetSelectArea(true, this._OnSearchShotArea.Bind(this, id))
        }
        else {
            TogSelectArea(true, this._OnSearchScreenShotArea.Bind(this, id))
        }
    }

    ; 剪贴板截图回调（截图方式 1/3）：保存剪贴板位图为搜索图片
    _SearchCheckClipboard(*) {
        if !DllCall("IsClipboardFormatAvailable", "uint", 8)
            return
        imageSerial := GetNextImageSerial()
        filePath := A_WorkingDir "\Setting\" MySoftData.CurSettingName "\Images\ScreenShot\" imageSerial ".png"
        SaveClipToBitmap(filePath)
        id := this._shotNodeId
        if (id != "" && this.cmdNodes.Has(id)) {
            data := this._SearchData(id)
            if (data != "") {
                data.SearchImagePath := filePath
                SaveMacroCMDData(data)
                this._RefreshSearchInline(id)
            }
        }
        SetTimer(, 0)
    }

    ; 截图方式 1/3：框选只设置搜索范围（图片来自剪贴板），范围外扩 20px
    _OnSearchShotArea(id, x1, y1, x2, y2) {
        this._SetSearchArea(id, Max(0, x1 - 20), Max(0, y1 - 20), Min(A_ScreenWidth, x2 + 20), Min(A_ScreenHeight, y2 + 20))
    }

    ; 截图方式（其它）：框选区域即时截图为搜索图片，并设搜索范围
    _OnSearchScreenShotArea(id, x1, y1, x2, y2) {
        imageSerial := GetNextImageSerial()
        filePath := A_WorkingDir "\Setting\" MySoftData.CurSettingName "\Images\ScreenShot\" imageSerial ".png"
        ScreenShot(x1, y1, x2, y2, filePath)
        data := this._SearchData(id)
        if (data == "")
            return
        data.SearchImagePath := filePath
        data.StartPosX := Max(0, x1 - 20)
        data.StartPosY := Max(0, y1 - 20)
        data.EndPosX := Min(A_ScreenWidth, x2 + 20)
        data.EndPosY := Min(A_ScreenHeight, y2 + 20)
        SaveMacroCMDData(data)
        this._RefreshSearchInline(id)
    }

    ; 选择图片（图片搜索）
    _OnSearchPic(id, *) {
        data := this._SearchData(id)
        if (data == "")
            return
        path := FileSelect(1, data.SearchImagePath, GetLang("选择图片"), "PNG Files (*.png)")
        if (path == "")
            return
        data.SearchImagePath := path
        SaveMacroCMDData(data)
        this._RefreshSearchInline(id)
    }

    ; 定位取色器（颜色搜索）：仅设置搜索颜色，搜索范围由「框选范围」单独设置
    _OnSearchPick(id, *) {
        this._shotNodeId := id
        MyTargetGui.SureAction := this._OnSearchPickSure.Bind(this, id)
        MyTargetGui.ShowGui()
    }

    _OnSearchPickSure(id, posX, posY, color) {
        data := this._SearchData(id)
        if (data == "")
            return
        data.SearchColor := StrReplace(color, "0x", "")
        SaveMacroCMDData(data)
        this._RefreshSearchInline(id)
    }

    ; 框选范围（所有类型通用）：拖拽框选设置起止坐标
    _OnSearchArea(id, *) {
        TogSelectArea(true, this._OnSearchAreaGot.Bind(this, id))
    }

    _OnSearchAreaGot(id, x1, y1, x2, y2) {
        this._SetSearchArea(id, x1, y1, x2, y2)
    }

    ; 写入搜索范围并刷新
    _SetSearchArea(id, x1, y1, x2, y2) {
        data := this._SearchData(id)
        if (data == "")
            return
        data.StartPosX := x1
        data.StartPosY := y1
        data.EndPosX := x2
        data.EndPosY := y2
        SaveMacroCMDData(data)
        this._RefreshSearchInline(id)
    }

    ; 切换搜索节点折叠态：折叠隐藏真/假分支节点（搜索直连后续），展开则显示分支节点。
    ; 运行时显隐 + 连线启停，避免整窗重建闪烁。
    _OnToggleFold(id, *) {
        if (!this.cmdNodes.Has(id))
            return
        node := this.cmdNodes[id]
        willFold := this._NodeFolded(id) ? 0 : 1
        node.Folded := willFold
        SaveMacroCMDData(node)
        if (willFold)
            this._FoldSearchRuntime(id)
        else
            this._UnfoldSearchRuntime(id)
        ; 标题按钮图标：折叠→▶（点击展开），展开→▼（点击收起）
        this.ui.Update("SFold_" id, "Content", willFold ? "▶" : "▼")
        this.ui.Update("SFold_" id, "ToolTip", willFold ? GetLang("展开") : GetLang("收起"))
        this._CaptureLinks()
    }

    ; 折叠：隐藏分支节点与分支相关连线，搜索直连原后续
    _FoldSearchRuntime(searchId) {
        g := this.graph
        if (g == "")
            return
        this._CaptureLinks()                 ; 先取得当前逻辑后继
        succ := this._SuccessorsOf(searchId)
        for conn in g.connections {
            if (this._ConnInvolvesSearchBranch(conn, searchId))
                this._DeactivateConnection(conn)
        }
        for isTrue in [true, false]
            this.ui.Update("Node_" this._BranchId(searchId, isTrue), "Visibility", "Collapsed")
        for x in succ
            this._ActivateConnection(searchId, x)
        ; 收起：把展开时为腾出分支空间而右移的后继子树还原（向左偏移）
        this._SpreadForCollapse(searchId)
        this._RebindPathClicks()
    }

    ; 展开：显示（或首次注入）分支节点，搜索改连分支、分支连原后续
    _UnfoldSearchRuntime(searchId) {
        g := this.graph
        if (g == "")
            return
        this._CaptureLinks()
        succ := this._SuccessorsOf(searchId)
        ; 停用「搜索 → 非分支后续」直连
        for conn in g.connections {
            if (conn.From == searchId && !this._IsBranchId(conn.To))
                this._DeactivateConnection(conn)
        }
        ; 分支节点：首次展开则注入，否则显隐
        if (!this._branchInjected.Has(searchId)) {
            this._InjectBranchPair(searchId)
        } else {
            for isTrue in [true, false]
                this.ui.Update("Node_" this._BranchId(searchId, isTrue), "Visibility", "Visible")
            this._ActivateConnection(searchId, this._BranchId(searchId, true))
            this._ActivateConnection(searchId, this._BranchId(searchId, false))
        }
        ; 分支 → 各后续
        for x in succ {
            this._ActivateConnection(this._BranchId(searchId, true), x)
            this._ActivateConnection(this._BranchId(searchId, false), x)
        }
        ; 展开：若后继离搜索过近，把整条后继子树右移腾出分支显示空间
        this._SpreadForExpand(searchId)
        this._RebindPathClicks()
    }

    ; 取某节点当前的逻辑后继（基于 this.links）
    _SuccessorsOf(id) {
        out := []
        for link in this.links {
            if (link.from == id && this._NodeExists(link.to))
                out.Push(link.to)
        }
        return out
    }

    ; 分支节点单击：用计时判定双击 → 打开嵌套节点编辑器编辑该分支子图
    _OnBranchClick(searchId, isTrue, *) {
        now := A_TickCount
        bkey := "BR_" searchId (isTrue ? "T" : "F")
        if (this._lastClickId == bkey && now - this._lastClickTime < 400) {
            this._lastClickId := ""
            this._lastClickTime := 0
            this._OpenBranchEditor(searchId, isTrue)
        } else {
            this._lastClickId := bkey
            this._lastClickTime := now
        }
    }

    ; 分支节点「展开/收起」按钮：在前 6 条与全部指令之间切换。
    ; 运行时仅切换裁剪容器限高与按钮文字，避免整窗重建闪烁。
    _OnBranchToggleExpand(searchId, isTrue, *) {
        brId := this._BranchId(searchId, isTrue)
        nv := !(this._branchExpanded.Has(brId) && this._branchExpanded[brId])
        this._branchExpanded[brId] := nv
        cmds := this._BranchGraphCmds(this._BranchStartSerial(searchId, isTrue))
        this._RebuildBranchChips(brId, cmds, nv)
        this.ui.Update("SBExpand_" brId, "Content", nv ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
    }

    ; 打开嵌套「节点编辑器」编辑分支子图；分支内容以「图形开始节点序列码」存于 TrueMacro/FalseMacro
    _OpenBranchEditor(searchId, isTrue) {
        data := this._SearchData(searchId)
        if (data == "")
            return
        if (this.BranchGraphGui == "")
            this.BranchGraphGui := MacroGraphGui()
        cur := isTrue ? (ObjHasOwnProp(data, "TrueMacro") ? data.TrueMacro : "") : (ObjHasOwnProp(data, "FalseMacro") ? data.FalseMacro : "")
        this.BranchGraphGui.OwnerHwnd := (this.ui != "" && this.ui.wpfHwnd) ? this.ui.wpfHwnd : ""
        this.BranchGraphGui.SureBtnAction := (startSerial) => this._OnBranchEditorSure(searchId, isTrue, startSerial)
        ; 嵌套编辑器关闭后：就地刷新该分支节点的指令清单（不重建父窗口，避免闪烁/重复窗口）
        this.BranchGraphGui.OnClosedAction := (*) => this._RefreshBranchBody(searchId, isTrue)
        this.BranchGraphGui.ShowGui(cur)
    }

    ; 嵌套分支编辑器回写：保存分支子图的开始节点序列码到 SearchData（不在此处重建父图，避免实时联动抖动）
    _OnBranchEditorSure(searchId, isTrue, startSerial) {
        data := this._SearchData(searchId)
        if (data == "")
            return
        if (isTrue)
            data.TrueMacro := startSerial
        else
            data.FalseMacro := startSerial
        SaveMacroCMDData(data)
    }

    ; 跟随：搜索节点拖动时，把其真/假分支节点按相对位置同步移动，并刷新相关连线
    _FollowBranchNodes(searchId) {
        g := this.graph
        if (g == "")
            return
        for isTrue in [true, false] {
            brId := this._BranchId(searchId, isTrue)
            bp := this._BranchPos(searchId, isTrue)
            this.pos[brId] := bp
            n := g.GetNode(brId)
            if (n) {
                n.X := bp.x + g.offsetX
                n.Y := bp.y + g.offsetY
                g.ui.Update("Node_" brId, "SetPosition", String(n.X) "," String(n.Y))
            }
        }
        for conn in g.connections {
            if (conn.From == searchId || this._IsBranchId(conn.From) || this._IsBranchId(conn.To))
                g.UpdatePath(conn.From, conn.To, conn.PathId)
        }
    }

    ; 展开时后继与搜索节点的最小横向间距（需越过分支节点：节点宽 + 100 偏移 + 分支宽 200 + 60 余量）
    _ExpandMinGap(searchId) {
        return this._SearchNodeWidth(searchId) + 360
    }

    ; 收起时后继与搜索节点的目标横向间距（节点宽 + 60 余量，避免与折叠后的节点重叠）
    _CollapseGap(searchId) {
        return this._SearchNodeWidth(searchId) + 60
    }

    ; 搜索节点逻辑X
    _NodeX(id) {
        return this.pos.Has(id) ? this.pos[id].x : 0
    }

    ; 直接后继中离搜索节点最近的逻辑X（无后继返回 ""）
    _NearestSuccessorX(searchId) {
        nearest := ""
        for link in this.links {
            if (link.from == searchId && this.pos.Has(link.to)) {
                sx := this.pos[link.to].x
                if (nearest == "" || sx < nearest)
                    nearest := sx
            }
        }
        return nearest
    }

    ; 收集某节点的全部后代（沿 links 传递闭包），返回 id 集合 Map
    _DescendantsOf(startId) {
        out := Map()
        queue := []
        for link in this.links {
            if (link.from == startId)
                queue.Push(link.to)
        }
        while (queue.Length) {
            cur := queue.RemoveAt(1)
            if (out.Has(cur) || cur == startId)
                continue
            out[cur] := true
            for link in this.links {
                if (link.from == cur)
                    queue.Push(link.to)
            }
        }
        return out
    }

    ; 横向平移单个节点（更新逻辑坐标、引擎坐标与界面位置）
    _ShiftNodeX(id, dx) {
        g := this.graph
        if (this.pos.Has(id))
            this.pos[id] := { x: this.pos[id].x + dx, y: this.pos[id].y }
        n := g.GetNode(id)
        if (n) {
            n.X := n.X + dx
            g.ui.Update("Node_" id, "SetPosition", String(n.X) "," String(n.Y))
        }
    }

    ; 把搜索节点的整条后继子树横向平移 dx（>0 右移 / <0 左移），子树内的展开搜索节点其分支同步跟随
    _ShiftDescendantsX(searchId, dx) {
        if (dx == 0)
            return
        g := this.graph
        if (g == "")
            return
        desc := this._DescendantsOf(searchId)
        for id in desc {
            this._ShiftNodeX(id, dx)
            if (this._IsExpandedSearch(id))
                this._FollowBranchNodes(id)
        }
        for conn in g.connections
            g.UpdatePath(conn.From, conn.To, conn.PathId)
    }

    ; 展开：后继离搜索过近则把后继子树右移，腾出分支显示空间，并记录位移用于收起还原
    _SpreadForExpand(searchId) {
        nearest := this._NearestSuccessorX(searchId)
        if (nearest == "")
            return
        gap := nearest - this._NodeX(searchId)
        need := this._ExpandMinGap(searchId)
        if (gap >= need)
            return
        dx := need - gap
        this._ShiftDescendantsX(searchId, dx)
        this._foldShift[searchId] := (this._foldShift.Has(searchId) ? this._foldShift[searchId] : 0) + dx
    }

    ; 收起：把展开时右移的后继子树左移还原；无本会话展开记录时，若后继过远则按启发式拉近
    _SpreadForCollapse(searchId) {
        dx := this._foldShift.Has(searchId) ? this._foldShift[searchId] : 0
        if (dx <= 0) {
            nearest := this._NearestSuccessorX(searchId)
            if (nearest == "")
                return
            gap := nearest - this._NodeX(searchId)
            target := this._CollapseGap(searchId)
            if (gap <= target + 80)
                return
            dx := gap - target
        }
        this._ShiftDescendantsX(searchId, -dx)
        if (this._foldShift.Has(searchId))
            this._foldShift.Delete(searchId)
    }

    ; 克隆一个移动Pro序列：新建序列码并把源数据各字段复制过去，返回新的 CurCMD(序列码)
    _CloneMMPro(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        newSerial := GetCMDSerialStr("移动Pro")
        newData := MMProData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                newData.PosVarX := src.PosVarX
                newData.PosVarY := src.PosVarY
                newData.Speed := src.Speed
                newData.ActionType := src.ActionType
                newData.MouseMoveMode := src.MouseMoveMode
                newData.Count := src.Count
                newData.Interval := src.Interval
                if (ObjHasOwnProp(src, "IsHumanMouse"))
                    newData.IsHumanMouse := src.IsHumanMouse
                if (ObjHasOwnProp(src, "ConfigName"))
                    newData.ConfigName := src.ConfigName
                if (ObjHasOwnProp(src, "ConfigArr"))
                    newData.ConfigArr := src.ConfigArr
            }
        }
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 克隆一个搜索/搜索Pro序列：新建序列码并把源数据各字段复制过去，返回新的 CurCMD(序列码)
    _CloneSearch(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        isPro := this._IsSearchProName(srcSerial)
        newSerial := GetCMDSerialStr(isPro ? "搜索Pro" : "搜索")
        newData := SearchData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                ; 逐属性复制（SerialStr 保持新序列码）
                for prop in src.OwnProps() {
                    if (prop == "SerialStr")
                        continue
                    newData.%prop% := src.%prop%
                }
            }
        }
        ; 真/假分支子图需深拷贝出独立序列码，避免粘贴后两个搜索共享同一分支子图
        newData.TrueMacro := this._CloneBranchGraph(newData.HasOwnProp("TrueMacro") ? newData.TrueMacro : "")
        newData.FalseMacro := this._CloneBranchGraph(newData.HasOwnProp("FalseMacro") ? newData.FalseMacro : "")
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 深拷贝一个分支子图（图形开始节点 + 其所有图形节点），返回新的开始节点序列码。
    ; 非「图形开始节点」序列码（如空串/旧线性宏）原样返回。
    _CloneBranchGraph(startSerial) {
        if (startSerial == "")
            return ""
        SplitSerialTextAndNumbers(startSerial, &t0, &n0)
        if (t0 != GetLangKey("图形开始节点") || n0 == "")
            return startSerial
        startData := GetMacroCMDData(startSerial)
        if (!IsObject(startData))
            return ""
        nodeArr := (startData.HasOwnProp("NodeArr") && IsObject(startData.NodeArr)) ? startData.NodeArr : []
        emptyArr := (startData.HasOwnProp("EmptyNode") && IsObject(startData.EmptyNode)) ? startData.EmptyNode : []

        ; 1) 沿 NodeArr/EmptyNode + NextNodeArr 广度遍历，为每个旧序列码生成新序列码
        serialMap := Map()
        queue := []
        for s in nodeArr
            queue.Push(s)
        for s in emptyArr
            queue.Push(s)
        while (queue.Length > 0) {
            s := queue.RemoveAt(1)
            if (s == "" || serialMap.Has(s))
                continue
            SplitSerialTextAndNumbers(s, &st, &sn)
            serialMap[s] := GetCMDSerialStr(st)
            nd := GetMacroCMDData(s)
            if (IsObject(nd) && nd.HasOwnProp("NextNodeArr") && IsObject(nd.NextNodeArr)) {
                for ns in nd.NextNodeArr
                    queue.Push(ns)
            }
        }

        ; 2) 复制每个图形节点，重映射 NextNodeArr 内的后继序列码
        for oldS, newS in serialMap {
            nd := GetMacroCMDData(oldS)
            cp := MacroGraphNode()
            cp.SerialStr := newS
            if (IsObject(nd)) {
                cp.CurCMD := nd.HasOwnProp("CurCMD") ? nd.CurCMD : ""
                cp.X := nd.HasOwnProp("X") ? nd.X : 0
                cp.Y := nd.HasOwnProp("Y") ? nd.Y : 0
                cp.Folded := nd.HasOwnProp("Folded") ? nd.Folded : 0
                newNexts := []
                if (nd.HasOwnProp("NextNodeArr") && IsObject(nd.NextNodeArr)) {
                    for ns in nd.NextNodeArr
                        newNexts.Push(serialMap.Has(ns) ? serialMap[ns] : ns)
                }
                cp.NextNodeArr := newNexts
            }
            SaveMacroCMDData(cp)
        }

        ; 3) 复制开始节点，重映射 NodeArr/EmptyNode
        newStart := GetCMDSerialStr("图形开始节点")
        sn := MacroGraphStartNode()
        sn.SerialStr := newStart
        newNodeArr := []
        for s in nodeArr
            newNodeArr.Push(serialMap.Has(s) ? serialMap[s] : s)
        newEmptyArr := []
        for s in emptyArr
            newEmptyArr.Push(serialMap.Has(s) ? serialMap[s] : s)
        sn.NodeArr := newNodeArr
        sn.EmptyNode := newEmptyArr
        sn.X := startData.HasOwnProp("X") ? startData.X : 60
        sn.Y := startData.HasOwnProp("Y") ? startData.Y : 220
        SaveMacroCMDData(sn)
        return newStart
    }

    _OnField(id, field, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        nameMap := Map("time", "Time_", "time2", "Time2_", "hold", "Hold_", "count", "Count_", "inter", "Inter_", "posx", "PosX_", "posy", "PosY_", "speed", "Speed_")
        key := nameMap[field] id
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (state.Has(key)) {
            val := state[key]
            ; 时间为可编辑下拉，忽略下拉初始化阶段的空值，避免覆盖已有时间
            if ((field == "time" || field == "time2") && val == "")
                return
            ; 数值字段最小为 1
            if (IsNumber(val) && val + 0 < 1)
                val := "1"
            d.%field% := val
        }
        this.cmdNodes[id].CurCMD := this._BuildCmd(d)
        if (field == "count")
            this._RefreshKeyVisibility(id)
        ; 防抖：200ms 内只执行一次 _CaptureLinks + _Apply
        if (this.HasOwnProp("_fieldDebounceTimer"))
            SetTimer(this._fieldDebounceTimer, 0)
        this._fieldDebounceTimer := this._DoFieldApply.Bind(this)
        SetTimer(this._fieldDebounceTimer, -200)
    }

    _DoFieldApply() {
        this._CaptureLinks()
        this._Apply()
    }

    ; 为所有内联编辑 TextBox 绑定回车事件和文本变化事件
    ; 注：间隔的 time/time2 已改为可编辑下拉(ComboBox)，由 SelectionChanged/LostFocus 处理，不在此绑定 TextChanged
    _BindTextBoxEnterEvents() {
        fields := ["hold", "count", "inter", "posx", "posy", "speed"]
        nameMap := Map("hold", "Hold_", "count", "Count_", "inter", "Inter_", "posx", "PosX_", "posy", "PosY_", "speed", "Speed_")
        for id in this.cmdNodes {
            for field in fields {
                boxName := nameMap[field] id
                this.ui.OnEvent(boxName, "KeyDown:Return", ObjBindMethod(this, "_OnField", id, field))
                this.ui.OnEvent(boxName, "TextChanged", ObjBindMethod(this, "_OnField", id, field))
            }
        }
    }

    ; 重算按键节点 点击时长/次数/间隔 行的显隐
    _RefreshKeyVisibility(id) {
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (d.type != GetLang("按键") || this.ui == "")
            return
        isClick := d.ktype == GetLang("点击")
        showInter := isClick && IsNumber(d.count) && (d.count + 0) > 1
        this.ui.Update("HoldRow_" id, "Visibility", isClick ? "Visible" : "Collapsed")
        this.ui.Update("CountRow_" id, "Visibility", isClick ? "Visible" : "Collapsed")
        this.ui.Update("InterRow_" id, "Visibility", showInter ? "Visible" : "Collapsed")
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
        d := this._Parse(this.cmdNodes[id].CurCMD)
        editor := ""
        if (d.type == GetLang("间隔"))
            editor := this.IntervalGui
        else if (d.type == GetLang("按键"))
            editor := this.KeyGui
        else if (d.type == GetLang("移动"))
            editor := this.MouseGui
        else if (d.type == GetLang("移动Pro"))
            editor := this.MMProGui
        else if (d.type == GetLang("搜索Pro"))
            editor := this.SearchProGui
        else if (d.type == GetLang("搜索"))
            editor := this.SearchGui
        if (editor == "")
            return

        editor.OwnerHwnd := (this.ui != "" && this.ui.wpfHwnd) ? this.ui.wpfHwnd : ""
        editor.SureBtnAction := (cmd) => this.OnEditorSure(id, cmd)
        editor.ShowGui(this.cmdNodes[id].CurCMD)
    }

    ; 完整编辑器确定后：回写数据并刷新节点显示
    OnEditorSure(id, cmd) {
        if (!this.cmdNodes.Has(id))
            return
        this.cmdNodes[id].CurCMD := cmd
        dEdit := this._Parse(cmd)
        ; 搜索/搜索Pro：就地刷新内联字段与分支节点内容，避免整窗重建（闪烁/窗口被销毁）
        if (dEdit.type == GetLang("搜索") || dEdit.type == GetLang("搜索Pro")) {
            this._RefreshSearchNode(id, dEdit)
            this._Apply()
            return
        }
        ; 注入的简要节点无法就地刷新 → 重建为完整内联节点
        if (this.injected.Has(id)) {
            this._CaptureLinks()
            this._Render()
            return
        }
        if (this.ui != "") {
            d := this._Parse(cmd)
            this.ui.Update("Title_" id, "Text", d.type)
            if (d.type == GetLang("间隔")) {
                this.ui.Update("ITypeCmb_" id, "SelectedIndex", this._IntervalTypeIndex(d.itype))
                this.ui.Update("Time_" id, "Text", d.time)
                this.ui.Update("Time2_" id, "Text", d.time2)
                this._RefreshIntervalVisibility(id)
            }
            else if (d.type == GetLang("按键")) {
                this.ui.Update("KeyName_" id, "Text", d.key)
                this.ui.Update("TypeCmb_" id, "Text", d.ktype)
                this.ui.Update("Hold_" id, "Text", d.hold)
                this.ui.Update("Count_" id, "Text", d.count)
                this.ui.Update("Inter_" id, "Text", d.inter)
                this._RefreshKeyVisibility(id)
            }
            else if (d.type == GetLang("移动")) {
                this.ui.Update("PosX_" id, "Text", d.posx)
                this.ui.Update("PosY_" id, "Text", d.posy)
                this.ui.Update("Speed_" id, "Text", d.speed)
                this.ui.Update("ModeCmb_" id, "SelectedIndex", this._MoveModeIndex(d.mode))
                this._RefreshMoveVisibility(id)
            }
            else if (d.type == GetLang("移动Pro")) {
                data := this._MMProData(id)
                if (data != "") {
                    this.ui.Update("MPPosX_" id, "Text", GetLang(data.PosVarX))
                    this.ui.Update("MPPosY_" id, "Text", GetLang(data.PosVarY))
                    this.ui.Update("MPSpeed_" id, "Text", data.Speed)
                    this.ui.Update("MPActionCmb_" id, "SelectedIndex", this._MMProActionIndex(data.ActionType))
                    this.ui.Update("MPModeCmb_" id, "SelectedIndex", this._MoveModeIndex(data.MouseMoveMode))
                    this.ui.Update("MPHuman_" id, "IsChecked", (ObjHasOwnProp(data, "IsHumanMouse") && (data.IsHumanMouse == 1 || data.IsHumanMouse == "1")) ? "True" : "False")
                    this.ui.Update("MPCount_" id, "Text", ObjHasOwnProp(data, "Count") ? data.Count : 1)
                    this.ui.Update("MPInterval_" id, "Text", ObjHasOwnProp(data, "Interval") ? data.Interval : 1000)
                    this._RefreshMMProVisibility(id)
                }
            }
        }
        this._Apply()
    }

    ; 搜索/搜索Pro 完整编辑器确定后：就地刷新内联字段、显隐与真/假分支节点内容（不重建窗口）
    _RefreshSearchNode(id, d) {
        if (this.ui == "")
            return
        isPro := (d.type == GetLang("搜索Pro"))
        maxType := isPro ? 6 : 3
        st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= maxType) ? d.searchType : 1
        this.ui.Update("Title_" id, "Text", d.type)
        this.ui.Update("STypeCmb_" id, "SelectedIndex", st - 1)
        this.ui.Update("SColor_" id, "Text", d.HasOwnProp("searchColor") ? d.searchColor : "FFFFFF")
        this.ui.Update("SText_" id, "Text", d.HasOwnProp("searchText") ? d.searchText : "")
        imgPath := d.HasOwnProp("searchImagePath") ? d.searchImagePath : ""
        this.ui.Update("SImg_" id, "Text", imgPath != "" ? RegExReplace(imgPath, ".*\\", "") : GetLang("未设置"))
        this.ui.Update("SSim_" id, "Text", d.HasOwnProp("similar") ? d.similar : 90)
        this.ui.Update("SStartX_" id, "Text", d.HasOwnProp("startPosX") ? d.startPosX : 0)
        this.ui.Update("SStartY_" id, "Text", d.HasOwnProp("startPosY") ? d.startPosY : 0)
        this.ui.Update("SEndX_" id, "Text", d.HasOwnProp("endPosX") ? d.endPosX : A_ScreenWidth)
        this.ui.Update("SEndY_" id, "Text", d.HasOwnProp("endPosY") ? d.endPosY : A_ScreenHeight)
        maxAct := isPro ? 3 : 4
        ma := (d.HasOwnProp("mouseAction") && d.mouseAction >= 1 && d.mouseAction <= maxAct) ? d.mouseAction : 2
        this.ui.Update("SActCmb_" id, "SelectedIndex", ma - 1)
        ; 搜索Pro 专属字段同步
        if (isPro) {
            this.ui.Update("SWin_" id, "Text", d.HasOwnProp("winInfo") ? d.winInfo : "")
            cnt := d.HasOwnProp("searchCount") ? d.searchCount : 1
            this.ui.Update("SCount_" id, "Text", (cnt == -1 || cnt == "-1") ? GetLang("无限") : "" cnt)
            this.ui.Update("SInterval_" id, "Text", d.HasOwnProp("searchInterval") ? d.searchInterval : 1000)
            this.ui.Update("SSpeed_" id, "Text", d.HasOwnProp("speed") ? d.speed : 90)
            this.ui.Update("SClick_" id, "Text", d.HasOwnProp("clickCount") ? d.clickCount : 1)
            this.ui.Update("SResTog_" id, "IsChecked", (d.HasOwnProp("resultToggle") && (d.resultToggle == 1 || d.resultToggle == "1")) ? "True" : "False")
            this.ui.Update("SResName_" id, "Text", d.HasOwnProp("resultSaveName") ? d.resultSaveName : "")
            this.ui.Update("SResTrue_" id, "Text", d.HasOwnProp("trueValue") ? d.trueValue : 1)
            this.ui.Update("SResFalse_" id, "Text", d.HasOwnProp("falseValue") ? d.falseValue : 0)
            this.ui.Update("SCoordTog_" id, "IsChecked", (d.HasOwnProp("coordToggle") && (d.coordToggle == 1 || d.coordToggle == "1")) ? "True" : "False")
            this.ui.Update("SCoordX_" id, "Text", d.HasOwnProp("coordXName") ? d.coordXName : "")
            this.ui.Update("SCoordY_" id, "Text", d.HasOwnProp("coordYName") ? d.coordYName : "")
        }
        this._RefreshSearchVisibility(id)
        ; TrueMacro/FalseMacro 可能在搜索编辑器中被修改，刷新分支节点内容
        this._RefreshBranchBody(id, true)
        this._RefreshBranchBody(id, false)
    }

    ; ----------------------------------------------------------------- 生成/回写

    ; 回写：图形宏以「开始节点(MacroGraphStartNode) 的 SerialStr」作为入口引用写回 MacroArr
    _Apply() {
        if (this.SureBtnAction == "")
            return
        this._CaptureLinks()
        action := this.SureBtnAction
        action(this.startSerial)
    }

    ; ----------------------------------------------------------------- 图结构持久化

    ; 保存图结构（全部走项目标准 SaveMacroCMDData，无额外索引）：
    ;   - 每个 MacroGraphNode（CurCMD、后继 NextNodeArr 的 SerialStr、坐标）存入 GraphNodeFile.ini；
    ;   - 开始节点 MacroGraphStartNode（NodeArr=开始连向的节点、EmptyNode=无前置的自由节点、坐标）存入 GraphStartNodeFile.ini。
    ;   - MacroArr 仅记录开始节点的 SerialStr，复原时由它即可取得全部信息。
    _SaveGraph() {
        if (this.graph == "")
            return
        if (this.startSerial == "")
            this.startSerial := GetCMDSerialStr("图形开始节点")
        this._CaptureLinks()
        this._SyncPositionsFromGraph()

        ; 后继表(engineId->[engineId])、入度统计、开始节点的后继
        nextMap := Map()
        inDeg := Map()
        for id in this.order
            inDeg[id] := 0
        startNexts := []
        for link in this.links {
            if (link.from == this.startId) {
                if (this.cmdNodes.Has(link.to))
                    startNexts.Push(link.to)
                continue
            }
            if (!this.cmdNodes.Has(link.from))
                continue
            if (!nextMap.Has(link.from))
                nextMap[link.from] := []
            nextMap[link.from].Push(link.to)
            if (this.cmdNodes.Has(link.to))
                inDeg[link.to] := inDeg[link.to] + 1
        }

        ; NodeArr = 开始节点连向的节点 SerialStr
        nodeArr := []
        startedSet := Map()
        for toE in startNexts {
            nodeArr.Push(this.cmdNodes[toE].SerialStr)
            startedSet[toE] := true
        }

        ; 逐指令节点保存本体
        for id in this.order {
            node := this.cmdNodes[id]
            nexts := []
            if (nextMap.Has(id)) {
                for toE in nextMap[id] {
                    if (this.cmdNodes.Has(toE))
                        nexts.Push(this.cmdNodes[toE].SerialStr)
                }
            }
            node.NextNodeArr := nexts
            p := this.pos.Has(id) ? this.pos[id] : { x: 0, y: 0 }
            node.X := p.x
            node.Y := p.y
            SaveMacroCMDData(node)          ; 存入 GraphNodeFile.ini（key=node.SerialStr）
        }

        ; EmptyNode = 既不被开始节点连接、也无任何前置指令节点的自由节点
        emptyNode := []
        for id in this.order {
            if (startedSet.Has(id) || inDeg[id] > 0)
                continue
            emptyNode.Push(this.cmdNodes[id].SerialStr)
        }

        ; 保存开始节点 MacroGraphStartNode
        sp := this.pos.Has(this.startId) ? this.pos[this.startId] : { x: 60, y: 220 }
        startNode := MacroGraphStartNode()
        startNode.SerialStr := this.startSerial
        startNode.NodeArr := nodeArr
        startNode.EmptyNode := emptyNode
        startNode.X := sp.x
        startNode.Y := sp.y
        SaveMacroCMDData(startNode)         ; 存入 GraphStartNodeFile.ini（key=startSerial）
    }

    ; 从开始节点 SerialStr 复原整张图；成功返回 true（cmdNodes/pos/links/order 均已重建）。
    ; 读 MacroGraphStartNode 拿到 NodeArr/EmptyNode 作为种子，沿各节点 NextNodeArr 广度遍历取回全部节点。
    _LoadGraph(startSerial) {
        if (startSerial == "")
            return false
        SplitSerialTextAndNumbers(startSerial, &t, &n)
        if (t != GetLangKey("图形开始节点") || n == "")    ; 非「图形开始节点」序列码 → 按线性宏处理
            return false
        startData := GetMacroCMDData(startSerial)
        if (!IsObject(startData))
            return false
        nodeArr := (startData.HasOwnProp("NodeArr") && IsObject(startData.NodeArr)) ? startData.NodeArr : []
        emptyArr := (startData.HasOwnProp("EmptyNode") && IsObject(startData.EmptyNode)) ? startData.EmptyNode : []
        if (nodeArr.Length == 0 && emptyArr.Length == 0)
            return false      ; 无内容（未保存过/空图）→ 走线性铺开

        this.startSerial := startSerial

        ; 广度遍历收集所有节点（种子 = NodeArr ∪ EmptyNode；沿 NextNodeArr 展开）
        serialToEngine := Map()
        nextSerialsMap := Map()
        loadedSerials := []
        queue := []
        for s in nodeArr
            queue.Push(s)
        for s in emptyArr
            queue.Push(s)
        while (queue.Length > 0) {
            serial := queue.RemoveAt(1)
            if (serial == "" || serialToEngine.Has(serial))
                continue
            nodeData := GetMacroCMDData(serial)
            eid := this._NewId()
            node := MacroGraphNode()
            node.SerialStr := serial
            node.CurCMD := (IsObject(nodeData) && nodeData.HasOwnProp("CurCMD")) ? nodeData.CurCMD : ""
            node.Folded := (IsObject(nodeData) && nodeData.HasOwnProp("Folded")) ? nodeData.Folded : 0
            this.cmdNodes[eid] := node
            this.order.Push(eid)
            x := (IsObject(nodeData) && nodeData.HasOwnProp("X")) ? nodeData.X : 0
            y := (IsObject(nodeData) && nodeData.HasOwnProp("Y")) ? nodeData.Y : 0
            this.pos[eid] := { x: x, y: y }
            serialToEngine[serial] := eid
            nexts := (IsObject(nodeData) && nodeData.HasOwnProp("NextNodeArr") && IsObject(nodeData.NextNodeArr)) ? nodeData.NextNodeArr : []
            nextSerialsMap[serial] := nexts
            for ns in nexts
                queue.Push(ns)
            loadedSerials.Push(serial)
        }

        ; 重建指令节点之间的连线（NextNodeArr 里是后继的 SerialStr）
        for serial, eid in serialToEngine {
            for nextSerial in nextSerialsMap[serial] {
                if (serialToEngine.Has(nextSerial))
                    this.links.Push({ from: eid, to: serialToEngine[nextSerial] })
            }
        }
        ; 开始节点坐标 + Start->NodeArr 连线
        this.pos[this.startId] := { x: (startData.HasOwnProp("X") ? startData.X : 60), y: (startData.HasOwnProp("Y") ? startData.Y : 220) }
        for s in nodeArr {
            if (serialToEngine.Has(s))
                this.links.Push({ from: this.startId, to: serialToEngine[s] })
        }
        ; 登记已用序号（含开始节点），避免后续 GetCMDSerialStr 生成重复
        loadedSerials.Push(startSerial)
        SetSerialByArr(loadedSerials)
        return true
    }

    ; ----------------------------------------------------------------- 指令解析/重建

    ; 创建节点：MacroGraphNode（来自 DataClass），持有 CurCMD，SerialStr 由 GetCMDSerialStr("图形节点") 生成
    _MakeNode(cmd) {
        node := MacroGraphNode()
        node.CurCMD := cmd
        node.SerialStr := GetCMDSerialStr("图形节点")
        return node
    }

    ; 解析 CurCMD，返回包含各字段的明细对象（节点信息全部由此而来，不单独存储）
    _Parse(cmd) {
        paramArr := SplitCommand(cmd)
        name := paramArr.Length >= 1 ? paramArr[1] : cmd
        d := { type: name, raw: cmd, temp: false, time: "", time2: "", itype: "", key: "", ktype: "", hold: "", count: "", inter: "", posx: "", posy: "", speed: "", mode: "" }

        if (name == GetLang("间隔")) {
            raw := paramArr.Length >= 2 ? paramArr[2] : "500"
            timeArr := StrSplit(raw, "~")
            if (timeArr.Length >= 2) {
                d.itype := GetLang("随机")
                d.time := timeArr[1]
                d.time2 := timeArr[2]
            }
            else {
                d.itype := GetLang("固定")
                d.time := raw
                d.time2 := "1000"
            }
        }
        else if (name == GetLang("按键")) {
            d.key := paramArr.Length >= 2 ? paramArr[2] : ""
            d.ktype := paramArr.Length >= 3 ? paramArr[3] : GetLang("点击")
            d.hold := paramArr.Length >= 4 ? paramArr[4] : "100"
            d.count := paramArr.Length >= 5 ? paramArr[5] : "1"
            d.inter := paramArr.Length >= 6 ? paramArr[6] : "200"
        }
        else if (name == GetLang("移动")) {
            d.posx := paramArr.Length >= 2 ? paramArr[2] : "0"
            d.posy := paramArr.Length >= 3 ? paramArr[3] : "0"
            d.speed := paramArr.Length >= 4 ? paramArr[4] : "90"
            d.mode := paramArr.Length >= 5 ? paramArr[5] : "0"
        }
        else if (this._IsMMProName(name)) {
            ; 移动Pro 参数存储在 MMProFile.ini 中，CurCMD 即其 SerialStr（如 "移动Pro3"）
            d.type := GetLang("移动Pro")
            d.serialStr := name
            try {
                data := GetMacroCMDData(name)
                if (IsObject(data)) {
                    d.posVarX := data.PosVarX
                    d.posVarY := data.PosVarY
                    d.speed := data.Speed
                    d.actionType := data.ActionType
                    d.mmmode := data.MouseMoveMode
                    d.isHuman := ObjHasOwnProp(data, "IsHumanMouse") ? data.IsHumanMouse : 0
                    d.count := ObjHasOwnProp(data, "Count") ? data.Count : 1
                    d.interval := ObjHasOwnProp(data, "Interval") ? data.Interval : 1000
                }
            }
        }
        else if (this._IsSearchName(name) || this._IsSearchProName(name)) {
            ; 搜索/搜索Pro 参数存储在 SearchFile.ini 中，CurCMD 即其 SerialStr（如 "搜索1"、"搜索Pro2"）
            d.type := this._IsSearchProName(name) ? GetLang("搜索Pro") : GetLang("搜索")
            d.serialStr := name
            try {
                data := GetMacroCMDData(name)
                if (IsObject(data)) {
                    d.searchType := data.SearchType
                    d.searchColor := data.SearchColor
                    d.searchText := data.SearchText
                    d.searchImagePath := data.SearchImagePath
                    d.similar := data.Similar
                    d.mouseAction := data.MouseActionType
                    d.startPosX := data.StartPosX
                    d.startPosY := data.StartPosY
                    d.endPosX := data.EndPosX
                    d.endPosY := data.EndPosY
                    d.trueMacro := ObjHasOwnProp(data, "TrueMacro") ? data.TrueMacro : ""
                    d.falseMacro := ObjHasOwnProp(data, "FalseMacro") ? data.FalseMacro : ""
                    ; 搜索Pro 专属字段（搜索节点忽略不用）
                    d.winInfo := ObjHasOwnProp(data, "WinInfo") ? data.WinInfo : ""
                    d.searchCount := ObjHasOwnProp(data, "SearchCount") ? data.SearchCount : 1
                    d.searchInterval := ObjHasOwnProp(data, "SearchInterval") ? data.SearchInterval : 1000
                    d.clickCount := ObjHasOwnProp(data, "ClickCount") ? data.ClickCount : 1
                    d.speed := ObjHasOwnProp(data, "Speed") ? data.Speed : 90
                    d.resultToggle := ObjHasOwnProp(data, "ResultToggle") ? data.ResultToggle : 0
                    d.resultSaveName := ObjHasOwnProp(data, "ResultSaveName") ? data.ResultSaveName : ""
                    d.trueValue := ObjHasOwnProp(data, "TrueValue") ? data.TrueValue : 1
                    d.falseValue := ObjHasOwnProp(data, "FalseValue") ? data.FalseValue : 0
                    d.coordToggle := ObjHasOwnProp(data, "CoordToogle") ? data.CoordToogle : 0
                    d.coordXName := ObjHasOwnProp(data, "CoordXName") ? data.CoordXName : ""
                    d.coordYName := ObjHasOwnProp(data, "CoordYName") ? data.CoordYName : ""
                }
            }
        }
        else {
            d.temp := true
        }
        return d
    }

    _BuildCmd(d) {
        if (d.type == GetLang("间隔")) {
            if (d.itype == GetLang("随机"))
                return GetLang("间隔") "_" d.time "~" d.time2
            return GetLang("间隔") "_" d.time
        }


        if (d.type == GetLang("按键")) {
            isClick := d.ktype == GetLang("点击")
            hasHold := isClick
            hasCount := hasHold && (d.count != "1" && d.count != 1)
            hasInter := hasCount && (d.inter != "0" && d.inter != 0)
            cmd := GetLang("按键") "_" d.key "_" d.ktype
            if (hasHold)
                cmd .= "_" d.hold
            if (hasCount)
                cmd .= "_" d.count
            if (hasInter)
                cmd .= "_" d.inter
            return cmd
        }

        if (d.type == GetLang("移动")) {
            cmd := GetLang("移动") "_" d.posx "_" d.posy "_" d.speed
            ; 模式：0=绝对移动(省略) 1=相对移动 2=游戏视角，与 MouseMoveGui 保持一致
            if (d.mode != "0" && d.mode != 0 && d.mode != "")
                cmd .= "_" d.mode
            return cmd
        }
        return d.raw
    }

    ; ----------------------------------------------------------------- 节点构建

    ; 开始/结束等无内联控件的节点
    _BuildBaseNode(id, title, nodeType) {
        node := this._NewNodeShell(id, title, nodeType, &body)
        return node
    }

    ; 指令节点（含内联编辑控件）
    _BuildCmdNode(id, node) {
        d := this._Parse(node.CurCMD)
        this._NewNodeShell(id, d.type, "Process", &body)
        this._FillNodeBody(id, d, body)
    }

    ; 填充节点 body（内联编辑控件）。静态构建与运行时注入复用同一套生成逻辑。
    _FillNodeBody(id, d, body) {
        if (d.type == GetLang("间隔")) {
            isRandom := d.itype == GetLang("随机")
            ; 间隔类型下拉（固定/随机）—— 标签与下拉同行
            this._AddComboRow(body, "ITypeRow_" id, GetLang("类型："), "ITypeCmb_" id
                , [GetLang("固定"), GetLang("随机")], this._IntervalTypeIndex(d.itype), true)
            ; 时间：可编辑下拉（既能下拉选变量，也能手动输入数值），与间隔编辑器一致
            varList := GetGuiVarArr()
            ; 固定值 / 随机最小值
            this._AddEditableComboRow(body, "Time1Row_" id, GetLang("时间："), "Time_" id, varList, d.time, true)
            ; 随机最大值（仅随机模式显示）
            this._AddEditableComboRow(body, "Time2Row_" id, GetLang("时间："), "Time2_" id, varList, d.time2, isRandom)
        }
        else if (d.type == GetLang("按键")) {
            body.Add("TextBlock").Name("KeyName_" id).Text(d.key).Foreground("#FFD27F").FontWeight("Bold").FontSize("13").TextWrapping("Wrap")

            ; 按键类型下拉 —— 标签与下拉同行
            this._AddComboRow(body, "TypeRow_" id, GetLang("按键类型") "：", "TypeCmb_" id
                , [GetLang("按下"), GetLang("松开"), GetLang("点击")], this._TypeIndex(d.ktype), true)

            isClick := d.ktype == GetLang("点击")
            showInter := isClick && IsNumber(d.count) && (d.count + 0) > 1

            this._AddFieldRow(body, "HoldRow_" id, GetLang("点击时长:"), "Hold_" id, d.hold, isClick, true, id, "hold")
            this._AddFieldRow(body, "CountRow_" id, GetLang("点击次数："), "Count_" id, d.count, isClick, true, id, "count")
            this._AddFieldRow(body, "InterRow_" id, GetLang("每次间隔："), "Inter_" id, d.inter, showInter, true, id, "inter")
        }
        else if (d.type == GetLang("移动")) {
            isGameView := (d.mode == "2" || d.mode == 2)
            ; 坐标X / 坐标Y / 移动速度 —— 标签与数值同行
            this._AddFieldRow(body, "PosXRow_" id, GetLang("坐标位置X:"), "PosX_" id, d.posx, true, true, id, "posx")
            this._AddFieldRow(body, "PosYRow_" id, GetLang("坐标位置Y:"), "PosY_" id, d.posy, true, true, id, "posy")
            this._AddFieldRow(body, "SpeedRow_" id, GetLang("移动速度："), "Speed_" id, isGameView ? "100" : d.speed, true, !isGameView, id, "speed")
            ; 移动方式下拉 —— 标签与下拉同行
            this._AddComboRow(body, "ModeRow_" id, GetLang("移动方式") "：", "ModeCmb_" id
                , [GetLang("绝对移动"), GetLang("相对移动"), GetLang("游戏视角")], this._MoveModeIndex(d.mode), true)
        }
        else if (d.type == GetLang("移动Pro")) {
            mmmode := d.HasOwnProp("mmmode") ? d.mmmode : 0
            isGameView := (mmmode == "2" || mmmode == 2)
            isHuman := (d.HasOwnProp("isHuman") && (d.isHuman == 1 || d.isHuman == "1"))
            ; 鼠标动作/拟真轨迹/速度 的可用状态与 MMProGui 保持一致：
            ;   游戏视角：动作=移动且禁用、速度=100且禁用、拟真轨迹取消并禁用、显示移动次数/每次间隔
            ;   拟真轨迹：动作=移动且禁用、移动方式禁用
            actionEnabled := !(isGameView || isHuman)
            actionIdx := (isGameView || isHuman) ? 0 : this._MMProActionIndex(d.HasOwnProp("actionType") ? d.actionType : 1)
            varList := GetGuiVarArr()
            ; 坐标X / 坐标Y：可编辑下拉（既能下拉选变量，也能手动输入数值）
            this._AddEditableComboRow(body, "MPPosXRow_" id, GetLang("坐标位置X:"), "MPPosX_" id, varList, this._MMProVarText(d, "posVarX"), true)
            this._AddEditableComboRow(body, "MPPosYRow_" id, GetLang("坐标位置Y:"), "MPPosY_" id, varList, this._MMProVarText(d, "posVarY"), true)
            ; 移动速度（文本框，支持标签拖拽改值）；游戏视角固定100且禁用
            this._AddFieldRow(body, "MPSpeedRow_" id, GetLang("移动速度："), "MPSpeed_" id, isGameView ? "100" : (d.HasOwnProp("speed") ? d.speed : "90"), true, !isGameView, id, "")
            ; 鼠标动作下拉（移动 / 移动点击1次 / 移动点击2次）
            this._AddComboRow(body, "MPActionRow_" id, GetLang("鼠标动作："), "MPActionCmb_" id
                , [GetLang("移动"), GetLang("移动点击1次"), GetLang("移动点击2次")], actionIdx, true, actionEnabled)
            ; 移动方式下拉；拟真轨迹开启时禁用
            this._AddComboRow(body, "MPModeRow_" id, GetLang("移动方式") "：", "MPModeCmb_" id
                , [GetLang("绝对移动"), GetLang("相对移动"), GetLang("游戏视角")], this._MoveModeIndex(mmmode), true, !isHuman)
            ; 启用拟真轨迹（复选框）；游戏视角下取消勾选并禁用
            this._AddCheckRow(body, "MPHumanRow_" id, "MPHuman_" id, GetLang("启用拟真轨迹"), (isHuman && !isGameView) ? 1 : 0, true, !isGameView)
            ; 移动次数 / 每次间隔（仅游戏视角显示）
            this._AddFieldRow(body, "MPCountRow_" id, GetLang("移动次数:"), "MPCount_" id, d.HasOwnProp("count") ? d.count : "1", isGameView, true, id, "")
            this._AddFieldRow(body, "MPIntervalRow_" id, GetLang("每次间隔："), "MPInterval_" id, d.HasOwnProp("interval") ? d.interval : "1000", isGameView, true, id, "")
        }
        else if (d.type == GetLang("搜索Pro")) {
            this._FillSearchProBody(id, d, body)
        }
        else if (d.type == GetLang("搜索")) {
            st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= 3) ? d.searchType : 1

            ; 搜索类型下拉
            typeNames := [GetLang("屏幕图片"), GetLang("屏幕颜色"), GetLang("屏幕文本")]
            this._AddComboRow(body, "STypeRow_" id, GetLang("搜索类型："), "STypeCmb_" id, typeNames, st - 1, true)

            ; 颜色（仅颜色搜索可见）
            this._AddFieldRow(body, "SColorRow_" id, GetLang("搜索颜色："), "SColor_" id, d.HasOwnProp("searchColor") ? d.searchColor : "FFFFFF", st == 2, true, id, "")
            ; 文本（仅文本搜索可见）
            this._AddFieldRow(body, "STextRow_" id, GetLang("搜索文本："), "SText_" id, d.HasOwnProp("searchText") ? d.searchText : "", st == 3, true, id, "")
            ; 图片名（只读显示）+ 相似度（仅图片搜索可见）
            imgPath := d.HasOwnProp("searchImagePath") ? d.searchImagePath : ""
            imgName := imgPath != "" ? RegExReplace(imgPath, ".*\\", "") : GetLang("未设置")
            this._AddFieldRow(body, "SImgRow_" id, GetLang("搜索图片："), "SImg_" id, imgName, st == 1, false)
            ; 图片预览改为浮动在节点左侧（见 _BuildHeader / _AddFloatingImgPreview），此处不再内嵌
            this._AddFieldRow(body, "SSimRow_" id, GetLang("相似度："), "SSim_" id, d.HasOwnProp("similar") ? d.similar : 90, st == 1, true, id, "", "Min:1,Max:100")

            ; 搜索范围坐标（可手动输入数值）
            this._AddFieldRow(body, "SStartXRow_" id, GetLang("起始坐标X："), "SStartX_" id, d.HasOwnProp("startPosX") ? d.startPosX : 0, true, true, id, "")
            this._AddFieldRow(body, "SStartYRow_" id, GetLang("起始坐标Y："), "SStartY_" id, d.HasOwnProp("startPosY") ? d.startPosY : 0, true, true, id, "")
            this._AddFieldRow(body, "SEndXRow_" id, GetLang("终止坐标X："), "SEndX_" id, d.HasOwnProp("endPosX") ? d.endPosX : A_ScreenWidth, true, true, id, "")
            this._AddFieldRow(body, "SEndYRow_" id, GetLang("终止坐标Y："), "SEndY_" id, d.HasOwnProp("endPosY") ? d.endPosY : A_ScreenHeight, true, true, id, "")

            ; 鼠标动作下拉
            actionNames := [GetLang("无动作"), GetLang("移动至目标"), GetLang("移动至目标点击1次"), GetLang("移动至目标点击2次")]
            ma := (d.HasOwnProp("mouseAction") && d.mouseAction >= 1 && d.mouseAction <= 4) ? d.mouseAction : 2
            this._AddComboRow(body, "SActRow_" id, GetLang("鼠标动作："), "SActCmb_" id, actionNames, ma - 1, true)

            ; 操作按钮（按类型显隐）：图片→截图/选择图片；颜色→定位取色器；所有类型→框选范围
            ops := body.Add("WrapPanel").Margin("0,6,0,0")
            shotBtn := ops.Add("Button").Name("SShot_" id).Content(GetLang("截图")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
            picBtn := ops.Add("Button").Name("SPic_" id).Content(GetLang("选择图片")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
            pickBtn := ops.Add("Button").Name("SPick_" id).Content(GetLang("定位取色器")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
            ops.Add("Button").Name("SArea_" id).Content(GetLang("框选范围")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
            if (st != 1) {
                shotBtn.Visibility("Collapsed")
                picBtn.Visibility("Collapsed")
            }
            if (st != 2)
                pickBtn.Visibility("Collapsed")
            ; 真/假分支以「强制绑定的外部分支节点」呈现（见 _BuildBranchPair），此处不再内嵌泳道
        }
        else {
            body.Add("TextBlock").Text(GetLang("临时节点")).Foreground("#FF9E9E").FontSize("12")
            body.Add("TextBlock").Text(d.raw).Foreground("#DDDDDD").FontSize("11").TextWrapping("Wrap")
        }
    }

    ; 搜索Pro 节点主体：在「搜索」基础上扩展 窗口类型/窗口信息/搜索次数+间隔/点击次数/结果保存/目标点保存；
    ; 坐标用可编辑下拉（变量或数值）；不显示 屏幕规格 与 识别模型（按需求隐藏）。
    _FillSearchProBody(id, d, body) {
        st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= 6) ? d.searchType : 1
        c := this._SearchTypeClass(st)
        varList := GetGuiVarArr()
        LW := "70", CW := "96"   ; 统一标签宽，使整行控件与下方两列的左列控件对齐

        ; 搜索类型（整行；标签宽与下方一致，下拉左边缘与左列控件对齐）
        typeNames := [GetLang("屏幕图片"), GetLang("屏幕颜色"), GetLang("屏幕文本"), GetLang("窗口图片"), GetLang("窗口颜色"), GetLang("窗口文本")]
        this._AddComboRow(body, "STypeRow_" id, GetLang("搜索类型："), "STypeCmb_" id, typeNames, st - 1, true, true, LW, "150")

        ; 窗口信息（整行，含「编辑」按钮打开窗口信息编辑器；仅窗口搜索类型显示）
        winRow := body.Add("StackPanel").Name("SWinRow_" id).Orientation("Horizontal").Margin("0,5,0,0")
        if (!c.isWin)
            winRow.Visibility("Collapsed")
        winRow.Add("TextBlock").Text(GetLang("窗口信息:")).Foreground("#DDDDDD").FontSize("12").Width(LW).VerticalAlignment("Center")
        this._MakeTextBox(winRow, "SWin_" id, d.HasOwnProp("winInfo") ? d.winInfo : "", "196")
        winRow.Add("Button").Name("SWinEdit_" id).Content(GetLang("编辑")).FontSize("11").Height("20").Margin("4,0,0,0").Padding("8,0")

        ; 颜色 / 文本 / 相似度（整行，按类型显隐）
        this._AddFieldRow(body, "SColorRow_" id, GetLang("搜索颜色："), "SColor_" id, d.HasOwnProp("searchColor") ? d.searchColor : "FFFFFF", c.isColor, true, id, "", "", LW, "150")
        this._AddFieldRow(body, "STextRow_" id, GetLang("搜索文本："), "SText_" id, d.HasOwnProp("searchText") ? d.searchText : "", c.isText, true, id, "", "", LW, "150")
        this._AddFieldRow(body, "SSimRow_" id, GetLang("相似度："), "SSim_" id, d.HasOwnProp("similar") ? d.similar : 90, c.isImage, true, id, "", "Min:1,Max:100", LW, CW)

        ; 搜索范围坐标（可编辑下拉，选变量或手输数值）：起点X|起点Y 一行，终点X|终点Y 一行
        rStart := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(rStart, "SStartXRow_" id, GetLang("起点X："), "SStartX_" id, varList, "" (d.HasOwnProp("startPosX") ? d.startPosX : 0), true, LW, CW, false)
        this._ProCellEdit(rStart, "SStartYRow_" id, GetLang("起点Y："), "SStartY_" id, varList, "" (d.HasOwnProp("startPosY") ? d.startPosY : 0), true, LW, CW, true)
        rEnd := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(rEnd, "SEndXRow_" id, GetLang("终点X："), "SEndX_" id, varList, "" (d.HasOwnProp("endPosX") ? d.endPosX : A_ScreenWidth), true, LW, CW, false)
        this._ProCellEdit(rEnd, "SEndYRow_" id, GetLang("终点Y："), "SEndY_" id, varList, "" (d.HasOwnProp("endPosY") ? d.endPosY : A_ScreenHeight), true, LW, CW, true)

        ; 搜索次数（含「无限」）| 每次间隔（次数为无限或大于1时显示）同一行
        cnt := d.HasOwnProp("searchCount") ? d.searchCount : 1
        cntText := (cnt == -1 || cnt == "-1") ? GetLang("无限") : "" cnt
        isCount := (cnt == -1 || cnt == "-1" || (IsNumber(cnt) && cnt + 0 > 1))
        rCnt := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(rCnt, "SCountRow_" id, GetLang("搜索次数："), "SCount_" id, [GetLang("无限")], cntText, true, LW, CW, false)
        this._ProCellField(rCnt, "SIntervalRow_" id, GetLang("每次间隔："), "SInterval_" id, d.HasOwnProp("searchInterval") ? d.searchInterval : 1000, isCount, id, LW, CW, true)

        ; 鼠标动作（整行）
        actionNames := [GetLang("无动作"), GetLang("移动至目标"), GetLang("移动至目标点击")]
        ma := (d.HasOwnProp("mouseAction") && d.mouseAction >= 1 && d.mouseAction <= 3) ? d.mouseAction : 2
        this._AddComboRow(body, "SActRow_" id, GetLang("鼠标动作："), "SActCmb_" id, actionNames, ma - 1, true, true, LW, "150")

        ; 移动速度（动作非「无」且非窗口搜索）| 点击次数（动作为点击且非窗口搜索）同一行
        showSpeed := (ma != 1 && !c.isWin)
        showClick := (ma == 3 && !c.isWin)
        rMouse := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellField(rMouse, "SSpeedRow_" id, GetLang("移动速度："), "SSpeed_" id, d.HasOwnProp("speed") ? d.speed : 90, showSpeed, id, LW, CW, false)
        this._ProCellField(rMouse, "SClickRow_" id, GetLang("点击次数："), "SClick_" id, d.HasOwnProp("clickCount") ? d.clickCount : 1, showClick, id, LW, CW, true)

        ; 操作按钮（按类型显隐）
        ops := body.Add("WrapPanel").Margin("0,6,0,0")
        shotBtn := ops.Add("Button").Name("SShot_" id).Content(GetLang("截图")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
        picBtn := ops.Add("Button").Name("SPic_" id).Content(GetLang("选择图片")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
        pickBtn := ops.Add("Button").Name("SPick_" id).Content(GetLang("定位取色器")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
        ops.Add("Button").Name("SArea_" id).Content(GetLang("框选范围")).FontSize("11").Height("22").Margin("0,0,4,4").Padding("6,0")
        if (!c.isImage) {
            shotBtn.Visibility("Collapsed")
            picBtn.Visibility("Collapsed")
        }
        if (!c.isColor)
            pickBtn.Visibility("Collapsed")

        ; 结果保存 / 目标点保存（可折叠卡片）
        this._AddSearchSaveCard(body, id, true, d, varList)
        this._AddSearchSaveCard(body, id, false, d, varList)
    }

    ; 行内单元格：标签 + 文本框（自成命名 StackPanel，便于按显隐切换）；rightCell=true 时加左间距形成第二列
    _ProCellField(rowSP, cellName, label, boxName, val, visible, id, lw, cw, rightCell, tag := "") {
        cell := rowSP.Add("StackPanel").Name(cellName).Orientation("Horizontal")
        if (rightCell)
            cell.Margin("14,0,0,0")
        if (!visible)
            cell.Visibility("Collapsed")
        cell.Add("TextBlock").Text(label).Foreground("#DDDDDD").FontSize("12").Width(lw).VerticalAlignment("Center")
        box := this._MakeTextBox(cell, boxName, val, cw, id, "")
        if (tag != "")
            box.SetProp("Tag", tag)
    }

    ; 行内单元格：标签 + 可编辑下拉（变量名/数值）
    _ProCellEdit(rowSP, cellName, label, comboName, items, textVal, visible, lw, cw, rightCell) {
        cell := rowSP.Add("StackPanel").Name(cellName).Orientation("Horizontal")
        if (rightCell)
            cell.Margin("14,0,0,0")
        if (!visible)
            cell.Visibility("Collapsed")
        cell.Add("TextBlock").Text(label).Foreground("#DDDDDD").FontSize("12").Width(lw).VerticalAlignment("Center")
        cmb := cell.Add("ComboBox").Name(comboName).Width(cw).Height("22").MinHeight("0").FontSize("12").Padding("2,0").MaxDropDownHeight("200").Foreground("White").IsEditable("True").IsTextSearchEnabled("False")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
        cmb.SetProp("Text", textVal)
    }

    ; 打开窗口信息编辑器（复用 FrontInfoGui）。用一个带 Value 属性的适配对象桥接 WPF 文本框。
    _OnSearchWinEdit(id, *) {
        data := this._SearchData(id)
        if (data == "")
            return
        adapter := { Value: data.HasOwnProp("WinInfo") ? data.WinInfo : "" }
        MyFrontInfoGui.OwnerHwnd := ""
        MyFrontInfoGui.HideAction := ""
        MyFrontInfoGui.SureAction := this._OnSearchWinEditSure.Bind(this, id, adapter)
        MyFrontInfoGui.ShowGui(adapter)
    }

    _OnSearchWinEditSure(id, adapter, *) {
        data := this._SearchData(id)
        if (data == "")
            return
        data.WinInfo := adapter.Value
        SaveMacroCMDData(data)
        this.ui.Update("SWin_" id, "Text", adapter.Value)
        this._Apply()
    }

    ; 搜索Pro「结果保存 / 目标点保存」卡片：开关复选框作为标题，勾选后展开内部变量字段
    _AddSearchSaveCard(body, id, isResult, d, varList) {
        title := isResult ? GetLang("结果保存") : GetLang("目标点保存")
        togName := (isResult ? "SResTog_" : "SCoordTog_") id
        fieldsName := (isResult ? "SResFields_" : "SCoordFields_") id
        toggled := isResult ? (d.HasOwnProp("resultToggle") && (d.resultToggle == 1 || d.resultToggle == "1"))
            : (d.HasOwnProp("coordToggle") && (d.coordToggle == 1 || d.coordToggle == "1"))

        card := body.Add("Border").Margin("0,8,0,0").Background("#1FFFFFFF").CornerRadius("5").BorderBrush("#3E3E50").BorderThickness("1").Padding("8,6")
        sp := card.Add("StackPanel")
        chk := sp.Add("CheckBox").Name(togName).Content(title).Foreground("#FFD27F").FontWeight("Bold").FontSize("12")
        if (toggled)
            chk.IsChecked("True")
        fields := sp.Add("StackPanel").Name(fieldsName).Margin("0,4,0,0")
        if (!toggled)
            fields.Visibility("Collapsed")
        if (isResult) {
            ; 变量名（可编辑下拉），标签宽 70
            this._AddEditableComboRow(fields, "SResNameRow_" id, GetLang("变量名") "：", "SResName_" id, varList, "" (d.HasOwnProp("resultSaveName") ? d.resultSaveName : ""), true, "70", "240")
            ; 真值 / 假值 在变量名下方，整体左缩进 70（与变量名输入框左对齐），文本左右居中
            tfRow := fields.Add("StackPanel").Orientation("Horizontal").Margin("70,5,0,0")
            tfRow.Add("TextBlock").Text(GetLang("真值") "：").Foreground("#DDDDDD").FontSize("12").Width("44").VerticalAlignment("Center")
            this._MakeTextBox(tfRow, "SResTrue_" id, "" (d.HasOwnProp("trueValue") ? d.trueValue : 1), "80")
            tfRow.Add("TextBlock").Text(GetLang("假值") "：").Foreground("#DDDDDD").FontSize("12").Width("44").Margin("12,0,0,0").VerticalAlignment("Center")
            this._MakeTextBox(tfRow, "SResFalse_" id, "" (d.HasOwnProp("falseValue") ? d.falseValue : 0), "80")
        }
        else {
            ; 目标点 X/Y 变量名：可编辑下拉（ComboBox）
            this._AddEditableComboRow(fields, "SCoordXRow_" id, GetLang("坐标X变量名") "：", "SCoordX_" id, varList, "" (d.HasOwnProp("coordXName") ? d.coordXName : ""), true, "96", "214")
            this._AddEditableComboRow(fields, "SCoordYRow_" id, GetLang("坐标Y变量名") "：", "SCoordY_" id, varList, "" (d.HasOwnProp("coordYName") ? d.coordYName : ""), true, "96", "214")
        }
        return card
    }

    ; ----------------------------------------------------------------- 搜索真/假分支节点（强制绑定）

    ; 分支节点合成 ID：真 = "<searchId>__BT"，假 = "<searchId>__BF"（搜索节点本身仍是 cmdNodes 中的 id）
    _BranchId(searchId, isTrue) {
        return searchId (isTrue ? "__BT" : "__BF")
    }

    ; 解析分支合成 ID，命中返回 { searchId, isTrue }，否则返回 ""
    _BranchInfo(nodeId) {
        if (nodeId != "" && RegExMatch(nodeId, "^(.+)__B([TF])$", &m))
            return { searchId: m[1], isTrue: (m[2] == "T") }
        return ""
    }

    _IsBranchId(nodeId) {
        return this._BranchInfo(nodeId) != ""
    }

    ; 把分支节点 ID 归一为其所属搜索节点 ID；非分支 ID 原样返回
    _LogicalNodeId(nodeId) {
        bi := this._BranchInfo(nodeId)
        return bi != "" ? bi.searchId : nodeId
    }

    ; 该 id 是否为搜索/搜索Pro 节点
    _IsSearchNodeId(id) {
        if (!this.cmdNodes.Has(id))
            return false
        arr := SplitCommand(this.cmdNodes[id].CurCMD)
        serial := arr.Length >= 1 ? arr[1] : this.cmdNodes[id].CurCMD
        return this._IsSearchName(serial) || this._IsSearchProName(serial)
    }

    ; 该搜索节点是否处于折叠态（折叠则隐藏分支节点、搜索直连后续）
    _NodeFolded(id) {
        if (!this.cmdNodes.Has(id))
            return false
        n := this.cmdNodes[id]
        return n.HasOwnProp("Folded") && (n.Folded == 1 || n.Folded == "1")
    }

    ; 搜索节点且未折叠（需要显示真/假分支节点）
    _IsExpandedSearch(id) {
        return this._IsSearchNodeId(id) && !this._NodeFolded(id)
    }

    ; 搜索/搜索Pro 节点宽度（Pro 更宽，分支节点需据此偏移，避免重叠）
    _SearchNodeWidth(searchId) {
        return this._IsNodePro(searchId) ? 380 : 200
    }

    ; 分支节点相对搜索节点的逻辑坐标（仅用于新建/注入时的默认位置，之后可独立拖动）
    ; X 偏移 = 节点宽度 + 固定间距，使分支落在搜索节点右侧（Pro 更宽时不重叠）
    ; Y：真分支与搜索节点齐平，假分支在真分支下方适当偏移
    _BranchPos(searchId, isTrue) {
        sp := this.pos.Has(searchId) ? this.pos[searchId] : { x: 200, y: 200 }
        return { x: sp.x + this._SearchNodeWidth(searchId) + 100, y: sp.y + (isTrue ? 0 : 210) }
    }

    _BranchTitle(isTrue) {
        return isTrue ? GetLang("找到（真）") : GetLang("未找到（假）")
    }

    ; 构建单个分支节点的 Border 元素（标题 + 指令条 + 展开按钮 + 端口）。
    ; asFragment=true 时附带 xmlns 命名空间，供运行时 AddXamlItem 注入。
    _MakeBranchBorderEl(searchId, isTrue, x, y, asFragment := false) {
        brId := this._BranchId(searchId, isTrue)
        headerColor := isTrue ? "#2E7D32" : "#C62828"
        borderColor := isTrue ? "#3FA34D" : "#D04545"
        title := this._BranchTitle(isTrue)

        border := XAMLElement("Border")
        if (asFragment)
            border.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation").SetProp("xmlns:x", "http://schemas.microsoft.com/winfx/2006/xaml")
        border.Name("Node_" brId).Background("{DynamicResource DropdownBg}").BorderBrush(borderColor).BorderThickness("1").CornerRadius("6").Width("200").SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        border.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")
        grid := border.Add("Grid")
        grid.Rows("28", "Auto")
        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background(headerColor).CornerRadius("5,5,0,0")
        hp := header.Add("StackPanel").Orientation("Horizontal").VerticalAlignment("Center").Margin("8,0")
        hp.Add("TextBlock").Text(title).Foreground("White").FontWeight("Bold").FontSize("12").VerticalAlignment("Center")
        body := grid.Add("StackPanel").Grid_Row(1).Margin("8,6,8,8")
        this._FillBranchNodeBody(searchId, isTrue, body, brId)
        this._AddNodePorts(grid, brId)
        return border
    }

    ; ---- 静态构建（_Render 期，画布尚未交付 UI）----
    ; 为一个展开的搜索节点构建真/假两个分支节点 + 强制连线（搜索→真、搜索→假）
    _BuildBranchPair(searchId) {
        this._BuildBranchNode(searchId, true)
        this._BuildBranchNode(searchId, false)
        this.graph.AddConnection(searchId, this._BranchId(searchId, true))
        this.graph.AddConnection(searchId, this._BranchId(searchId, false))
    }

    _BuildBranchNode(searchId, isTrue) {
        g := this.graph
        brId := this._BranchId(searchId, isTrue)
        bp := this._BranchPos(searchId, isTrue)
        this.pos[brId] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeBranchBorderEl(searchId, isTrue, x, y, false)
        g.canvas._Children.Push(el)
        g.nodes.Push({ Id: brId, Title: this._BranchTitle(isTrue), X: x, Y: y, W: 200, H: 60, Type: "Process" })
    }

    ; ---- 运行时注入（窗口已就绪，避免整窗重建闪烁）----
    _InjectBranchPair(searchId) {
        this._InjectBranchNode(searchId, true)
        this._InjectBranchNode(searchId, false)
        this._ActivateConnection(searchId, this._BranchId(searchId, true))
        this._ActivateConnection(searchId, this._BranchId(searchId, false))
        this._branchInjected[searchId] := true
    }

    _InjectBranchNode(searchId, isTrue) {
        g := this.graph
        brId := this._BranchId(searchId, isTrue)
        bp := this._BranchPos(searchId, isTrue)
        this.pos[brId] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeBranchBorderEl(searchId, isTrue, x, y, true)
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(el.ToString()))
        g.nodes.Push({ Id: brId, Title: this._BranchTitle(isTrue), X: x, Y: y, W: 200, H: 60, Type: "Process" })
        ; 引擎拖动/选中（高亮、跟随移动）
        g.ui.OnEvent("Node_" brId, "DragMove", ObjBindMethod(g, "OnNodeMoved", brId))
        g.ui.OnEvent("Node_" brId, "SelectNode", ObjBindMethod(g, "OnSelectNode", brId))
        g.ui.OnEvent("Node_" brId, "CtrlSelectNode", ObjBindMethod(g, "OnCtrlSelectNode", brId))
        ; 本类事件（双击进编辑器 + 展开按钮），runtime=true 同步向引擎补绑
        this._RegisterBranchEvents(searchId, isTrue, true)
        SetTimer(() => g.ui.Update("Node_" brId, "EnableDrag", "grid=20"), -150)
    }

    ; 给一个节点 grid 追加 入/出 端口（与 _NewNodeShell 中端口样式一致）
    _AddNodePorts(grid, nodeId) {
        portInEl := XAMLElement("Ellipse")
        portInEl.Name("Port_In_" nodeId)
        portInEl._Props["Width"] := "14", portInEl._Props["Height"] := "14"
        portInEl._Props["Fill"] := "#4CAF50", portInEl._Props["Stroke"] := "#333", portInEl._Props["StrokeThickness"] := "1"
        portInEl._Props["Grid.Row"] := "1", portInEl._Props["VerticalAlignment"] := "Top", portInEl._Props["HorizontalAlignment"] := "Left", portInEl._Props["Margin"] := "-7,-7,0,0"
        portInEl._Props["Panel.ZIndex"] := "10", portInEl._Props["IsHitTestVisible"] := "True", portInEl._Props["Cursor"] := "Hand"
        grid._Children.Push(portInEl)

        portOutEl := XAMLElement("Ellipse")
        portOutEl.Name("Port_Out_" nodeId)
        portOutEl._Props["Width"] := "14", portOutEl._Props["Height"] := "14"
        portOutEl._Props["Fill"] := "#FF5722", portOutEl._Props["Stroke"] := "#333", portOutEl._Props["StrokeThickness"] := "1"
        portOutEl._Props["Grid.Row"] := "1", portOutEl._Props["VerticalAlignment"] := "Top", portOutEl._Props["HorizontalAlignment"] := "Right", portOutEl._Props["Margin"] := "0,-7,-7,0"
        portOutEl._Props["Panel.ZIndex"] := "10", portOutEl._Props["IsHitTestVisible"] := "True", portOutEl._Props["Cursor"] := "Hand"
        grid._Children.Push(portOutEl)
    }

    ; 折叠（未展开）时分支节点显示的指令条数
    _BranchPreviewCount() {
        return 5
    }

    ; 填充分支节点内容：默认前 5 条指令（指令小卡片），超出则提供展开/收起；并提示双击进入编辑器
    _FillBranchNodeBody(searchId, isTrue, body, brId) {
        cmds := this._BranchGraphCmds(this._BranchStartSerial(searchId, isTrue))
        expanded := this._branchExpanded.Has(brId) && this._branchExpanded[brId]
        ; 指令以小卡片堆叠呈现；放入命名 StackPanel，便于运行时 ClearItems+AddXamlItem 重建刷新
        panel := body.Add("StackPanel").Name("SBChipsPanel_" brId)
        shown := expanded ? cmds.Length : Min(cmds.Length, this._BranchPreviewCount())
        if (cmds.Length == 0) {
            panel.Add("TextBlock").Text("（" GetLang("空") "）").Foreground("#888888").FontSize("11")
        } else {
            Loop shown {
                chip := panel.Add("Border").Background("#33000000").CornerRadius("3").Margin("0,2,0,0").Padding("5,2")
                chip.Add("TextBlock").Text(cmds[A_Index]).Foreground("#DDDDDD").FontSize("11").TextWrapping("Wrap")
            }
        }
        ; 展开/收起按钮：始终创建（便于运行时显隐），不超过预览条数时隐藏
        btn := body.Add("Button").Name("SBExpand_" brId).Content(expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")")).FontSize("10").Height("20").Margin("0,4,0,0").Padding("6,0").HorizontalAlignment("Left")
        if (cmds.Length <= this._BranchPreviewCount())
            btn.Visibility("Collapsed")
        body.Add("TextBlock").Text(GetLang("双击编辑分支")).Foreground("#888888").FontSize("10").Margin("0,4,0,0")
    }

    ; 单个指令小卡片的 XAML 片段（带命名空间，供运行时 AddXamlItem 注入）
    _BranchChipXaml(text) {
        ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
        return '<Border ' ns ' Background="#33000000" CornerRadius="3" Margin="0,2,0,0" Padding="5,2"><TextBlock Text="' this._XmlEsc(text) '" Foreground="#DDDDDD" FontSize="11" TextWrapping="Wrap"/></Border>'
    }

    ; 运行时按当前展开态重建分支指令卡片（清空后重新注入）
    _RebuildBranchChips(brId, cmds, expanded) {
        this.ui.Update("SBChipsPanel_" brId, "ClearItems", "")
        if (cmds.Length == 0) {
            ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
            this.ui.Update("SBChipsPanel_" brId, "AddXamlItem", '<TextBlock ' ns ' Text="（' this._XmlEsc(GetLang("空")) '）" Foreground="#888888" FontSize="11"/>')
            return
        }
        shown := expanded ? cmds.Length : Min(cmds.Length, this._BranchPreviewCount())
        Loop shown
            this.ui.Update("SBChipsPanel_" brId, "AddXamlItem", this._BranchChipXaml(cmds[A_Index]))
    }

    ; 运行时刷新分支节点内容（搜索编辑器/分支编辑器改动后调用，无需重建窗口）
    _RefreshBranchBody(searchId, isTrue) {
        if (this.ui == "" || !this._branchInjected.Has(searchId))
            return
        brId := this._BranchId(searchId, isTrue)
        cmds := this._BranchGraphCmds(this._BranchStartSerial(searchId, isTrue))
        expanded := this._branchExpanded.Has(brId) && this._branchExpanded[brId]
        this._RebuildBranchChips(brId, cmds, expanded)
        this.ui.Update("SBExpand_" brId, "Visibility", cmds.Length > this._BranchPreviewCount() ? "Visible" : "Collapsed")
        this.ui.Update("SBExpand_" brId, "Content", expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
    }

    ; 取分支保存内容（图形开始节点序列码 或 线性宏串）
    _BranchStartSerial(searchId, isTrue) {
        data := this._SearchData(searchId)
        if (data == "")
            return ""
        if (isTrue)
            return data.HasOwnProp("TrueMacro") ? data.TrueMacro : ""
        return data.HasOwnProp("FalseMacro") ? data.FalseMacro : ""
    }

    ; 把分支内容解析为指令显示串数组。
    ; 分支可能保存两种形式：①图形开始节点序列码（嵌套图，多后继只取首个）②线性指令宏串。
    _BranchGraphCmds(startSerial) {
        result := []
        if (startSerial == "")
            return result
        SplitSerialTextAndNumbers(startSerial, &t, &n)
        ; 非「图形开始节点」：按线性指令宏直接拆分显示，无需图遍历
        if (t != GetLangKey("图形开始节点") || n == "") {
            for cmd in SplitMacro(startSerial) {
                if (cmd != "")
                    result.Push(cmd)
            }
            return result
        }
        startData := GetMacroCMDData(startSerial)
        if (!IsObject(startData))
            return result
        nodeArr := (startData.HasOwnProp("NodeArr") && IsObject(startData.NodeArr)) ? startData.NodeArr : []
        cur := nodeArr.Length >= 1 ? nodeArr[1] : ""
        visited := Map()
        while (cur != "" && !visited.Has(cur)) {
            visited[cur] := true
            nd := GetMacroCMDData(cur)
            if (!IsObject(nd))
                break
            cmd := nd.HasOwnProp("CurCMD") ? nd.CurCMD : ""
            if (cmd != "")
                result.Push(cmd)
            nexts := (nd.HasOwnProp("NextNodeArr") && IsObject(nd.NextNodeArr)) ? nd.NextNodeArr : []
            cur := nexts.Length >= 1 ? nexts[1] : ""
        }
        return result
    }

    ; 构建可运行时注入的节点片段（Border + 内嵌端口）的 XAML 字符串。
    ; 端口作为 Border 子元素，用负 Margin 伸出节点边缘，拖动时自动跟随。
    _NodeFragments(id, node, &nodeXaml, &portInXaml, &portOutXaml) {
        g := this.graph
        d := this._Parse(node.CurCMD)
        p := this.pos.Has(id) ? this.pos[id] : { x: 200, y: 200 }
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        pres := "http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xns := "http://schemas.microsoft.com/winfx/2006/xaml"

        nodeW := (d.type == GetLang("搜索Pro")) ? 380 : 200
        border := XAMLElement("Border")
        border.SetProp("xmlns", pres).SetProp("xmlns:x", xns)
        border.Name("Node_" id).Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("6").Width(String(nodeW)).SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        border.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")
        grid := border.Add("Grid")
        grid.Rows("30", "Auto")
        this._BuildHeader(grid, id, d.type, "#3E3E50")
        body := grid.Add("StackPanel").Grid_Row(1).Margin("10,6,10,8")
        this._FillNodeBody(id, d, body)

        ; 端口：直接设置 _Props 确保属性正确
        portInEl := XAMLElement("Ellipse")
        portInEl.Name("Port_In_" id)
        portInEl._Props["Width"] := "14", portInEl._Props["Height"] := "14"
        portInEl._Props["Fill"] := "#4CAF50", portInEl._Props["Stroke"] := "#333", portInEl._Props["StrokeThickness"] := "1"
        portInEl._Props["Grid.Row"] := "1", portInEl._Props["VerticalAlignment"] := "Top", portInEl._Props["HorizontalAlignment"] := "Left", portInEl._Props["Margin"] := "-7,-7,0,0"
        portInEl._Props["Panel.ZIndex"] := "10", portInEl._Props["IsHitTestVisible"] := "True", portInEl._Props["Cursor"] := "Hand"
        grid._Children.Push(portInEl)

        portOutEl := XAMLElement("Ellipse")
        portOutEl.Name("Port_Out_" id)
        portOutEl._Props["Width"] := "14", portOutEl._Props["Height"] := "14"
        portOutEl._Props["Fill"] := "#FF5722", portOutEl._Props["Stroke"] := "#333", portOutEl._Props["StrokeThickness"] := "1"
        portOutEl._Props["Grid.Row"] := "1", portOutEl._Props["VerticalAlignment"] := "Top", portOutEl._Props["HorizontalAlignment"] := "Right", portOutEl._Props["Margin"] := "0,-7,-7,0"
        portOutEl._Props["Panel.ZIndex"] := "10", portOutEl._Props["IsHitTestVisible"] := "True", portOutEl._Props["Cursor"] := "Hand"
        grid._Children.Push(portOutEl)

        ; 压成单行供运行时 AddXamlItem 注入
        nodeXaml := this._FlattenXaml(border.ToString())
        portInXaml := ""
        portOutXaml := ""
    }

    ; 把 XAMLElement.ToString() 的多行输出压成单行，供运行时 AddXamlItem 注入使用。
    ; 引擎按 `n 切分命令，多行 XAML 会被截断；属性值里的换行已被 ToString 转义为 &#10;，
    ; 故此处移除的全部是结构性换行/缩进，安全。
    _FlattenXaml(s) {
        s := StrReplace(s, "`r", "")
        s := StrReplace(s, "`n", "")
        return s
    }

    ; 创建节点外壳（Border + 头部标题 + 端口），body 通过引用返回供填充
    _NewNodeShell(id, title, nodeType, &body) {
        g := this.graph
        p := this.pos.Has(id) ? this.pos[id] : { x: 200, y: 200 }
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        headerColor := nodeType == "Input" ? "#2E5A2E" : (nodeType == "Output" ? "#5A2E2E" : "#3E3E50")
        ; 搜索Pro 参数多，加宽节点以容纳两列布局
        nodeW := (title == GetLang("搜索Pro")) ? 380 : 200

        node := g.canvas.Add("Border").Name("Node_" id).Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("6").Width(String(nodeW)).SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        node.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")

        grid := node.Add("Grid")
        grid.Rows("30", "Auto")

        this._BuildHeader(grid, id, title, headerColor)

        body := grid.Add("StackPanel").Grid_Row(1).Margin("10,6,10,8")

        ; 端口：使用原始 XAML 字符串注入，确保属性正确
        ; 入点在标题栏下方左侧，出点在标题栏下方右侧
        if (nodeType != "Input") {
            portInEl := XAMLElement("Ellipse")
            portInEl.Name("Port_In_" id)
            portInEl._Props["Width"] := "14"
            portInEl._Props["Height"] := "14"
            portInEl._Props["Fill"] := "#4CAF50"
            portInEl._Props["Stroke"] := "#333"
            portInEl._Props["StrokeThickness"] := "1"
            portInEl._Props["Grid.Row"] := "1"
            portInEl._Props["VerticalAlignment"] := "Top"
            portInEl._Props["HorizontalAlignment"] := "Left"
            portInEl._Props["Margin"] := "-7,-7,0,0"
            portInEl._Props["Panel.ZIndex"] := "10"
            portInEl._Props["IsHitTestVisible"] := "True"
            portInEl._Props["Cursor"] := "Hand"
            grid._Children.Push(portInEl)
        }
        if (nodeType != "Output") {
            portOutEl := XAMLElement("Ellipse")
            portOutEl.Name("Port_Out_" id)
            portOutEl._Props["Width"] := "14"
            portOutEl._Props["Height"] := "14"
            portOutEl._Props["Fill"] := "#FF5722"
            portOutEl._Props["Stroke"] := "#333"
            portOutEl._Props["StrokeThickness"] := "1"
            portOutEl._Props["Grid.Row"] := "1"
            portOutEl._Props["VerticalAlignment"] := "Top"
            portOutEl._Props["HorizontalAlignment"] := "Right"
            portOutEl._Props["Margin"] := "0,-7,-7,0"
            portOutEl._Props["Panel.ZIndex"] := "10"
            portOutEl._Props["IsHitTestVisible"] := "True"
            portOutEl._Props["Cursor"] := "Hand"
            grid._Children.Push(portOutEl)
        }

        nodeObj := { Id: id, Title: title, X: x, Y: y, UI: node, W: nodeW, H: 60, Type: nodeType }
        g.nodes.Push(nodeObj)
        return node
    }

    ; 节点标题栏（图标 + 标题）。静态构建与运行时注入复用同一逻辑。
    ; 搜索/搜索Pro 节点：标题栏右侧追加 折叠/展开 按钮，控制真/假分支节点的显隐。
    _BuildHeader(grid, id, title, headerColor) {
        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background(headerColor).CornerRadius("5,5,0,0")
        hgrid := header.Add("Grid")
        hgrid.Cols("*", "Auto")
        hp := hgrid.Add("StackPanel").Grid_Column(0).Orientation("Horizontal").VerticalAlignment("Center").Margin("8,0")
        iconUri := this._IconForType(title)
        if (iconUri != "")
            hp.Add("Image").SetProp("Source", iconUri).Width("14").Height("14").Margin("0,0,5,0").VerticalAlignment("Center")
        hp.Add("TextBlock").Name("Title_" id).Text(title).Foreground("White").FontWeight("Bold").FontSize("12").VerticalAlignment("Center")
        if (this._IsSearchTypeTitle(title)) {
            ; 标题预览：颜色搜索显示色块（图片预览改为浮动在节点左侧，见 _AddFloatingImgPreview）
            d := this._Parse(this.cmdNodes[id].CurCMD)
            st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= 6) ? d.searchType : 1
            color := d.HasOwnProp("searchColor") ? d.searchColor : "FFFFFF"
            swEl := hp.Add("Border").Name("STitleColor_" id).Width("18").Height("18").CornerRadius("3").Margin("6,0,0,0").BorderBrush("#FFFFFF").BorderThickness("1").VerticalAlignment("Center")
            if (this._SearchTypeClass(st).isColor && RegExMatch(color, "^[0-9A-Fa-f]{6}$"))
                swEl.Background("#" color)
            else
                swEl.Visibility("Collapsed")
            folded := this._NodeFolded(id)
            ; 折叠/展开用实心三角图标（较大）：折叠态 ▶（点击展开），展开态 ▼（点击收起）
            btn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize("14").FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            btn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
            ; 图片搜索预览：浮动在节点左侧、入点下方，右上角贴近节点左边缘（不占用内容区）
            this._AddFloatingImgPreview(grid, id, d)
        }
        return header
    }

    ; 浮动图片预览：作为节点 Grid(Row1) 的顶部子元素，用 TranslateTransform 平移到节点左侧，
    ; 右上角贴近节点左边缘、位于入点下方；不参与内容布局，避免预览图夹在字段中间很突兀。
    _AddFloatingImgPreview(grid, id, d) {
        st := (d.HasOwnProp("searchType") && d.searchType >= 1 && d.searchType <= 6) ? d.searchType : 1
        cls := this._SearchTypeClass(st)
        imgPath := d.HasOwnProp("searchImagePath") ? d.searchImagePath : ""
        pw := 80, ph := 80
        prev := grid.Add("Border").Name("SImgPrevRow_" id).Grid_Row(1).Width(String(pw)).Height(String(ph)).HorizontalAlignment("Left").VerticalAlignment("Top").Margin("0,66,0,0").Background("#E61E1E1E").CornerRadius("4").BorderBrush("#666666").BorderThickness("1").SetProp("Panel.ZIndex", "30").SetProp("IsHitTestVisible", "False").SetProp("ClipToBounds", "True")
        prev.Add("Border.RenderTransform").Add("TranslateTransform").SetProp("X", String(-(pw + 6)))
        ; UniformToFill：铺满预览框并裁掉溢出，避免非正方形图片出现上下/左右黑边
        img := prev.Add("Image").Name("SImgPrev_" id).SetProp("Stretch", "UniformToFill")
        showImg := (cls.isImage && imgPath != "" && FileExist(imgPath))
        if (showImg)
            img.SetProp("Source", StrReplace(imgPath, "\", "/"))
        else
            prev.Visibility("Collapsed")
    }

    _IsSearchTypeTitle(title) {
        return title == GetLang("搜索") || title == GetLang("搜索Pro")
    }

    ; 由指令类型名查找对应图标 URI（匹配 CmdList 顺序）；开始节点等无对应项返回空
    _IconForType(typeName) {
        for i, n in this.CmdList {
            if (n == typeName)
                return this._IconUri(i)
        }
        return ""
    }

    ; 一行 "标签 + 文本框"，visible 控制初始显隐，enabled 控制文本框是否可编辑
    _AddFieldRow(body, rowName, labelText, boxName, boxValue, visible, enabled := true, nodeId := "", field := "", boxTag := "", labelW := "80", boxW := "96") {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,5,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize("12").Width(labelW).VerticalAlignment("Center")
        box := this._MakeTextBox(row, boxName, boxValue, boxW, nodeId, field)
        ; boxTag 形如 "Min:1,Max:100"：限制 label 拖动改值的取值区间（引擎读取 Tag）
        if (boxTag != "")
            box.SetProp("Tag", boxTag)
        if (!enabled)
            box.IsEnabled("False")
        return row
    }

    ; 一行 "标签 + 下拉框"，label 与下拉框同行显示，visible 控制初始显隐
    _AddComboRow(body, rowName, labelText, comboName, items, selIndex, visible, enabled := true, labelW := "80", comboW := "96") {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,5,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize("12").Width(labelW).VerticalAlignment("Center")
        cmb := row.Add("ComboBox").Name(comboName).Width(comboW).Height("22").MinHeight("0").FontSize("12").Padding("2,0").MaxDropDownHeight("200").SelectedIndex(selIndex)
        if (!enabled)
            cmb.IsEnabled("False")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
        return row
    }

    ; 标签 + 可编辑下拉（IsEditable）：既能从下拉选项中选，也能手动输入文本/数值
    _AddEditableComboRow(body, rowName, labelText, comboName, items, textValue, visible, labelW := "80", comboW := "96") {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,5,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize("12").Width(labelW).VerticalAlignment("Center")
        ; MaxDropDownHeight 限制下拉高度（约 10 项），超出时模板内 ScrollViewer 自动出现滚动条
        cmb := row.Add("ComboBox").Name(comboName).Width(comboW).Height("22").MinHeight("0").FontSize("12").Padding("2,0").MaxDropDownHeight("200").Foreground("White").IsEditable("True").IsTextSearchEnabled("False")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
        ; ComboBox 上 .Text() 会被别名成 Content，需用 SetProp 直接写 Text 属性（编辑框文本，ToString 会自动转义）
        cmb.SetProp("Text", textValue)
        return row
    }

    ; 标签型复选框行
    _AddCheckRow(body, rowName, chkName, labelText, isChecked, visible := true, enabled := true) {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,5,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        chk := row.Add("CheckBox").Name(chkName).Content(labelText).Foreground("#DDDDDD").FontSize("12").VerticalAlignment("Center")
        if (isChecked == 1 || isChecked == "1")
            chk.IsChecked("True")
        if (!enabled)
            chk.IsEnabled("False")
        return row
    }

    ; 统一的小高度文本框（MinHeight=0 覆盖主题默认的 36，否则高度不生效）
    _MakeTextBox(parent, name, value, width, nodeId := "", field := "") {
        return parent.Add("TextBox").Name(name).Text(value).Width(width).Height("20").MinHeight("0").FontSize("12").Padding("4,0").VerticalContentAlignment("Center").HorizontalContentAlignment("Center").TextAlignment("Center").CaretBrush("White")
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
