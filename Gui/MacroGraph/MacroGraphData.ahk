#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 数据 / 持久化 / 解析
;
; 节点克隆（移动Pro/搜索/分支子图深拷贝）、图结构保存与复原、CurCMD 解析与重建。
; 方法体保持原样，this 仍为 MacroGraphGui 实例，通过 _GraftMacroGraphMixin
; 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

; 解析结果对象基类：让普通对象同时支持 d.fixedProp（点）与 d["dynKey" i]（中括号）访问。
; AHK v2 的对象字面量默认不支持中括号取值（无 __Item），会抛 "no property named __Item"，
; 导致 _MapIniDataToParse 里 d["toggle" i]:=... 静默失败（被 _Parse 的 try 吞掉），
; 进而变量/运算等节点解析恒为默认值。设此基类后中括号读写统一映射到自身属性。
class MGParseObjBase {
    __Item[key] {
        get => this.HasOwnProp(key) ? this.%key% : ""
        set => this.%key% := value
    }
}

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
                for layoutProp in ["TrueBranchDX", "TrueBranchDY", "FalseBranchDX", "FalseBranchDY", "ExpandShift", "SuccDX", "SuccDY", "ProBranchOff"] {
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

    ; 克隆一个输入序列：新建序列码并把源数据各字段复制过去，返回新的 CurCMD(序列码)
    _CloneInput(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        newSerial := GetCMDSerialStr("输入")
        newData := InputData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                for prop in src.OwnProps() {
                    if (prop == "SerialStr")
                        continue
                    newData.%prop% := src.%prop%
                }
            }
        }
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 克隆一个输出序列：新建序列码并把源数据各字段复制过去，返回新的 CurCMD(序列码)
    _CloneOutput(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        newSerial := GetCMDSerialStr("输出")
        newData := OutputData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                for prop in src.OwnProps() {
                    if (prop == "SerialStr")
                        continue
                    newData.%prop% := src.%prop%
                }
            }
        }
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 形式化 INI 指令的 cmdKey 列表（与 AssetUtil 中 CMD 映射一致）
    _FormalIniCmdKeys() {
        return ["宏操作", "变量", "变量提取", "如果", "如果Pro", "运算", "运行", "文件读写", "文本处理", "数组",
            "后台鼠标", "后台按键", "窗口管理", "按键检测", "抓图", "循环"]
    }

    _FormalIniKeyFromName(name) {
        if (name == "")
            return ""
        base := RegExReplace(name, "\d+$", "")
        for key in this._FormalIniCmdKeys() {
            if (base == GetLang(key))
                return key
        }
        return ""
    }

    _FormalIniDataClass(cmdKey) {
        static m := ""
        if (m == "") {
            m := Map(
                "宏操作", SubMacroData,
                "变量", VariableData,
                "变量提取", ExVariableData,
                "如果", CompareData,
                "如果Pro", CompareProData,
                "运算", OperationData,
                "运行", RunData,
                "文件读写", FileIOData,
                "文本处理", TextOpsData,
                "数组", ArrayData,
                "后台鼠标", BGMouseData,
                "后台按键", BGKeyData,
                "窗口管理", WindowManageData,
                "按键检测", KeyCheckData,
                "抓图", ScreenShotData,
                "循环", LoopData
            )
        }
        return m.Has(cmdKey) ? m[cmdKey] : ""
    }

    ; 克隆形式化 INI 指令：新建序列码并复制源 INI 数据
    _CloneFormalIni(srcCmd, cmdKey) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        cls := this._FormalIniDataClass(cmdKey)
        if (cls == "")
            return srcCmd
        newSerial := GetCMDSerialStr(cmdKey)
        ; 用 .Clone() 整体复制源数据（应用通用机制，最可靠），再对数组逐个深拷贝，
        ; 避免新旧节点共享同一份配置；克隆失败再回退默认对象。
        newData := ""
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                newData := src.Clone()
                for prop in newData.OwnProps() {
                    val := newData.%prop%
                    if (val is Array)
                        newData.%prop% := val.Clone()
                }
            }
        }
        if (!IsObject(newData))
            newData := cls()
        newData.SerialStr := newSerial
        if (cmdKey == "如果") {
            newData.TrueMacro := this._CloneBranchGraph(newData.HasOwnProp("TrueMacro") ? newData.TrueMacro : "")
            newData.FalseMacro := this._CloneBranchGraph(newData.HasOwnProp("FalseMacro") ? newData.FalseMacro : "")
        }
        if (cmdKey == "如果Pro") {
            if (newData.HasOwnProp("MacroArr") && IsObject(newData.MacroArr)) {
                loop newData.MacroArr.Length
                    newData.MacroArr[A_Index] := this._CloneBranchGraph(newData.MacroArr[A_Index])
            }
            if (newData.HasOwnProp("DefaultMacro"))
                newData.DefaultMacro := this._CloneBranchGraph(newData.DefaultMacro)
        }
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 克隆一个如果序列：新建序列码并把源数据各字段复制过去，真/假分支子图深拷贝
    _CloneIf(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        newSerial := GetCMDSerialStr("如果")
        newData := CompareData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                for prop in src.OwnProps() {
                    if (prop == "SerialStr")
                        continue
                    newData.%prop% := src.%prop%
                }
            }
        }
        newData.TrueMacro := this._CloneBranchGraph(newData.HasOwnProp("TrueMacro") ? newData.TrueMacro : "")
        newData.FalseMacro := this._CloneBranchGraph(newData.HasOwnProp("FalseMacro") ? newData.FalseMacro : "")
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 克隆一个如果Pro序列：新建序列码并深拷贝各分支子图
    _CloneComparePro(srcCmd) {
        srcArr := SplitCommand(srcCmd)
        srcSerial := srcArr.Length >= 1 ? srcArr[1] : srcCmd
        newSerial := GetCMDSerialStr("如果Pro")
        newData := CompareProData()
        newData.SerialStr := newSerial
        try {
            src := GetMacroCMDData(srcSerial)
            if (IsObject(src)) {
                for prop in src.OwnProps() {
                    if (prop == "SerialStr")
                        continue
                    val := src.%prop%
                    if (val is Array) {
                        cp := []
                        for item in val {
                            if (item is Array)
                                cp.Push(item.Clone())
                            else
                                cp.Push(item)
                        }
                        newData.%prop% := cp
                    } else
                        newData.%prop% := val
                }
            }
        }
        if (newData.HasOwnProp("MacroArr") && IsObject(newData.MacroArr)) {
            loop newData.MacroArr.Length
                newData.MacroArr[A_Index] := this._CloneBranchGraph(newData.MacroArr[A_Index])
        }
        if (newData.HasOwnProp("DefaultMacro"))
            newData.DefaultMacro := this._CloneBranchGraph(newData.DefaultMacro)
        SaveMacroCMDData(newData)
        return newSerial
    }

    ; 将 INI 数据对象的属性复制到解析结果 d（camelCase 字段名）
    _MapIniDataToParse(d, data, cmdKey) {
        if (!IsObject(data))
            return
        if (cmdKey == "宏操作") {
            d.macroType := data.MacroType
            d.callType := data.CallType
            d.insertCount := data.InsertCount
            d.index := data.Index
            d.macroSerial := data.MacroSerial
        } else if (cmdKey == "变量") {
            d.isIgnoreExist := data.IsIgnoreExist
            loop 4 {
                i := A_Index
                d["toggle" i] := data.ToggleArr[i]
                d["operaType" i] := data.OperaTypeArr[i]
                d["variable" i] := data.VariableArr[i]
                d["copyVar" i] := data.CopyVariableArr[i]
                d["minVar" i] := data.MinVariableArr[i]
                d["maxVar" i] := data.MaxVariableArr[i]
            }
        } else if (cmdKey == "变量提取") {
            d.isIgnoreExist := data.IsIgnoreExist
            d.extractType := data.ExtractType
            d.extractStr := data.ExtractStr
            d.winInfo := data.WinInfo
            d.ocrType := data.OCRType
            d.startPosX := data.StartPosX
            d.startPosY := data.StartPosY
            d.endPosX := data.EndPosX
            d.endPosY := data.EndPosY
            d.searchCount := data.SearchCount
            d.searchInterval := data.SearchInterval
            loop 6 {
                i := A_Index
                d["exToggle" i] := data.ToggleArr[i]
                d["exVariable" i] := data.VariableArr[i]
            }
        } else if (cmdKey == "如果") {
            d.logicType := data.LogicalType
            d.trueControlType := data.TrueControlType
            d.falseControlType := data.FalseControlType
            d.trueMacro := data.TrueMacro
            d.falseMacro := data.FalseMacro
            d.saveToggle := data.SaveToggle
            d.saveName := data.SaveName
            d.trueValue := data.TrueValue
            d.falseValue := data.FalseValue
            loop 4 {
                i := A_Index
                d["ifTog" i] := data.ToggleArr[i]
                d["ifName" i] := data.NameArr[i]
                d["ifCmp" i] := data.CompareTypeArr[i]
                d["ifVar" i] := data.VariableArr[i]
            }
        } else if (cmdKey == "如果Pro") {
            d.proCaseCount := data.VariNameArr.Length
            d.proDefaultMacro := data.DefaultMacro
            d.proDefaultControl := data.DefaultControlType
            loop data.VariNameArr.Length {
                ci := A_Index
                d["proLogic" ci] := data.LogicTypeArr[ci]
                d["proMacro" ci] := data.MacroArr[ci]
                d["proControl" ci] := data.ControlTypeArr[ci]
                loop data.VariNameArr[ci].Length {
                    si := A_Index
                    d["proVar" ci "_" si] := data.VariNameArr[ci][si]
                    d["proCmp" ci "_" si] := data.CompareTypeArr[ci][si]
                    d["proVal" ci "_" si] := data.VariableArr[ci][si]
                }
                d["proCondiCount" ci] := data.VariNameArr[ci].Length
            }
        } else if (cmdKey == "运算") {
            loop 4 {
                i := A_Index
                d["opToggle" i] := data.ToggleArr[i]
                d["updateName" i] := data.UpdateNameArr[i]
                d["expression" i] := data.ExpressionArr[i]
            }
        } else if (cmdKey == "运行") {
            d.runTarget := data.Target
            d.runMode := data.Mode
            d.option := ObjHasOwnProp(data, "Option") ? data.Option : 1
            d.stdin := ObjHasOwnProp(data, "StdIn") ? data.StdIn : ""
            d.encIn  := (ObjHasOwnProp(data, "Encoding") && ObjHasOwnProp(data.Encoding, "In"))  ? data.Encoding.In  : "UTF-8"
            d.encOut := (ObjHasOwnProp(data, "Encoding") && ObjHasOwnProp(data.Encoding, "Out")) ? data.Encoding.Out : "UTF-8"
            loop 3 {
                if (ObjHasOwnProp(data, "SaveNameArr") && data.SaveNameArr.Length >= A_Index)
                    d["runSave" A_Index] := data.SaveNameArr[A_Index]
                else
                    d["runSave" A_Index] := (A_Index == 1 ? "ExitCode" : (A_Index == 2 ? "StdOut" : "StdErr"))
            }
        } else if (cmdKey == "文件读写") {
            d.operType := data.OperType
            d.operMode := data.OperMode
            d.encoding := data.Encoding
            d.filePath := data.FilePath
            d.nameOrSerial := data.NameOrSerial
            d.rowVar := data.RowVar
            d.colVar := data.ColVar
            d.rowEndVar := data.RowEndVar
            d.colEndVar := data.ColEndVar
            d.textRowVar := data.TextRowVar
            d.content := data.Content
            d.arrName := data.ArrName
            d.saveType := data.SaveType
            d.saveName := data.SaveName
        } else if (cmdKey == "文本处理") {
            d.textOpsType := data.Type
            d.textName := data.Name
            d.argsType := data.ArgsType
            d.argsName := data.ArgsName
            d.search := data.Search
            d.replace := data.Replace
            d.matchType := data.MatchType
            d.saveType := data.SaveType
            d.saveName := data.SaveName
        } else if (cmdKey == "数组") {
            d.isIgnoreExist := data.IsIgnoreExist
            d.arrayType := data.Type
            d.arrayName := data.Name
            d.initArr := data.InitArr.Clone()
            d.mainIndex := data.MainIndex
            d.argsIndex := data.ArgsIndex
            d.argsType := data.ArgsType
            d.argsName := data.ArgsName
            d.saveType := data.SaveType
            d.saveName := data.SaveName
        } else if (cmdKey == "后台鼠标") {
            d.targetTitle := data.TargetTitle
            d.bgOperateType := data.OperateType
            d.bgMouseType := data.MouseType
            d.bgPosVarX := data.PosVarX
            d.bgPosVarY := data.PosVarY
            d.scrollV := data.ScrollV
            d.scrollH := data.ScrollH
            d.clickTime := data.ClickTime
        } else if (cmdKey == "后台按键") {
            d.bgKeyType := data.Type
            d.frontStr := data.FrontStr
            d.clickTime := data.ClickTime
            d.clickCount := data.ClickCount
            d.clickInterval := data.ClickInterval
            d.bgKeyCount := data.KeyArr.Length
            keyStr := ""
            for k in data.KeyArr
                keyStr .= k "⎖"
            d.bgKeyStr := RTrim(keyStr, "⎖")
        } else if (cmdKey == "窗口管理") {
            d.wmActionType := data.ActionType
            d.wmSearchValue := data.SearchValue
            d.wmPosX := data.PosX
            d.wmPosY := data.PosY
            d.wmWidth := data.Width
            d.wmHeight := data.Height
            d.wmNewTitle := data.NewTitle
            d.wmTransparency := data.Transparency
        } else if (cmdKey == "按键检测") {
            d.kcCheckType := data.CheckType
            d.kcStateType := data.StateType
            d.kcVarName := data.VarName
            d.kcKeyCount := data.KeyArr.Length
            keyStr := ""
            for k in data.KeyArr
                keyStr .= k "⎖"
            d.kcKeyStr := RTrim(keyStr, "⎖")
        } else if (cmdKey == "抓图") {
            d.ssType := data.ScreenShotType
            d.ssWinInfo := data.WinInfo
            d.ssStartX := data.StartPosX
            d.ssStartY := data.StartPosY
            d.ssEndX := data.EndPosX
            d.ssEndY := data.EndPosY
            d.ssNameType := data.NameType
            d.ssFixedName := data.FixedName
            d.ssSavePath := data.SavePath
            d.ssResultToggle := data.ResultToggle
            d.ssResultSaveName := data.ResultSaveName
        } else if (cmdKey == "循环") {
            d.loopCount := data.LoopCount
            d.condiType := data.CondiType
            d.logicType := data.LogicType
            d.loopBody := data.LoopBody
            loop 4 {
                i := A_Index
                d["loopTog" i] := data.ToggleArr[i]
                d["loopName" i] := data.NameArr[i]
                d["loopCmp" i] := data.CompareTypeArr[i]
                d["loopVar" i] := data.VariableArr[i]
            }
        }
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
            ; 展开的循环节点：持久化外置循环体相对偏移，重载/收展时布局稳定
            this._StoreLoopBodyLayout(id, node, p)
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
        if (this._IsExpandedIfPro(searchId)) {
            this._StoreProBranchLayout(searchId, node, searchPos)
            node.ExpandShift := ""
        } else if (this._HasVisibleBranches(searchId) && !this._IsIfProNodeId(searchId)) {
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

    ; 把展开循环节点的外置循环体相对位置写入其 MacroGraphNode（供重载/收展时还原）。
    ; 折叠态：外置体不存在，保留既有 LoopBodyDX/DY（勿覆盖）。
    _StoreLoopBodyLayout(loopId, node, loopPos) {
        if (!this._IsExpandedLoop(loopId))
            return
        bid := this._LoopBodyId(loopId)
        if (!this.pos.Has(bid))
            return
        bp := this.pos[bid]
        node.LoopBodyDX := bp.x - loopPos.x
        node.LoopBodyDY := bp.y - loopPos.y
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
            for layoutProp in ["TrueBranchDX", "TrueBranchDY", "FalseBranchDX", "FalseBranchDY", "ExpandShift", "SuccDX", "SuccDY", "ProBranchOff"] {
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

    ; 判断 RMT CMD 分段是否为「类别」名（用于区分新格式 RMT指令_类别_指令 与旧格式 RMT指令_指令_序号）
    _IsRmtCategoryName(name) {
        for cat in GetLangArr(["全部", "图文", "输入控制", "宏控制", "调试", "软件自身"]) {
            if (name == cat)
                return true
        }
        return false
    }

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
        ObjSetBase(d, MGParseObjBase.Prototype)   ; 启用 d["dynKey"] 中括号读写（见 MGParseObjBase）

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
        else if (this._IsInputName(name)) {
            ; 输入参数存储在 InputFile.ini 中，CurCMD 即其 SerialStr（如 "输入1"）
            d.type := GetLang("输入")
            d.serialStr := name
            try {
                data := GetMacroCMDData(name)
                if (IsObject(data)) {
                    d.inputType := data.Type
                    d.pauseType := data.PauseType
                    d.cancelType := data.CancelType
                    d.saveName := data.SaveName
                }
            }
        }
        else if (this._IsOutputName(name)) {
            ; 输出参数存储在 OutputFile.ini 中，CurCMD 即其 SerialStr（如 "输出1"）
            d.type := GetLang("输出")
            d.serialStr := name
            try {
                data := GetMacroCMDData(name)
                if (IsObject(data)) {
                    d.outputType := data.OutputType
                    d.text := data.Text
                    d.variableName := (data.VariableName != "") ? data.VariableName : "Data"
                }
            }
        }
        else if (name == GetLang("RMT指令")) {
            d.type := GetLang("RMT指令")
            ; CMD格式: RMT指令_类别_指令_序号（新）或 RMT指令_指令_序号（旧兼容）
            if (paramArr.Length >= 4) {
                d.rmtCategory := paramArr[2]
                d.rmtOp := paramArr[3]
                d.rmtMenuIdx := paramArr[4]
            } else if (paramArr.Length >= 3) {
                if (this._IsRmtCategoryName(paramArr[2])) {
                    ; 新格式（无菜单序号）：RMT指令_类别_指令
                    d.rmtCategory := paramArr[2]
                    d.rmtOp := paramArr[3]
                    d.rmtMenuIdx := "1"
                } else {
                    ; 旧格式：RMT指令_指令_序号
                    d.rmtCategory := GetLang("全部")
                    d.rmtOp := paramArr[2]
                    d.rmtMenuIdx := IsNumber(paramArr[3]) ? paramArr[3] : "1"
                }
            } else if (paramArr.Length >= 2) {
                d.rmtCategory := GetLang("全部")
                d.rmtOp := paramArr[2]
                d.rmtMenuIdx := "1"
            } else {
                d.rmtCategory := GetLang("全部")
                d.rmtOp := GetLang("截图")
                d.rmtMenuIdx := "1"
            }
        }
        else if (iniKey := this._FormalIniKeyFromName(name)) {
            d.type := GetLang(iniKey)
            d.serialStr := name
            try {
                data := GetMacroCMDData(name)
                this._MapIniDataToParse(d, data, iniKey)
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
        if (d.type == GetLang("RMT指令")) {
            ; CMD格式: RMT指令_类别_指令_序号
            category := d.HasOwnProp("rmtCategory") ? d.rmtCategory : GetLang("全部")
            op := d.HasOwnProp("rmtOp") ? d.rmtOp : GetLang("截图")
            cmd := GetLang("RMT指令") "_" category "_" op
            if (op == GetLang("显示菜单") && d.HasOwnProp("rmtMenuIdx") && d.rmtMenuIdx != "")
                cmd .= "_" d.rmtMenuIdx
            return cmd
        }
        return d.raw
    }
}

_GraftMacroGraphMixin(MacroGraphDataMixin)