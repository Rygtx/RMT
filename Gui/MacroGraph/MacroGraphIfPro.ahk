#Requires AutoHotkey v2.0

; 如果Pro 节点：动态多分支、侧向分支点、折叠摘要（与 MacroGraphFormal / NodeUI 配套）

class MacroGraphIfProMixin {

    _IsIfProNodeId(id) {
        if (!this.cmdNodes.Has(id))
            return false
        return this._Parse(this.cmdNodes[id].CurCMD).type == GetLang("如果Pro")
    }

    _IsExpandedIfPro(id) {
        return this._IsIfProNodeId(id) && !this._NodeFolded(id)
    }

    ; 如果Pro 分支合成 ID："<parentId>__BP0" … "__BP{n}"（末位为「以上都不是」）
    _ProBranchId(parentId, idx) {
        return parentId "__BP" idx
    }

    _ProBranchInfo(nodeId) {
        if (nodeId != "" && RegExMatch(nodeId, "^(.+)__BP(\d+)$", &m))
            return { parentId: m[1], idx: Integer(m[2]) }
        return ""
    }

    _IsProBranchId(nodeId) {
        return this._ProBranchInfo(nodeId) != ""
    }

    _IfProData(id) {
        return this._FormalIniData(id)
    }

    _IfProBranchCountFromData(data) {
        if (data == "" || !data.HasOwnProp("VariNameArr") || !IsObject(data.VariNameArr))
            return 1
        return data.VariNameArr.Length + 1
    }

    _IfProBranchCountFromId(id) {
        return this._IfProBranchCountFromData(this._IfProData(id))
    }

    _IfProCaseCountFromData(data) {
        if (data == "" || !data.HasOwnProp("VariNameArr"))
            return 0
        return data.VariNameArr.Length
    }

    _IfProBranchTitle(parentId, idx) {
        cc := this._IfProCaseCountFromData(this._IfProData(parentId))
        if (idx < cc)
            return "情况" (idx + 1)
        return GetLang("以上都不是")
    }

    _IfProBranchMacro(parentId, idx) {
        data := this._IfProData(parentId)
        if (data == "")
            return ""
        cc := this._IfProCaseCountFromData(data)
        if (idx < cc)
            return data.MacroArr[idx + 1]
        return data.DefaultMacro
    }

    _IfProBranchControl(parentId, idx) {
        data := this._IfProData(parentId)
        if (data == "")
            return "无"
        cc := this._IfProCaseCountFromData(data)
        if (idx < cc)
            return data.ControlTypeArr[idx + 1]
        return data.DefaultControlType
    }

    _IfProCaseCondiCount(data, caseIdx) {
        if (data == "" || !data.HasOwnProp("VariNameArr") || caseIdx < 1 || caseIdx > data.VariNameArr.Length)
            return 0
        return data.VariNameArr[caseIdx].Length
    }

    ; UI 固定 4 个条件槽（勾选 N 后显示 N+1，与「如果」节点一致）
    _IfProShowSlotCount(data, caseIdx) {
        return 4
    }

    ; 条件 slot 是否处于逐级展开链上（上一条件已启用才显示下一空槽）
    _IfProSlotChainOn(data, caseIdx, slot) {
        if (slot <= 1)
            return true
        return (slot - 1) <= this._IfProCaseCondiCount(data, caseIdx)
    }

    ; 单行控件行高（Margin 5 + 控件 22）
    _IfProRowEstH() {
        return 27
    }

    _IfProCondiCardEstH(data, caseIdx, slot) {
        if (!this._IfProSlotChainOn(data, caseIdx, slot))
            return 0
        cc := this._IfProCaseCondiCount(data, caseIdx)
        if (slot > cc + 1)
            return 0
        on := slot <= cc
        ; Border Margin 3 + Padding 2/4 + Border 2
        h := 3 + 2 + this._IfProRowEstH() + 4 + 2
        if (!on)
            return h
        cmp := (slot <= data.CompareTypeArr[caseIdx].Length) ? data.CompareTypeArr[caseIdx][slot] : 3
        h += this._IfProRowEstH() * 2
        if (cmp != 7)
            h += this._IfProRowEstH()
        return h
    }

    _IfProCaseSectionEstH(data, caseIdx) {
        ; Border Margin 6 + Padding 4/6 + Border 2
        h := 6 + 4 + 18 + 6 + 2
        cc := this._IfProCaseCondiCount(data, caseIdx)
        if (cc > 1)
            h += this._IfProRowEstH()
        loop 4 {
            slot := A_Index
            if (slot > cc + 1)
                break
            cardH := this._IfProCondiCardEstH(data, caseIdx, slot)
            if (cardH > 0)
                h += cardH
            else
                break
        }
        return Max(h, 40)
    }

    _IfProDefSectionEstH() {
        return 6 + 8 + 18 + 8 + 2
    }

    ; 各情况/默认分支出点中心 Y（相对节点顶边，整数像素；body 起始于 30+6=36）
    _IfProPortCenterY(data, branchIdx) {
        cc := this._IfProCaseCountFromData(data)
        y := 36
        if (branchIdx < cc) {
            ci := branchIdx + 1
            loop ci - 1
                y += this._IfProCaseSectionEstH(data, A_Index)
            y += this._IfProCaseSectionEstH(data, ci) // 2
            return y
        }
        loop cc
            y += this._IfProCaseSectionEstH(data, A_Index)
        y += this._IfProDefSectionEstH() // 2
        y -= 10  ; 末位「以上都不是」出点略上移，与 UI 对齐
        return y
    }

    _IfProPortMarginTop(data, branchIdx) {
        return this._IfProPortCenterY(data, branchIdx) - 37
    }

