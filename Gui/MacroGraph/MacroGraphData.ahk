#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 数据 / 持久化 / 解析
;
; 节点克隆（移动Pro/搜索/分支子图深拷贝）、图结构保存与复原、CurCMD 解析与重建。
; 方法体保持原样，this 仍为 MacroGraphGui 实例，通过 _GraftMacroGraphMixin
; 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphDataMixin {
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
                ; 展开态布局信息一并深拷贝，保持分支位置稳定
                for layoutProp in ["TrueBranchDX", "TrueBranchDY", "FalseBranchDX", "FalseBranchDY", "ExpandShift", "SuccDX", "SuccDY"] {
                    if (nd.HasOwnProp(layoutProp))
                        cp.%layoutProp% := nd.%layoutProp%
                }
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
            ; 展开的搜索节点：持久化真/假分支相对偏移 + 展开位移，重载/收展时布局稳定
            this._StoreBranchLayout(id, node, p)
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

    ; 把展开搜索节点的分支相对位置、最近后继相对偏移(SuccDX/DY)写入其 MacroGraphNode（供重载/收展时还原）。
    ; 折叠态：分支不存在，保留既有的分支偏移与后继偏移记忆（勿覆盖），仅清空已弃用的 ExpandShift。
    _StoreBranchLayout(searchId, node, searchPos) {
        if (this._IsExpandedSearch(searchId)) {
            for isTrue in [true, false] {
                brId := this._BranchId(searchId, isTrue)
                if (!this.pos.Has(brId))
                    continue
                bp := this.pos[brId]
                if (isTrue) {
                    node.TrueBranchDX := bp.x - searchPos.x
                    node.TrueBranchDY := bp.y - searchPos.y
                } else {
                    node.FalseBranchDX := bp.x - searchPos.x
                    node.FalseBranchDY := bp.y - searchPos.y
                }
            }
            node.ExpandShift := ""
            ; 记录「最近后继(下一个)节点」相对搜索节点的偏移，供收起→展开时精确还原后继位置
            succId := this._NearestSuccessorId(searchId)
            if (succId != "" && this.pos.Has(succId)) {
                sp := this.pos[succId]
                node.SuccDX := sp.x - searchPos.x
                node.SuccDY := sp.y - searchPos.y
            } else {
                node.SuccDX := ""
                node.SuccDY := ""
            }
        } else {
            ; 折叠态：分支不存在、后继处于收起态小间距；保留既有 SuccDX/SuccDY(展开布局记忆)与分支偏移，勿覆盖
            node.ExpandShift := ""
        }
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
            ; 还原展开态布局信息（分支相对偏移 + 展开位移 + 后继相对位置）；缺失则保持默认 ""
            for layoutProp in ["TrueBranchDX", "TrueBranchDY", "FalseBranchDX", "FalseBranchDY", "ExpandShift", "SuccDX", "SuccDY"] {
                if (IsObject(nodeData) && nodeData.HasOwnProp(layoutProp))
                    node.%layoutProp% := nodeData.%layoutProp%
            }
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
}

_GraftMacroGraphMixin(MacroGraphDataMixin)
