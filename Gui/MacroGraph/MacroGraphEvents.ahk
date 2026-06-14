#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 事件注册 / 输入交互
;
; 节点与分支事件注册、控件事件绑定、节点拖动与键盘快捷键（复制/粘贴/删除）处理。
; 方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphEventsMixin {
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

    ; 窗口按键：Delete 删除选中项；Ctrl+C/V 复制粘贴节点
    ; 桥接层 PreviewKeyDown 仅传入 {Key}，修饰键需用 GetKeyState 检测
    _OnKeyDown(state, ctrl, info) {
        key := ""
        if (IsObject(info) && info.HasProp("Key"))
            key := info.Key
        else if (Type(info) == "String") {
            parts := StrSplit(info, ":")
            key := parts.Length >= 2 ? parts[2] : info
        }
        ; 忽略单独的修饰键
        if (key == "" || RegExMatch(key, "^(Left|Right)?(Ctrl|Shift|Alt|Win)$") || key == "System")
            return
        ctrlDown := GetKeyState("Ctrl")
        shiftDown := GetKeyState("Shift")
        if (key == "Delete" || key == "Back")
            this._DeleteSelected()
        else if (ctrlDown && !shiftDown && (key = "C" || key = "c"))
            this._CopySelected()
        else if (ctrlDown && !shiftDown && (key = "V" || key = "v"))
            this._PasteNodes()
    }
}

_GraftMacroGraphMixin(MacroGraphEventsMixin)
