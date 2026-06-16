#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 分支 / 折叠展开 / 布局
;
; 搜索类节点的真/假分支节点显隐、折叠展开、嵌套分支编辑器，以及展开/收起时
; 后继子树的横向平移与位置还原逻辑。方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphBranchMixin {
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

    ; 切换变量节点折叠态：折叠=只显示各启用变量「变量名 = 值」摘要；展开=完整卡片。
    ; 摘要与完整两套容器同时存在，仅切换显隐（不整窗重建），避免闪烁；节点高度随容器自动收放。
    _OnToggleVarFold(id, *) {
        if (this.ui == "" || !this.cmdNodes.Has(id))
            return
        node := this.cmdNodes[id]
        willFold := this._NodeFolded(id) ? 0 : 1
        node.Folded := willFold
        try SaveMacroCMDData(node)
        if (willFold)
            this._RefreshVariableSummary(id)   ; 收起前用当前值刷新摘要
        this.ui.Update("VarSumBox_" id, "Visibility", willFold ? "Visible" : "Collapsed")
        this.ui.Update("VarFullBox_" id, "Visibility", willFold ? "Collapsed" : "Visible")
        this.ui.Update("SFold_" id, "Content", willFold ? "▶" : "▼")
        this.ui.Update("SFold_" id, "ToolTip", willFold ? GetLang("展开") : GetLang("收起"))
    }

    ; 切换运算节点折叠态：折叠=只显示各启用槽「目标 = 表达式」摘要；展开=完整卡片。
    _OnToggleOpFold(id, *) {
        if (this.ui == "" || !this.cmdNodes.Has(id))
            return
        node := this.cmdNodes[id]
        willFold := this._NodeFolded(id) ? 0 : 1
        node.Folded := willFold
        try SaveMacroCMDData(node)
        if (willFold)
            this._RefreshOperationSummary(id)
        this.ui.Update("OpSumBox_" id, "Visibility", willFold ? "Visible" : "Collapsed")
        this.ui.Update("OpFullBox_" id, "Visibility", willFold ? "Collapsed" : "Visible")
        this.ui.Update("SFold_" id, "Content", willFold ? "▶" : "▼")
        this.ui.Update("SFold_" id, "ToolTip", willFold ? GetLang("展开") : GetLang("收起"))
    }

    ; 切换循环节点折叠态：
    ;   展开(Folded=0)：完整条件卡片 + 外置循环体节点（回环连线）；
    ;   收起(Folded=1)：简化条件摘要 + 内置循环体卡片（chips），隐藏外置体与回环连线。
    ; 运行时显隐 + 连线启停，避免整窗重建闪烁。
    _OnToggleLoopFold(id, *) {
        if (this.ui == "" || !this.cmdNodes.Has(id))
            return
        node := this.cmdNodes[id]
        willFold := this._NodeFolded(id) ? 0 : 1
        node.Folded := willFold
        try SaveMacroCMDData(node)
        if (willFold) {
            this._RefreshLoopSummary(id)       ; 收起前用当前数据刷新摘要
            this._FoldLoopRuntime(id)          ; 隐藏外置循环体 + 停用回环连线
        } else {
            this._UnfoldLoopRuntime(id)        ; 显示/注入外置循环体 + 启用回环连线
        }
        this.ui.Update("LoopSumBox_" id, "Visibility", willFold ? "Visible" : "Collapsed")
        this.ui.Update("LoopFullBox_" id, "Visibility", willFold ? "Collapsed" : "Visible")
        this.ui.Update("LoopInlineBody_" id, "Visibility", willFold ? "Visible" : "Collapsed")
        if (willFold)
            this._RefreshLoopChips(id)         ; 内置循环体卡片随收起显示，刷新内容
        this.ui.Update("SFold_" id, "Content", willFold ? "▶" : "▼")
        this.ui.Update("SFold_" id, "ToolTip", willFold ? GetLang("展开") : GetLang("收起"))
        this._CaptureLinks()
    }

    ; 折叠循环：隐藏外置循环体节点 + 两条回环路径 + 循环节点右侧两个交互点；后继子树左移靠近循环节点
    _FoldLoopRuntime(loopId) {
        if (this.ui == "")
            return
        bid := this._LoopBodyId(loopId)
        this.ui.Update("Node_" bid, "Visibility", "Collapsed")
        this.ui.Update("LoopEnterPath_" loopId, "Visibility", "Collapsed")
        this.ui.Update("LoopReturnPath_" loopId, "Visibility", "Collapsed")
        this.ui.Update("LoopCyO_" loopId, "Visibility", "Collapsed")
        this.ui.Update("LoopCyI_" loopId, "Visibility", "Collapsed")
        this._CaptureLinks()
        this._SpreadForCollapse(loopId)        ; 收起：后继子树左移，与循环节点保持目标间距
    }

    ; 展开循环：显示（或首次注入）外置循环体节点 + 两条回环路径 + 循环节点右侧两个交互点；后继子树右移恢复
    _UnfoldLoopRuntime(loopId) {
        if (this.ui == "")
            return
        bid := this._LoopBodyId(loopId)
        if (!this._loopBodyInjected.Has(loopId)) {
            this._InjectLoopBodyNode(loopId)
        } else {
            this.ui.Update("Node_" bid, "Visibility", "Visible")
            this.ui.Update("LoopEnterPath_" loopId, "Visibility", "Visible")
            this.ui.Update("LoopReturnPath_" loopId, "Visibility", "Visible")
            this._UpdateLoopCyclePaths(loopId)
        }
        this.ui.Update("LoopCyO_" loopId, "Visibility", "Visible")
        this.ui.Update("LoopCyI_" loopId, "Visibility", "Visible")
        this._CaptureLinks()
        this._SpreadForExpand(loopId)          ; 展开：后继子树右移腾出外置循环体空间
    }

    ; 就地刷新循环节点收起态摘要（次数 + 条件简化信息），从当前数据取值，无需重建
    _RefreshLoopSummary(id) {
        if (this.ui == "")
            return
        info := this._LoopSummaryInfo(id)
        this.ui.Update("LoopSumCount_" id, "Text", GetLang("循环次数") "：" info.count)
        this.ui.Update("LoopSumCondi_" id, "Text", GetLang("循环条件") "：" info.condiName)
        this.ui.Update("LoopSumLogic_" id, "Text", GetLang("逻辑关系") "：" info.logicName)
        this.ui.Update("LoopSumLogic_" id, "Visibility", info.showLogic ? "Visible" : "Collapsed")
        data := this._SearchData(id)
        loop 4 {
            ci := this._LoopCondiSummaryRow(data, A_Index)
            this.ui.Update("LoopSumCondiTxt_" A_Index "_" id, "Text", ci.text)
            this.ui.Update("LoopSumCondiRow_" A_Index "_" id, "Visibility", ci.on ? "Visible" : "Collapsed")
        }
    }

    ; 外置循环体节点单击：计时判定双击 → 打开嵌套节点编辑器编辑循环体子图
    _OnLoopBodyClick(loopId, *) {
        now := A_TickCount
        lkey := "LB_" loopId
        if (this._lastClickId == lkey && now - this._lastClickTime < 400) {
            this._lastClickId := ""
            this._lastClickTime := 0
            this._OpenLoopBodyEditor(loopId)
        } else {
            this._lastClickId := lkey
            this._lastClickTime := now
        }
    }

    ; 打开嵌套「节点编辑器」编辑循环体子图；循环体内容以「图形开始节点序列码」存于 LoopBody
    _OpenLoopBodyEditor(loopId) {
        data := this._SearchData(loopId)
        if (data == "")
            return
        if (this.BranchGraphGui == "")
            this.BranchGraphGui := MacroGraphGui()
        cur := ObjHasOwnProp(data, "LoopBody") ? data.LoopBody : ""
        this.BranchGraphGui.OwnerHwnd := (this.ui != "" && this.ui.wpfHwnd) ? this.ui.wpfHwnd : ""
        this.BranchGraphGui.SureBtnAction := (startSerial) => this._OnLoopBodyEditorSure(loopId, startSerial)
        this.BranchGraphGui.OnClosedAction := (*) => this._RefreshLoopBodyNode(loopId)
        this.BranchGraphGui.ShowGui(cur)
    }

    ; 嵌套循环体编辑器回写：保存循环体子图的开始节点序列码到 LoopData
    _OnLoopBodyEditorSure(loopId, startSerial) {
        data := this._SearchData(loopId)
        if (data == "")
            return
        data.LoopBody := startSerial
        SaveMacroCMDData(data)
    }

    ; 就地刷新变量节点摘要（收起态显示），从当前 INI/解析数据取值，无需重建
    _RefreshVariableSummary(id) {
        if (this.ui == "")
            return
        d := this._FormalDFromId(id)
        anyOn := false
        loop 4 {
            slot := A_Index
            info := this._VarSummaryRowInfo(d, slot)
            if (info.on)
                anyOn := true
            this.ui.Update("VarSumRow_" slot "_" id, "Visibility", info.on ? "Visible" : "Collapsed")
            this.ui.Update("VarSumTxt_" slot "_" id, "Text", info.text)
        }
        this.ui.Update("VarSumEmpty_" id, "Visibility", anyOn ? "Collapsed" : "Visible")
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
        this._CaptureLinks()
        ; 收起：后继子树左移，与搜索节点保持至少 120px 间距
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
        data := this._BranchParentData(searchId)
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
        data := this._BranchParentData(searchId)
        if (data == "")
            return
        if (isTrue)
            data.TrueMacro := startSerial
        else
            data.FalseMacro := startSerial
        SaveMacroCMDData(data)
    }

    ; 展开循环节点的外置循环体随父节点横向平移 dx（保持相对位置）
    _ShiftLoopBodyNode(loopId, dx) {
        if (dx == 0 || !this._IsExpandedLoop(loopId))
            return
        g := this.graph
        if (g == "")
            return
        bid := this._LoopBodyId(loopId)
        if (this.pos.Has(bid) && g.GetNode(bid))
            this._ShiftNodeX(bid, dx)
        for conn in g.connections {
            if (conn.From == loopId || conn.To == loopId || this._IsLoopBodyId(conn.From) || this._IsLoopBodyId(conn.To))
                g.UpdatePath(conn.From, conn.To, conn.PathId)
        }
    }

    ; 展开搜索节点的分支节点随父节点横向平移 dx（保持用户摆放的相对位置，不重置为默认偏移）
    _ShiftBranchNodes(searchId, dx) {
        if (dx == 0)
            return
        if (this._IsIfProNodeId(searchId)) {
            this._ShiftProBranchNodes(searchId, dx)
            return
        }
        if (!this._HasVisibleBranches(searchId))
            return
        g := this.graph
        if (g == "")
            return
        for isTrue in [true, false] {
            brId := this._BranchId(searchId, isTrue)
            if (this.pos.Has(brId) && g.GetNode(brId))
                this._ShiftNodeX(brId, dx)
        }
        for conn in g.connections {
            if (conn.From == searchId || this._IsBranchId(conn.From) || this._IsBranchId(conn.To))
                g.UpdatePath(conn.From, conn.To, conn.PathId)
        }
    }

    ; 展开时后继与搜索节点的最小横向间距（需越过分支节点：节点宽 + 100 偏移 + 分支宽 200 + 60 余量）
    _ExpandMinGap(searchId) {
        return this._BranchParentWidth(searchId) + 360
    }

    ; 收起时 A 右缘到后继节点左缘的目标间距（px）
    _CollapseMargin() {
        return 120
    }

    ; 收起时后继节点左缘相对 A 左缘的目标 X 间距（= 节点宽 + 右缘余量）
    _CollapseGap(searchId) {
        return this._BranchParentWidth(searchId) + this._CollapseMargin()
    }

    ; 搜索节点逻辑X
    _NodeX(id) {
        return this.pos.Has(id) ? this.pos[id].x : 0
    }

    ; 搜索节点逻辑Y
    _NodeY(id) {
        return this.pos.Has(id) ? this.pos[id].y : 0
    }

    ; 直接后继中离搜索节点最近的主节点逻辑 X（跳过分支合成节点，避免误用 B 的分支位置）
    _NearestSuccessorX(searchId) {
        nearest := ""
        for link in this.links {
            if (link.from != searchId || !this.pos.Has(link.to) || this._IsBranchId(link.to) || this._IsProBranchId(link.to))
                continue
            sx := this.pos[link.to].x
            if (nearest == "" || sx < nearest)
                nearest := sx
        }
        return nearest
    }

    ; 直接后继中离搜索节点最近的主节点 id（跳过分支合成节点）；无后继返回 ""
    _NearestSuccessorId(searchId) {
        nearestId := "", nearestX := ""
        for link in this.links {
            if (link.from != searchId || !this.pos.Has(link.to) || this._IsBranchId(link.to) || this._IsProBranchId(link.to))
                continue
            sx := this.pos[link.to].x
            if (nearestX == "" || sx < nearestX) {
                nearestX := sx
                nearestId := link.to
            }
        }
        return nearestId
    }

    ; 收集某节点的全部后代（沿 links 传递闭包），跳过分支合成节点
    _DescendantsOf(startId) {
        out := Map()
        queue := []
        for link in this.links {
            if (link.from == startId && !this._IsBranchId(link.to) && !this._IsProBranchId(link.to))
                queue.Push(link.to)
        }
        while (queue.Length) {
            cur := queue.RemoveAt(1)
            if (out.Has(cur) || cur == startId || this._IsBranchId(cur) || this._IsProBranchId(cur))
                continue
            out[cur] := true
            for link in this.links {
                if (link.from == cur && !this._IsBranchId(link.to) && !this._IsProBranchId(link.to))
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

    ; 把搜索节点的整条后继子树横向平移 dx；展开搜索的主节点平移时，其分支节点同步平移相同距离
    _ShiftDescendantsX(searchId, dx) {
        if (dx == 0)
            return
        g := this.graph
        if (g == "")
            return
        desc := this._DescendantsOf(searchId)
        for id in desc {
            if (this._IsBranchId(id) || this._IsProBranchId(id) || this._IsLoopBodyId(id))
                continue
            this._ShiftNodeX(id, dx)
            if (this._HasVisibleBranches(id))
                this._ShiftBranchNodes(id, dx)
            if (this._IsExpandedLoop(id))
                this._ShiftLoopBodyNode(id, dx)
        }
        for conn in g.connections
            g.UpdatePath(conn.From, conn.To, conn.PathId)
    }

    ; 渲染前（引擎未就绪，只改 this.pos 逻辑坐标）静态平移后继子树。
    ; 用于首次进入时为展开搜索节点预留分支空间，避免分支与后继重叠。
    _StaticShiftDescendantsX(searchId, dx) {
        if (dx == 0)
            return
        desc := this._DescendantsOf(searchId)
        for id in desc {
            if (this._IsBranchId(id) || this._IsProBranchId(id) || !this.pos.Has(id))
                continue
            this.pos[id] := { x: this.pos[id].x + dx, y: this.pos[id].y }
        }
    }

    ; 渲染前：为所有展开的搜索节点预留分支空间。后继离搜索过近（< 展开目标间距）时把后继子树右移到
    ; 目标间距（位置式，幂等；仅在过近时右移，不改动比目标更宽的用户布局），
    ; 修复「首次进入编辑器时搜索后面的分支错乱/重叠」。目标间距见 _ExpandTargetDX（优先用保存的后继相对位置）。
    _StaticSpreadExpandedSearches() {
        for id in this.order {
            if (!this._HasVisibleBranches(id) && !this._IsExpandedLoop(id))
                continue
            nearest := this._NearestSuccessorX(id)
            if (nearest == "")
                continue
            curDX := nearest - this._NodeX(id)
            target := this._ExpandTargetDX(id)
            if (curDX >= target)
                continue
            this._StaticShiftDescendantsX(id, target - curDX)
        }
    }

    ; 展开：把后继子树平移以腾出分支空间（位置式，不累加位移，收/展往返不漂移）：
    ;   · 有记忆的后继偏移(SuccDX≥最小间距)：精确对齐到该偏移（双向，精确还原用户摆放）；
    ;   · 无记忆：仅在后继过近时右移到最小间距，已较远的后继不往回拉（避免意外位移）。
    _SpreadForExpand(searchId) {
        nearest := this._NearestSuccessorX(searchId)
        if (nearest == "")
            return
        curDX := nearest - this._NodeX(searchId)
        minGap := this._ExpandMinGap(searchId)
        saved := this._SavedSuccOffsetX(searchId)
        if (saved != "" && saved >= minGap) {
            dx := saved - curDX
        } else {
            if (curDX >= minGap)
                return
            dx := minGap - curDX
        }
        if (dx != 0)
            this._ShiftDescendantsX(searchId, dx)
    }

    ; 取节点上保存的「最近后继相对 X 偏移」(SuccDX)；未保存/非法返回 ""
    _SavedSuccOffsetX(searchId) {
        if (!this.cmdNodes.Has(searchId))
            return ""
        node := this.cmdNodes[searchId]
        if (!node.HasOwnProp("SuccDX"))
            return ""
        dx := node.SuccDX
        if (dx == "" || !IsNumber(dx))
            return ""
        return dx + 0
    }

    ; 展开时「最近后继」相对搜索节点的目标 X 偏移：
    ; 优先用保存/记忆的后继相对位置(SuccDX)，并夹紧到不小于 _ExpandMinGap（保证分支不与后继重叠）；
    ; 无有效保存值时直接用 _ExpandMinGap。
    _ExpandTargetDX(searchId) {
        minGap := this._ExpandMinGap(searchId)
        saved := this._SavedSuccOffsetX(searchId)
        if (saved != "" && saved > minGap)
            return saved
        return minGap
    }

    ; 收起前把当前(展开态)最近后继的相对偏移记忆到 SuccDX/SuccDY，供下次展开精确还原用户摆放的位置。
    ; 仅当当前偏移确属展开态(>= 最小间距)时记录，避免把收起态的小间距误存为展开偏移。
    _RememberSuccOffset(searchId) {
        if (!this.cmdNodes.Has(searchId))
            return
        succId := this._NearestSuccessorId(searchId)
        if (succId == "" || !this.pos.Has(succId))
            return
        curDX := this.pos[succId].x - this._NodeX(searchId)
        if (curDX < this._ExpandMinGap(searchId))
            return
        node := this.cmdNodes[searchId]
        node.SuccDX := curDX
        node.SuccDY := this.pos[succId].y - this._NodeY(searchId)
        SaveMacroCMDData(node)
    }

    ; 收起：先记忆当前(展开态)后继偏移(供下次展开还原)，再把后继子树平移，
    ; 使「最近后继」精确落在收起目标偏移 _CollapseGap 处（位置式，与展开对称，收/展往返一致）。
    _SpreadForCollapse(searchId) {
        nearest := this._NearestSuccessorX(searchId)
        if (nearest == "")
            return
        this._RememberSuccOffset(searchId)
        curDX := nearest - this._NodeX(searchId)
        dx := this._CollapseGap(searchId) - curDX
        if (dx != 0)
            this._ShiftDescendantsX(searchId, dx)
    }
}

_GraftMacroGraphMixin(MacroGraphBranchMixin)
