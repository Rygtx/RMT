#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 选择 / 复制 / 粘贴 / 删除 / 编辑
;
; 选中节点的删除（含分支子节点清理）、复制、粘贴（含序列码克隆与连线还原）、
; 编辑入口与粘贴锚点解析。方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphEditMixin {
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
        origin := this._GetPasteOrigin()
        ox := origin.x, oy := origin.y
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
            else if (pasteHead.Length >= 1 && this._IsInputName(pasteHead[1]))
                pasteCmd := this._CloneInput(pasteCmd)
            else if (pasteHead.Length >= 1 && this._IsOutputName(pasteHead[1]))
                pasteCmd := this._CloneOutput(pasteCmd)
            node := this._MakeNode(pasteCmd)
            this.cmdNodes[id] := node
            this.order.Push(id)
            this.pos[id] := { x: ox + cd.dx, y: oy + cd.dy }
            idMap[cd.srcId] := id
            newIds.Push(id)
        }
        ; 恢复选中节点之间的连线
        for link in this._clipboard.links {
            newFrom := idMap.Has(link.from) ? idMap[link.from] : ""
            newTo := idMap.Has(link.to) ? idMap[link.to] : ""
            if (newFrom != "" && newTo != "" && newFrom != newTo)
                this.links.Push({ from: newFrom, to: newTo })
        }
        ; 运行时注入（不重建窗口，避免闪烁）
        for id in newIds {
            node := this.cmdNodes[id]
            this._InjectFullNode(id, node)
            if (this._IsExpandedSearch(id))
                this._InjectBranchPair(id)
        }
        for link in this._clipboard.links {
            newFrom := idMap.Has(link.from) ? idMap[link.from] : ""
            newTo := idMap.Has(link.to) ? idMap[link.to] : ""
            if (newFrom != "" && newTo != "" && newFrom != newTo)
                this._ActivateConnection(newFrom, newTo)
        }
        this._NormalizeBranchConnections()
        this._ThickenConnections()
        this._RebindPathClicks()
        this._Apply()
    }

    ; 粘贴锚点：优先取鼠标「当前实时位置」（CanvasMouseLive，跟随光标而非上次点击/移动缓存），
    ; 其次回退到缓存的画布鼠标位置，再回退到上次右键位置
    _GetPasteOrigin() {
        g := this.graph
        if (this.ui != "" && this.ui.wpfHwnd && g != "") {
            ; 实时光标位置（粘贴跟随当前鼠标，而不是上次点击位置）
            ; 注：桥接层 MQUERY 用 '>' 分隔「控件名>属性」，不能用下划线，否则 FindName 失败返回空。
            origin := this._ParseCanvasPoint(this.ui.Query(g.id ">CanvasMouseLive"), g)
            if (origin != "")
                return origin
            ; 回退：MouseMove 缓存的画布坐标
            origin := this._ParseCanvasPoint(this.ui.Query(g.id ">CanvasMouse"), g)
            if (origin != "")
                return origin
        }
        if (g != "" && g.HasProp("lastRightClickX"))
            return { x: g.lastRightClickX - g.offsetX, y: g.lastRightClickY - g.offsetY }
        return { x: 300, y: 300 }
    }

    ; 解析 "x,y" 画布坐标字符串为去画布偏移后的逻辑坐标；非法返回 ""
    _ParseCanvasPoint(val, g) {
        if (val == "" || !InStr(val, ","))
            return ""
        parts := StrSplit(val, ",")
        if (parts.Length < 2)
            return ""
        return { x: Number(parts[1]) - g.offsetX, y: Number(parts[2]) - g.offsetY }
    }

    _RemoveFromOrder(id) {
        no := []
        for x in this.order {
            if (x != id)
                no.Push(x)
        }
        this.order := no
    }
}

_GraftMacroGraphMixin(MacroGraphEditMixin)