    _IfProBranchPathGeom(parentId, toId, px := "", py := "") {
        g := this.graph
        if (g == "")
            return ""
        pn := g.GetNode(parentId)
        bn := g.GetNode(toId)
        if (!pn || !bn)
            return ""
        pi := this._ProBranchInfo(toId)
        if (pi == "")
            return ""
        data := this._IfProData(parentId)
        if (data == "")
            return ""
        px := (px != "") ? px : pn.X
        py := (py != "") ? py : pn.Y
        nw := this._IfProNodeWidth()
        mt := this._IfProPortMarginTop(data, pi.idx)
        if (this._ifProPortMargin.Has(parentId) && this._ifProPortMargin[parentId].Length > pi.idx)
            mt := this._ifProPortMargin[parentId][pi.idx + 1]
        sy := py + 30 + mt + 7
        sx := px + nw
        return this._IfProBranchGeom(sx, sy, bn.X, bn.Y + 31)
    }

    _HookGraphIfProPaths() {
        g := this.graph
        if (g == "" || !IsObject(g))
            return
        ; 在 graph 上挂 MacroGraphGui 委托，由 XNodeGraph.UpdatePath 直接调用（避免 Func hook 参数限制）
        g._mgIfProGui := this
    }

    _IfProParsePathStartY(geom) {
        if (RegExMatch(geom, "^M(-?\d+),(-?\d+)", &m))
            return Integer(m[2])
        return ""
    }

    _SetIfProPathDragTag(pathId, parentId, sy) {
        if (this.ui == "" || pathId == "")
            return
        pn := this.graph.GetNode(parentId)
        if (!pn)
            return
        relY := Round(sy - pn.Y)
        this.ui.Update(pathId, "Tag", "ifproStartY:" relY)
    }

    _IsIfProBranchLink(fromId, toId) {
        if (!this._IsIfProNodeId(fromId) || !this._IsProBranchId(toId))
            return false
        pi := this._ProBranchInfo(toId)
        return pi != "" && pi.parentId == fromId && this._IsExpandedIfPro(fromId)
    }

    ; 由 XNodeGraph.UpdatePath 委托：已处理返回 true，否则 false 走默认路径
    _TryIfProUpdatePath(fromId, toId, pathId, initial := false, pathEl := "") {
        if (!this._IsIfProBranchLink(fromId, toId))
            return false
        this._ApplyIfProConnectionPath(fromId, toId, pathId, initial, pathEl)
        return true
    }

    _ApplyIfProConnectionPath(fromId, toId, pathId, initial := false, pathEl := "") {
        g := this.graph
        geom := this._IfProBranchPathGeom(fromId, toId)
        if (geom == "")
            return
        if (initial && pathEl != "") {
            g._SetConnPathData(pathId, geom, true, pathEl)
            sy := this._IfProParsePathStartY(geom)
            pn := g.GetNode(fromId)
            if (sy != "" && pn)
                pathEl.SetProp("Tag", "ifproStartY:" Round(sy - pn.Y))
        } else if (this.ui != "") {
            g._SetConnPathData(pathId, geom)
            sy := this._IfProParsePathStartY(geom)
            if (sy != "")
                this._SetIfProPathDragTag(pathId, fromId, sy)
        }
    }

    _HasSavedProBranchLayout(parentId) {
        if (!this.cmdNodes.Has(parentId))
            return false
        node := this.cmdNodes[parentId]
        return node.HasOwnProp("ProBranchOff") && node.ProBranchOff != ""
    }

    _ScheduleProBranchLayoutRestore(parentId, delay := 180) {
        SetTimer(this._DeferredRestoreProBranchLayout.Bind(this, parentId), -delay)
    }

    _DeferredRestoreProBranchLayout(parentId) {
        this._RestoreProBranchPositions(parentId)
        this._ScheduleIfProPathUpdate(parentId)
    }

    _RefreshIfProPortPositions(id) {
        if (this.ui == "")
            return
        data := this._IfProData(id)
        if (data == "")
            return
        count := this._IfProBranchCountFromData(data)
        margins := []
        loop count {
            idx := A_Index - 1
            mt := this._IfProPortMarginTop(data, idx)
            margins.Push(mt)
            this.ui.Update("ProBrPort_" id "_" idx, "Margin", "0," mt ",-7,0")
        }
        this._ifProPortMargin[id] := margins
        this._UpdateIfProBranchPaths(id)
    }

    ; 初始化时：无自定义偏移的分支 Y 与对应情况出点对齐（连线水平）；收/展及编辑后不再调用
    _AlignProBranchPositionsInit(parentId) {
        g := this.graph
        if (g == "" || this.ui == "" || !this._IsExpandedIfPro(parentId))
            return
        if (this._HasSavedProBranchLayout(parentId))
            return
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            if (this._SavedProBranchOffset(parentId, idx + 1) != "")
                continue
            brId := this._ProBranchId(parentId, idx)
            bp := this._ProBranchPos(parentId, idx)
            this.pos[brId] := bp
            x := bp.x + g.offsetX
            y := bp.y + g.offsetY
            bn := g.GetNode(brId)
            if (bn) {
                bn.X := x
                bn.Y := y
            }
            this.ui.Update("Node_" brId, "SetPosition", x "," y)
        }
    }

    ; 按 ProBranchOff 恢复各分支位置；无保存偏移时保留引擎当前坐标（不收/展拉回默认对齐）
    _RestoreProBranchPositions(parentId) {
        g := this.graph
        if (g == "" || this.ui == "" || !this._IsExpandedIfPro(parentId))
            return
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            brId := this._ProBranchId(parentId, idx)
            bn := g.GetNode(brId)
            if (this._SavedProBranchOffset(parentId, idx + 1) != "")
                bp := this._ProBranchPos(parentId, idx)
            else if (bn)
                bp := { x: bn.X - g.offsetX, y: bn.Y - g.offsetY }
            else
                bp := this._ProBranchPos(parentId, idx)
            this.pos[brId] := bp
            x := bp.x + g.offsetX
            y := bp.y + g.offsetY
            if (bn) {
                bn.X := x
                bn.Y := y
            }
            this.ui.Update("Node_" brId, "SetPosition", x "," y)
        }
    }

    _IfProBranchGeom(sx, sy, ex, ey) {
        sx := Round(sx), sy := Round(sy), ex := Round(ex), ey := Round(ey)
        if (Abs(sy - ey) <= 2)
            return Format("M{},{} L{},{}", sx, sy, ex, ey)
        dx := Max(Round(Abs(ex - sx) * 0.5), 40)
        return Format("M{},{} C{},{} {},{} {},{}", sx, sy, sx + dx, sy, ex - dx, ey, ex, ey)
    }

    _ScheduleIfProPathUpdate(parentId, px := "", py := "") {
        if (this.ui == "" || this.graph == "")
            return
        this._UpdateIfProBranchPaths(parentId, px, py)
    }

    _UpdateIfProBranchPaths(parentId, px := "", py := "") {
        g := this.graph
        if (g == "" || this.ui == "" || !this._IsExpandedIfPro(parentId))
            return
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            brId := this._ProBranchId(parentId, idx)
            pathId := g.id "_Path_" parentId "_" brId
            geom := this._IfProBranchPathGeom(parentId, brId, px, py)
            if (geom != "") {
                g._SetConnPathData(pathId, geom)
                sy := this._IfProParsePathStartY(geom)
                if (sy != "")
                    this._SetIfProPathDragTag(pathId, parentId, sy)
                g._PlaceConnArrow(brId, pathId)
            }
        }
    }

    _ApplyIfProPortOutVisibility(id) {
        if (this.ui == "")
            return
        expanded := this._IsExpandedIfPro(id)
        count := this._IfProBranchCountFromId(id)
        loop count
            this.ui.Update("ProBrPort_" id "_" (A_Index - 1), "Visibility", expanded ? "Visible" : "Collapsed")
        ; 展开/收起均保留标题栏标准出点；展开时若从此出点连到后续，会自动拆分到各情况分支
        this.ui.Update("Port_Out_" id, "Visibility", "Visible")
    }

    _CollectProBranchIds(parentId) {
        res := []
        loop 32 {
            brId := this._ProBranchId(parentId, A_Index - 1)
            has := this.pos.Has(brId)
            if (!has && this.graph != "")
                has := this.graph.GetNode(brId)
            if (has)
                res.Push(brId)
            else if (res.Length > 0)
                break
        }
        if (res.Length == 0) {
            count := this._IfProBranchCountFromId(parentId)
            loop count
                res.Push(this._ProBranchId(parentId, A_Index - 1))
        }
        return res
    }

    ; 在节点 Grid 右侧追加各情况出点（位于主节点外边框，与连线路径对齐）
    _AddIfProBranchPortEls(grid, id) {
        data := this._IfProData(id)
        if (data == "")
            return
        folded := this._NodeFolded(id)
        count := this._IfProBranchCountFromData(data)
        margins := []
        loop count {
            idx := A_Index - 1
            mt := this._IfProPortMarginTop(data, idx)
            margins.Push(mt)
            vis := folded ? "Collapsed" : "Visible"
            el := XAMLElement("Ellipse")
            el.Name("ProBrPort_" id "_" idx)
            el._Props["Width"] := "14", el._Props["Height"] := "14"
            el._Props["Fill"] := "#FF5722", el._Props["Stroke"] := "#333", el._Props["StrokeThickness"] := "1"
            el._Props["Grid.Row"] := "1", el._Props["VerticalAlignment"] := "Top", el._Props["HorizontalAlignment"] := "Right"
            ; Margin 必须用整数，否则中文区域设置下浮点会变成「0,77,5,-7,0」导致 XAML 解析失败、主节点注入消失
            el._Props["Margin"] := "0," mt ",-7,0"
            el._Props["Panel.ZIndex"] := "20", el._Props["Visibility"] := vis
            el._Props["IsHitTestVisible"] := "False", el._Props["Cursor"] := "Hand"
            grid._Children.Push(el)
        }
        this._ifProPortMargin[id] := margins
    }

    _IfProNodeWidth() {
        return 200
    }

    _IfProBranchDefaultDY(parentId, idx) {
        data := this._IfProData(parentId)
        if (data == "")
            return 40 + idx * 130
        return this._IfProPortCenterY(data, idx) - 31
    }

    _ParseProBranchOff(text) {
        res := []
        if (text == "")
            return res
        for part in StrSplit(text, ";") {
            if (part == "") {
                res.Push("")
                continue
            }
            xy := StrSplit(part, ",")
            if (xy.Length >= 2 && IsNumber(xy[1]) && IsNumber(xy[2]))
                res.Push({ dx: xy[1] + 0, dy: xy[2] + 0 })
            else
                res.Push("")
        }
        return res
    }

    _SavedProBranchOffset(parentId, idx) {
        if (!this.cmdNodes.Has(parentId))
            return ""
        node := this.cmdNodes[parentId]
        if (!node.HasOwnProp("ProBranchOff") || node.ProBranchOff == "")
            return ""
        arr := this._ParseProBranchOff(node.ProBranchOff)
        if (idx < 1 || idx > arr.Length)
            return ""
        off := arr[idx]
        return (off != "" && IsObject(off)) ? off : ""
    }

    _ProBranchPos(parentId, idx) {
        sp := this.pos.Has(parentId) ? this.pos[parentId] : { x: 200, y: 200 }
        rel := this._SavedProBranchOffset(parentId, idx + 1)
        if (rel != "")
            return { x: sp.x + rel.dx, y: sp.y + rel.dy }
        return { x: sp.x + this._IfProNodeWidth() + 100, y: sp.y + this._IfProBranchDefaultDY(parentId, idx) }
    }

    ; 分支拖动只更新引擎坐标时，从引擎节点反写逻辑坐标（供折叠保存 ProBranchOff）
    _FlushProBranchPosFromEngine(parentId) {
        g := this.graph
        if (g == "")
            return
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            brId := this._ProBranchId(parentId, A_Index - 1)
            bn := g.GetNode(brId)
            if (!bn)
                continue
            if (!this.pos.Has(brId))
                this.pos[brId] := { x: 0, y: 0 }
            this.pos[brId].x := bn.X - g.offsetX
            this.pos[brId].y := bn.Y - g.offsetY
        }
    }

    _StoreProBranchLayout(parentId, node, parentPos) {
        this._FlushProBranchPosFromEngine(parentId)
        parts := []
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            brId := this._ProBranchId(parentId, A_Index - 1)
            if (this.pos.Has(brId)) {
                bp := this.pos[brId]
                parts.Push((bp.x - parentPos.x) "," (bp.y - parentPos.y))
            } else
                parts.Push("")
        }
        node.ProBranchOff := parts.Length ? parts[1] : ""
        if (parts.Length > 1) {
            loop parts.Length {
                if (A_Index == 1)
                    continue
                node.ProBranchOff .= ";" parts[A_Index]
            }
        }
        succId := this._NearestSuccessorId(parentId)
        if (succId != "" && this.pos.Has(succId)) {
            sp := this.pos[succId]
            node.SuccDX := sp.x - parentPos.x
            node.SuccDY := sp.y - parentPos.y
        }
    }

    _ProBranchHeaderColor(idx, caseCount) {
        if (idx >= caseCount)
            return "#6A1B9A"
        return "#3949AB"
    }

    _ProBranchBorderColor(idx, caseCount) {
        return idx >= caseCount ? "#8E24AA" : "#5C6BC0"
    }

    _MakeProBranchBorderEl(parentId, idx, x, y, asFragment := false) {
        brId := this._ProBranchId(parentId, idx)
        cc := this._IfProCaseCountFromData(this._IfProData(parentId))
        headerColor := this._ProBranchHeaderColor(idx, cc)
        borderColor := this._ProBranchBorderColor(idx, cc)
        title := this._IfProBranchTitle(parentId, idx)

        border := XAMLElement("Border")
        if (asFragment)
            border.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation").SetProp("xmlns:x", "http://schemas.microsoft.com/winfx/2006/xaml")
        border.Name("Node_" brId).Background("{DynamicResource DropdownBg}").BorderBrush(borderColor).BorderThickness("1").CornerRadius("6").Width("200").Padding("0").Margin("0").SetProp("ClipToBounds", "False").SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        grid := border.Add("Grid")
        grid.Rows("28", "Auto")
        this._AddNodeSelRing(grid, brId)
        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background(headerColor).CornerRadius("5,5,0,0")
        hp := header.Add("StackPanel").Orientation("Horizontal").VerticalAlignment("Center").Margin("8,0")
        hp.Add("TextBlock").Text(title).Foreground("White").FontWeight("Bold").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
        body := grid.Add("StackPanel").Grid_Row(1).Margin("10,0,0,8")
        this._FillProBranchNodeBody(parentId, idx, body, brId)
        this._AddNodePorts(grid, brId)
        return border
    }

    _FillProBranchNodeBody(parentId, idx, body, brId) {
        startSerial := this._IfProBranchMacro(parentId, idx)
        cmds := this._BranchGraphCmds(startSerial)
        expanded := this._branchExpanded.Has(brId) && this._branchExpanded[brId]
        panel := body.Add("StackPanel").Name("SBChipsPanel_" brId)
        shown := expanded ? cmds.Length : Min(cmds.Length, this._BranchPreviewCount())
        chipW := this._BranchChipWidth()
        if (cmds.Length == 0) {
            panel.Add("TextBlock").Text("（" GetLang("空") "）").Foreground("#888888").FontSize(this._MGFontSize(11))
        } else {
            Loop shown {
                chip := panel.Add("Border").Background("#33000000").CornerRadius("3").Margin("0,2,0,0").Padding("5,2").Width(chipW).HorizontalAlignment("Left")
                chip.Add("TextBlock").Text(cmds[A_Index]).Foreground("{DynamicResource TextMain}").FontSize(this._MGFontSize(11)).TextWrapping("Wrap")
            }
        }
        btn := body.Add("Button").Name("SBExpand_" brId).Content(expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")")).FontSize(this._MGFontSize(10)).Height("20").Margin("0,4,0,0").Padding("6,0").HorizontalAlignment("Left")
        if (cmds.Length <= this._BranchPreviewCount())
            btn.Visibility("Collapsed")
        flowTypes := this._IfFlowTypes()
        ct := GetLang(this._IfProBranchControl(parentId, idx))
        fidx := this._IndexInLangArr(flowTypes, ct)
        if (fidx < 0)
            fidx := 0
        this._AddComboRow(body, "BrFlowRow_" brId, GetLang("流程控制："), "BrFlowCmb_" brId, flowTypes, fidx, true, true, "58", "120")
        body.Add("TextBlock").Text(GetLang("双击编辑分支")).Foreground("#888888").FontSize(this._MGFontSize(10)).Margin("0,4,0,0")
    }

    _BuildProBranchSet(parentId) {
        this._HookGraphIfProPaths()
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            this._BuildProBranchNode(parentId, idx)
            this.graph.AddConnection(parentId, this._ProBranchId(parentId, idx))
        }
    }

    _BuildProBranchNode(parentId, idx) {
        g := this.graph
        brId := this._ProBranchId(parentId, idx)
        bp := this._ProBranchPos(parentId, idx)
        this.pos[brId] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeProBranchBorderEl(parentId, idx, x, y, false)
        g.canvas._Children.Push(el)
        g.nodes.Push({ Id: brId, Title: this._IfProBranchTitle(parentId, idx), X: x, Y: y, W: 200, H: 60, Type: "Process" })
    }

    _InjectProBranchSet(parentId) {
        this._HookGraphIfProPaths()
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            this._InjectProBranchNode(parentId, idx)
            this._ActivateConnection(parentId, this._ProBranchId(parentId, idx))
        }
        this._branchInjected[parentId] := true
        this._ApplyIfProPortOutVisibility(parentId)
        if (!this._HasSavedProBranchLayout(parentId))
            this._AlignProBranchPositionsInit(parentId)
        SetTimer(() => this._RefreshIfProPortPositions(parentId), -100)
    }

    _InjectProBranchNode(parentId, idx) {
        g := this.graph
        brId := this._ProBranchId(parentId, idx)
        bp := this._ProBranchPos(parentId, idx)
        this.pos[brId] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeProBranchBorderEl(parentId, idx, x, y, true)
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(el.ToString()))
        g.nodes.Push({ Id: brId, Title: this._IfProBranchTitle(parentId, idx), X: x, Y: y, W: 200, H: 60, Type: "Process" })
        g.ui.OnEvent("Node_" brId, "SelectNode", ObjBindMethod(g, "OnSelectNode", brId))
        g.ui.OnEvent("Node_" brId, "CtrlSelectNode", ObjBindMethod(g, "OnCtrlSelectNode", brId))
        this._RegisterProBranchEvents(parentId, idx, true)
        SetTimer(this._FinishProBranchDragSetup.Bind(this, parentId, brId), -150)
    }

    _FinishProBranchDragSetup(parentId, brId) {
        g := this.graph
        if (g != "")
            g.ui.Update("Node_" brId, "EnableDrag", "grid=20")
        if (this._HasSavedProBranchLayout(parentId))
            this._ScheduleProBranchLayoutRestore(parentId, 30)
    }

    _OnProBranchDrag(parentId, brId, state, ctrl, event) {
        g := this.graph
        if (g != "")
            g.OnNodeMoved(brId, state, ctrl, event)
        if (!state.Has("DragCoords") || g == "")
            return
        parts := StrSplit(state["DragCoords"], ",")
        if (parts.Length >= 2) {
            if (!this.pos.Has(brId))
                this.pos[brId] := { x: 0, y: 0 }
            this.pos[brId].x := Number(parts[1]) - g.offsetX
            this.pos[brId].y := Number(parts[2]) - g.offsetY
            this._ScheduleIfProPathUpdate(parentId)
        }
    }

    _RegisterProBranchEvents(parentId, idx, runtime := false) {
        brId := this._ProBranchId(parentId, idx)
        this.ui.OnEvent("Node_" brId, "DragMove", this._OnProBranchDrag.Bind(this, parentId, brId))
        this.ui.OnEvent("Node_" brId, "SelectNode", this._OnProBranchClick.Bind(this, parentId, idx))
        this.ui.OnEvent("Node_" brId, "CtrlSelectNode", this._OnProBranchClick.Bind(this, parentId, idx))
        this._BindCtrl("SBExpand_" brId, "Click", this._OnProBranchToggleExpand.Bind(this, parentId, idx), runtime)
        this._TrackCtrl("BrFlowCmb_" brId, runtime)
        this._BindCtrl("BrFlowCmb_" brId, "SelectionChanged", this._OnProBranchFlowControl.Bind(this, parentId, idx), runtime)
    }

    _OnProBranchClick(parentId, idx, *) {
        now := A_TickCount
        bkey := "PBR_" parentId "_" idx
        if (this._lastClickId == bkey && now - this._lastClickTime < 400) {
            this._lastClickId := ""
            this._lastClickTime := 0
            this._OpenProBranchEditor(parentId, idx)
        } else {
            this._lastClickId := bkey
            this._lastClickTime := now
        }
    }

    _OnProBranchToggleExpand(parentId, idx, *) {
        brId := this._ProBranchId(parentId, idx)
        nv := !(this._branchExpanded.Has(brId) && this._branchExpanded[brId])
        this._branchExpanded[brId] := nv
        cmds := this._BranchGraphCmds(this._IfProBranchMacro(parentId, idx))
        this._RebuildBranchChips(brId, cmds, nv)
        this.ui.Update("SBExpand_" brId, "Content", nv ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
    }

    _OpenProBranchEditor(parentId, idx) {
        if (this.BranchGraphGui == "")
            this.BranchGraphGui := MacroGraphGui()
        cur := this._IfProBranchMacro(parentId, idx)
        this.BranchGraphGui.OwnerHwnd := (this.ui != "" && this.ui.wpfHwnd) ? this.ui.wpfHwnd : ""
        this.BranchGraphGui.SureBtnAction := (startSerial) => this._OnProBranchEditorSure(parentId, idx, startSerial)
        this.BranchGraphGui.OnClosedAction := (*) => this._RefreshProBranchBody(parentId, idx)
        this.BranchGraphGui.ShowGui(cur)
    }

    _OnProBranchEditorSure(parentId, idx, startSerial) {
        data := this._IfProData(parentId)
        if (data == "")
            return
        cc := this._IfProCaseCountFromData(data)
        if (idx < cc)
            data.MacroArr[idx + 1] := startSerial
        else
            data.DefaultMacro := startSerial
        SaveMacroCMDData(data)
    }

    _RefreshProBranchBody(parentId, idx) {
        if (this.ui == "" || !this._branchInjected.Has(parentId))
            return
        brId := this._ProBranchId(parentId, idx)
        cmds := this._BranchGraphCmds(this._IfProBranchMacro(parentId, idx))
        expanded := this._branchExpanded.Has(brId) && this._branchExpanded[brId]
        this._RebuildBranchChips(brId, cmds, expanded)
        this.ui.Update("SBExpand_" brId, "Visibility", cmds.Length > this._BranchPreviewCount() ? "Visible" : "Collapsed")
        this.ui.Update("SBExpand_" brId, "Content", expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
        flowTypes := this._IfFlowTypes()
        ct := GetLang(this._IfProBranchControl(parentId, idx))
        fidx := this._IndexInLangArr(flowTypes, ct)
        if (fidx < 0)
            fidx := 0
        this.ui.Update("BrFlowCmb_" brId, "SelectedIndex", fidx)
    }

    _OnProBranchFlowControl(parentId, idx, state, ctrl, event) {
        data := this._IfProData(parentId)
        if (data == "")
            return
        brId := this._ProBranchId(parentId, idx)
        key := "BrFlowCmb_" brId
        flowTypes := this._IfFlowTypes()
        if (!state.Has(key) || state[key] == "")
            return
        val := GetLangKey(state[key])
        cc := this._IfProCaseCountFromData(data)
        if (idx < cc)
            data.ControlTypeArr[idx + 1] := val
        else
            data.DefaultControlType := val
        SaveMacroCMDData(data)
        this._Apply()
    }

    _InjectBranches(parentId) {
        if (this._IsIfProNodeId(parentId))
            this._InjectProBranchSet(parentId)
        else
            this._InjectBranchPair(parentId)
    }

    _BuildBranches(parentId) {
        if (this._IsIfProNodeId(parentId))
            this._BuildProBranchSet(parentId)
        else
            this._BuildBranchPair(parentId)
    }

    _RemoveProBranchNodesRuntime(parentId) {
        g := this.graph
        if (g == "")
            return
        brIds := this._CollectProBranchIds(parentId)
        brSet := Map()
        for brId in brIds {
            brSet[brId] := true
            pi := this._ProBranchInfo(brId)
            if (pi != "" && this.ui != "")
                this.ui.Update("ProBrPort_" parentId "_" pi.idx, "Visibility", "Collapsed")
            g.ui.Update("Node_" brId, "Visibility", "Collapsed")
            g.ui.Update("Port_In_" brId, "Visibility", "Collapsed")
            g.ui.Update("Port_Out_" brId, "Visibility", "Collapsed")
            if (this.pos.Has(brId))
                this.pos.Delete(brId)
            if (g.selectedNodes.Has(brId))
                g.selectedNodes.Delete(brId)
        }
        keep := []
        for conn in g.connections {
            drop := brSet.Has(conn.From) || brSet.Has(conn.To) || (conn.From == parentId && brSet.Has(conn.To))
            if (drop)
                g.SetConnVisible(conn.PathId, "Collapsed")
            else
                keep.Push(conn)
        }
        g.connections := keep
        nkeep := []
        for n in g.nodes {
            if (!brSet.Has(n.Id))
                nkeep.Push(n)
        }
        g.nodes := nkeep
        if (this._branchInjected.Has(parentId))
            this._branchInjected.Delete(parentId)
        if (this._ifProPortMargin.Has(parentId))
            this._ifProPortMargin.Delete(parentId)
    }

    _ShiftProBranchNodes(parentId, dx) {
        if (dx == 0 || !this._IsExpandedIfPro(parentId))
            return
        g := this.graph
        if (g == "")
            return
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            brId := this._ProBranchId(parentId, A_Index - 1)
            if (this.pos.Has(brId) && g.GetNode(brId))
                this._ShiftNodeX(brId, dx)
        }
        for conn in g.connections {
            if (conn.From == parentId || this._IsProBranchId(conn.From) || this._IsProBranchId(conn.To))
                g.UpdatePath(conn.From, conn.To, conn.PathId)
        }
        this._ScheduleIfProPathUpdate(parentId)
    }

    _ProBranchIndices(parentId) {
        res := []
        count := this._IfProBranchCountFromId(parentId)
        loop count
            res.Push(A_Index - 1)
        return res
    }

    _ConnInvolvesParentBranch(conn, parentId) {
        if (this._ConnInvolvesSearchBranch(conn, parentId))
            return true
        bf := this._ProBranchInfo(conn.From)
        bt := this._ProBranchInfo(conn.To)
        if (bf != "" && bf.parentId == parentId)
            return true
        if (bt != "" && bt.parentId == parentId)
            return true
        return false
    }

    _FoldIfProRuntime(parentId) {
        g := this.graph
        if (g == "")
            return
        this._CaptureLinks()
        if (this.cmdNodes.Has(parentId)) {
            node := this.cmdNodes[parentId]
            pp := this.pos.Has(parentId) ? this.pos[parentId] : { x: 0, y: 0 }
            this._StoreProBranchLayout(parentId, node, pp)
            try SaveMacroCMDData(node)
        }
        succ := this._SuccessorsOf(parentId)
        for conn in g.connections {
            if (this._ConnInvolvesParentBranch(conn, parentId))
                this._DeactivateConnection(conn)
        }
        count := this._IfProBranchCountFromId(parentId)
        loop count
            this.ui.Update("Node_" this._ProBranchId(parentId, A_Index - 1), "Visibility", "Collapsed")
        loop count
            this.ui.Update("ProBrPort_" parentId "_" (A_Index - 1), "Visibility", "Collapsed")
        for x in succ
            this._ActivateConnection(parentId, x)
        this._CaptureLinks()
        this._SpreadForCollapse(parentId)
        this._RebindPathClicks()
    }

    _UnfoldIfProRuntime(parentId) {
        g := this.graph
        if (g == "")
            return
        this._CaptureLinks()
        succ := this._SuccessorsOf(parentId)
        for conn in g.connections {
            if (conn.From == parentId && !this._IsBranchId(conn.To) && !this._IsProBranchId(conn.To))
                this._DeactivateConnection(conn)
        }
        if (!this._branchInjected.Has(parentId)) {
            this._InjectProBranchSet(parentId)
        } else {
            this._RestoreProBranchPositions(parentId)
            count := this._IfProBranchCountFromId(parentId)
            loop count {
                idx := A_Index - 1
                brId := this._ProBranchId(parentId, idx)
                this.ui.Update("Node_" brId, "Visibility", "Visible")
                this._ActivateConnection(parentId, brId)
            }
        }
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            idx := A_Index - 1
            brId := this._ProBranchId(parentId, idx)
            for x in succ
                this._ActivateConnection(brId, x)
        }
        loop count
            this.ui.Update("ProBrPort_" parentId "_" (A_Index - 1), "Visibility", "Visible")
        this._ApplyIfProPortOutVisibility(parentId)
        this._RestoreProBranchPositions(parentId)
        this._SpreadForExpand(parentId)
        this._NormalizeBranchConnections()
        this._RebindPathClicks()
        this._ScheduleIfProPathUpdate(parentId)
        this._ScheduleProBranchLayoutRestore(parentId)
    }

    _OnToggleIfProFold(id, *) {
        if (this.ui == "" || !this.cmdNodes.Has(id))
            return
        node := this.cmdNodes[id]
        willFold := this._NodeFolded(id) ? 0 : 1
        if (willFold && this._IsExpandedIfPro(id)) {
            pp := this.pos.Has(id) ? this.pos[id] : { x: 0, y: 0 }
            this._FlushProBranchPosFromEngine(id)
            this._StoreProBranchLayout(id, node, pp)
        }
        node.Folded := willFold
        try SaveMacroCMDData(node)
        if (willFold) {
            this._RefreshIfProSummary(id)
            this._FoldIfProRuntime(id)
        } else {
            this._UnfoldIfProRuntime(id)
        }
        cc := this._IfProCaseCountFromData(this._IfProData(id))
        loop cc {
            ci := A_Index
            this.ui.Update("IfProC" ci "Full_" id, "Visibility", willFold ? "Collapsed" : "Visible")
            this.ui.Update("IfProC" ci "Sum_" id, "Visibility", willFold ? "Visible" : "Collapsed")
        }
        this._ApplyIfProPortOutVisibility(id)
        this.ui.Update("SFold_" id, "Content", willFold ? "▶" : "▼")
        this.ui.Update("SFold_" id, "ToolTip", willFold ? GetLang("展开") : GetLang("收起"))
        this._CaptureLinks()
    }

    ; 分支数量变化后重建外置分支节点（ComparePro 编辑器确定后调用）
    _RebuildIfProBranches(parentId) {
        if (this.ui == "" || !this._IsIfProNodeId(parentId) || this._NodeFolded(parentId))
            return
        this._RemoveProBranchNodesRuntime(parentId)
        this._InjectProBranchSet(parentId)
        succ := this._SuccessorsOf(parentId)
        count := this._IfProBranchCountFromId(parentId)
        loop count {
            brId := this._ProBranchId(parentId, A_Index - 1)
            for x in succ
                this._ActivateConnection(brId, x)
        }
        this._NormalizeBranchConnections()
        this._RebindPathClicks()
        this._RestoreProBranchPositions(parentId)
        this._ScheduleIfProPathUpdate(parentId)
        this._ScheduleProBranchLayoutRestore(parentId)
    }

    _IfProCmpTypes() {
        return this._LoopCmpTypes()
    }

    _IfProLogicTypes() {
        return this._LoopLogicTypes()
    }

    _IfProCondiSummaryRow(data, caseIdx, slot) {
        res := { on: false, text: "" }
        if (data == "" || caseIdx < 1 || caseIdx > data.VariNameArr.Length)
            return res
        condiN := data.VariNameArr[caseIdx].Length
        if (slot < 1 || slot > condiN)
            return res
        res.on := true
        cmpTypes := GetLangArr(["大于", "大于等于", "等于", "小于等于", "小于", "字符包含", "变量存在", "正则匹配"])
        nm := GetLang(data.VariNameArr[caseIdx][slot])
        cmp := data.CompareTypeArr[caseIdx][slot]
        typeStr := (cmp >= 1 && cmp <= cmpTypes.Length) ? cmpTypes[cmp] : cmpTypes[3]
        res.text := (cmp != 7) ? nm " " typeStr " " GetLang(data.VariableArr[caseIdx][slot]) : nm " " typeStr
        return res
    }

    _IfProCaseLogicSummary(data, caseIdx) {
        condiN := data.VariNameArr[caseIdx].Length
        if (condiN <= 1)
            return { show: false, text: "" }
        logicTypes := this._IfProLogicTypes()
        lt := data.LogicTypeArr[caseIdx]
        logicName := (lt >= 1 && lt <= logicTypes.Length) ? logicTypes[lt] : logicTypes[1]
        return { show: true, text: GetLang("逻辑关系：") logicName }
    }

    _FillIfProCaseSummaryRows(box, id, caseIdx, data) {
        fs := this._MGFontSize(11)
        fg := "#9FA8DA"
        logic := this._IfProCaseLogicSummary(data, caseIdx)
        lRow := box.Add("TextBlock").Name("IfProSumLogic_" caseIdx "_" id).Text(logic.text).Foreground("#C5CAE9").FontSize(this._MGFontSize(12)).Margin("0,4,0,0").TextWrapping("Wrap")
        if (!logic.show)
            lRow.Visibility("Collapsed")
        condiN := data.VariNameArr[caseIdx].Length
        loop condiN {
            slot := A_Index
            info := this._IfProCondiSummaryRow(data, caseIdx, slot)
            row := box.Add("StackPanel").Name("IfProSumRow_" caseIdx "_" slot "_" id).Orientation("Horizontal").Margin("0,5,0,0")
            if (!info.on)
                row.Visibility("Collapsed")
            row.Add("Ellipse").Width("7").Height("7").Fill("#5C9DED").Margin("0,0,6,0").VerticalAlignment("Center")
            row.Add("TextBlock").Name("IfProSumTxt_" caseIdx "_" slot "_" id).Text(info.text).Foreground(fg).FontSize(fs).VerticalAlignment("Center").TextWrapping("Wrap")
        }
    }

    _RefreshIfProSummary(id) {
        if (this.ui == "")
            return
        data := this._IfProData(id)
        if (data == "")
            return
        cc := this._IfProCaseCountFromData(data)
        loop cc {
            ci := A_Index
            logic := this._IfProCaseLogicSummary(data, ci)
            this.ui.Update("IfProSumLogic_" ci "_" id, "Text", logic.text)
            this.ui.Update("IfProSumLogic_" ci "_" id, "Visibility", logic.show ? "Visible" : "Collapsed")
            condiN := data.VariNameArr[ci].Length
            loop condiN {
                slot := A_Index
                info := this._IfProCondiSummaryRow(data, ci, slot)
                this.ui.Update("IfProSumRow_" ci "_" slot "_" id, "Visibility", info.on ? "Visible" : "Collapsed")
                this.ui.Update("IfProSumTxt_" ci "_" slot "_" id, "Text", info.text)
            }
        }
    }

    _FillIfProCondiSlot(inner, id, caseIdx, slot, data, showRow, showVal) {
        lw := "44", cw := "100"
        p := "IfProC" caseIdx "S" slot
        nm := (slot <= data.VariNameArr[caseIdx].Length) ? data.VariNameArr[caseIdx][slot] : ("Var" slot)
        cmp := (slot <= data.CompareTypeArr[caseIdx].Length) ? data.CompareTypeArr[caseIdx][slot] : 3
        vr := (slot <= data.VariableArr[caseIdx].Length) ? data.VariableArr[caseIdx][slot] : ("Var" slot)
        on := slot <= data.VariNameArr[caseIdx].Length
        cmpTypes := this._IfProCmpTypes()
        card := inner.Add("Border").Name(p "Row_" id).BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("3").Background("{DynamicResource InputBg}").Margin("0,3,0,0").Padding("4,2,4,4")
        if (!showRow)
            card.Visibility("Collapsed")
        stk := card.Add("StackPanel")
        this._AddCheckRow(stk, p "TogChk_" id, p "Tog_" id, GetLang("条件") slot, on, true)
        this._AddEditableComboRow(stk, p "NameRow_" id, GetLang("变量："), p "Name_" id, GetGuiVarArr(), GetLang(nm), on && showRow, lw, cw)
        this._AddComboRow(stk, p "CmpRow_" id, GetLang("比较："), p "Cmp_" id, cmpTypes, cmp - 1, on && showRow, true, lw, cw)
        this._AddEditableComboRow(stk, p "VarRow_" id, GetLang("值："), p "Var_" id, GetGuiVarArr(), GetLang(vr), on && showRow && showVal, lw, cw)
    }

    _FillIfProCaseSection(body, id, caseIdx, data, folded := "") {
        if (folded == "")
            folded := this._NodeFolded(id)
        p := "IfProC" caseIdx
        fs := this._MGFontSize(12)
        sec := body.Add("Border").Name(p "Sec_" id).BorderBrush("#5C6BC0").BorderThickness("1.5").CornerRadius("6").Background("#2E2E45").Margin("0,6,0,0").Padding("6,4,6,6")
        wrap := sec.Add("StackPanel")
        innerFull := wrap.Add("StackPanel").Name(p "Full_" id)
        innerFull.Visibility(folded ? "Collapsed" : "Visible")
        innerFull.Add("TextBlock").Text("情况" caseIdx).Foreground("#C5CAE9").FontWeight("Bold").FontSize(fs)
        cc := this._IfProCaseCondiCount(data, caseIdx)
        logicTypes := this._IfProLogicTypes()
        lt := data.LogicTypeArr[caseIdx]
        showLogic := cc > 1
        this._AddComboRow(innerFull, p "LogicRow_" id, GetLang("逻辑关系："), p "LogicCmb_" id, logicTypes, Max(0, lt - 1), showLogic, true, "58", "96")
        prevOn := true
        loop 4 {
            slot := A_Index
            chainVis := (slot == 1) ? true : prevOn
            on := slot <= cc
            cmp := (slot <= data.CompareTypeArr[caseIdx].Length) ? data.CompareTypeArr[caseIdx][slot] : 3
            this._FillIfProCondiSlot(innerFull, id, caseIdx, slot, data, chainVis, cmp != 7)
            prevOn := chainVis && on
        }
        innerSum := wrap.Add("StackPanel").Name(p "Sum_" id)
        innerSum.Visibility(folded ? "Visible" : "Collapsed")
        innerSum.Add("TextBlock").Text("情况" caseIdx).Foreground("#C5CAE9").FontWeight("Bold").FontSize(fs)
        this._FillIfProCaseSummaryRows(innerSum, id, caseIdx, data)
    }

    _FillIfProDefaultSection(body, id, data, folded := "") {
        fs := this._MGFontSize(12)
        sec := body.Add("Border").Name("IfProDefSec_" id).BorderBrush("#8E24AA").BorderThickness("1").CornerRadius("5").Background("#2A2438").Margin("0,6,0,0").Padding("6,8,6,8")
        inner := sec.Add("StackPanel")
        inner.Add("TextBlock").Text(GetLang("以上都不是")).Foreground("#E1BEE7").FontWeight("Bold").FontSize(fs)
    }

    _FillIfProBody(id, d, body) {
        data := this._IfProData(id)
        if (data == "")
            return
        folded := this._NodeFolded(id)
        secBox := body.Add("StackPanel").Name("IfProSecBox_" id)
        cc := this._IfProCaseCountFromData(data)
        loop cc
            this._FillIfProCaseSection(secBox, id, A_Index, data, folded)
        this._FillIfProDefaultSection(secBox, id, data, folded)
        this._AddFormalHint(body)
        this._ifProUiCaseCount[id] := cc
    }
}

_GraftMacroGraphMixin(MacroGraphIfProMixin)
