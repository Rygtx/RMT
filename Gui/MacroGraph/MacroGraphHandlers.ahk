#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 节点内联编辑回调
;
; 间隔/按键/移动/移动Pro/搜索/搜索Pro 等节点在节点面板上直接内联编辑时的事件回调、
; 显隐联动与类型↔文本/索引转换。方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphHandlersMixin {
    ; ----------------------------------------------------------------- 内联编辑回调

    ; 按键类型下拉项：0=按下 1=松开 2=点击（与 _TypeIndex / 节点构建顺序一致）
    _KeyTypeFromIndex(idx) {
        if (idx == 0)
            return GetLang("按下")
        if (idx == 1)
            return GetLang("松开")
        return GetLang("点击")
    }

    ; 从引擎当前选中项解析按键类型：SelectedIndex 优先（state 文本在多节点下可能为空）
    _KeyTypeFromState(key, state, fallback := "") {
        if (this.ui != "") {
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0 && Integer(idx) <= 2)
                return this._KeyTypeFromIndex(Integer(idx))
        }
        if (IsObject(state) && state.Has(key) && state[key] != "") {
            t := state[key]
            if (t == GetLang("按下") || t == GetLang("松开") || t == GetLang("点击"))
                return t
            if (IsNumber(t) && Integer(t) >= 0 && Integer(t) <= 2)
                return this._KeyTypeFromIndex(Integer(t))
        }
        if (fallback != "")
            return fallback
        return GetLang("点击")
    }

    _OnKeyType(id, state, ctrl, event) {
        if (!this.cmdNodes.Has(id))
            return
        key := "TypeCmb_" id
        d := this._Parse(this.cmdNodes[id].CurCMD)
        d.ktype := this._KeyTypeFromState(key, state, d.ktype)
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
        ; 优先用 SelectedIndex（不依赖下拉项 Content 文本；多节点/主题下 state 文本可能为空）
        d.itype := this._IntervalTypeFromState(key, state, d.itype)
        if (d.itype == GetLang("随机") && d.time2 == "")
            d.time2 := "1000"
        this.cmdNodes[id].CurCMD := this._BuildCmd(d)
        this._RefreshIntervalVisibility(id)
        this._Apply()
    }

    ; 随机模式显示第二时间行，固定模式隐藏；同时同步时间控件值，避免切换后显示旧值
    _RefreshIntervalVisibility(id) {
        d := this._Parse(this.cmdNodes[id].CurCMD)
        if (d.type != GetLang("间隔") || this.ui == "")
            return
        isRandom := d.itype == GetLang("随机")
        ; 先显隐再同步文本，避免对仍折叠的 Time2 写 Text 触发无效事件
        this.ui.Update("Time2Row_" id, "Visibility", isRandom ? "Visible" : "Collapsed")
        this.ui.Update("Time_" id, "Text", d.time)
        this.ui.Update("Time2_" id, "Text", d.time2)
    }

    ; 间隔类型 -> 下拉项索引
    _IntervalTypeIndex(itype) {
        return (itype == GetLang("随机")) ? 1 : 0
    }

    ; 从引擎当前选中项解析间隔类型：SelectedIndex 优先，其次 state 文本，最后保留旧值
    _IntervalTypeFromState(key, state, fallback := "") {
        if (this.ui != "") {
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0)
                return (Integer(idx) == 1) ? GetLang("随机") : GetLang("固定")
        }
        if (IsObject(state) && state.Has(key) && state[key] != "")
            return this._IntervalTypeFromText(state[key])
        if (fallback != "")
            return fallback
        return GetLang("固定")
    }

    ; 下拉项文本 -> 间隔类型（与显示项使用同一 GetLang，确保中英文一致匹配）
    _IntervalTypeFromText(text) {
        if (text == "1" || text == 1)
            return GetLang("随机")
        if (text == "0" || text == 0)
            return GetLang("固定")
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

    ; 游戏视角模式下速度固定100且禁用编辑；其余模式恢复可编辑并同步速度值
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
            ; 切出游戏视角时同步速度值为数据模型中的值，避免残留 100
            this.ui.Update("Speed_" id, "Text", d.speed)
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

    ; 如果Pro序列码判定（如 "如果Pro1"）
    _IsCompareProName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("如果Pro")
    }

    ; 如果序列码判定（如 "如果1"）：去掉结尾数字后与「如果」完全匹配
    _IsCompareName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("如果")
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
        ; KeyDown 只处理回车
        if (IsObject(event) && event.HasProp("Key")) {
            k := event.Key
            if (k != "Return" && k != "Enter")
                return
        }
        nameMap := Map("PosVarX", "MPPosX_", "PosVarY", "MPPosY_", "Speed", "MPSpeed_", "Count", "MPCount_", "Interval", "MPInterval_")
        key := nameMap[field] id
        val := ""
        hasVal := false
        if (IsObject(state) && state.Has(key)) {
            val := state[key]
            hasVal := true
        }
        else if (this.ui != "") {
            q := this.ui.Query(key)
            if (q != "") {
                val := q
                hasVal := true
            }
        }
        if (!hasVal)
            return
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
    ; 同时同步控件值，确保切换后内容与数据模型一致
    _RefreshMMProVisibility(id) {
        if (this.ui == "")
            return
        data := this._MMProData(id)
        if (data == "")
            return
        isGameView := (data.MouseMoveMode == 2 || data.MouseMoveMode == "2")
        isHuman := (ObjHasOwnProp(data, "IsHumanMouse") && (data.IsHumanMouse == 1 || data.IsHumanMouse == "1"))

        ; 移动速度：游戏视角固定 100 且禁用；其余模式同步数据模型中的值
        if (isGameView) {
            this.ui.Update("MPSpeed_" id, "Text", "100")
            this.ui.Update("MPSpeed_" id, "IsEnabled", "False")
        }
        else {
            speedVal := ObjHasOwnProp(data, "Speed") ? data.Speed : "90"
            this.ui.Update("MPSpeed_" id, "Text", speedVal)
            this.ui.Update("MPSpeed_" id, "IsEnabled", "True")
        }

        ; 鼠标动作：游戏视角或拟真轨迹下强制「移动」且禁用；其余模式同步选中项
        if (isGameView || isHuman) {
            this.ui.Update("MPActionCmb_" id, "SelectedIndex", 0)
            this.ui.Update("MPActionCmb_" id, "IsEnabled", "False")
        }
        else {
            actionIdx := this._MMProActionIndex(ObjHasOwnProp(data, "ActionType") ? data.ActionType : 1)
            this.ui.Update("MPActionCmb_" id, "SelectedIndex", actionIdx)
            this.ui.Update("MPActionCmb_" id, "IsEnabled", "True")
        }

        ; 移动方式：拟真轨迹开启时禁用；非禁用时同步选中项
        if (isHuman) {
            this.ui.Update("MPModeCmb_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("MPModeCmb_" id, "SelectedIndex", this._MoveModeIndex(data.MouseMoveMode))
            this.ui.Update("MPModeCmb_" id, "IsEnabled", "True")
        }

        ; 拟真轨迹：游戏视角下取消勾选并禁用
        if (isGameView) {
            this.ui.Update("MPHuman_" id, "IsChecked", "False")
            this.ui.Update("MPHuman_" id, "IsEnabled", "False")
        }
        else {
            this.ui.Update("MPHuman_" id, "IsEnabled", "True")
        }

        ; 移动次数 / 每次间隔：仅游戏视角显示；同步控件值
        this.ui.Update("MPCount_" id, "Text", ObjHasOwnProp(data, "Count") ? data.Count : "1")
        this.ui.Update("MPInterval_" id, "Text", ObjHasOwnProp(data, "Interval") ? data.Interval : "1000")
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

    ; 读取分支父节点数据（搜索/搜索Pro 或 如果）
    _BranchParentData(parentId) {
        if (this._IsSearchNodeId(parentId))
            return this._SearchData(parentId)
        if (this._IsIfNodeId(parentId))
            return this._FormalIniData(parentId)
        if (this._IsIfProNodeId(parentId))
            return this._FormalIniData(parentId)
        return ""
    }

    ; 下拉文本 -> 搜索类型编号（1屏幕图片 2屏幕颜色 3屏幕文本 4窗口图片 5窗口颜色 6窗口文本）
    _SearchTypeFromText(text) {
        names := [GetLang("屏幕图片"), GetLang("屏幕颜色"), GetLang("屏幕文本"), GetLang("窗口图片"), GetLang("窗口颜色"), GetLang("窗口文本")]
        loop names.Length {
            if (text == names[A_Index] || GetLangKey(text) == GetLangKey(names[A_Index]))
                return A_Index
        }
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

    ; 搜索类型编号上限（搜索 1-3，搜索Pro 1-6）
    _SearchTypeMax(id) {
        return this._IsNodePro(id) ? 6 : 3
    }

    ; 从事件 state / 下拉索引解析搜索类型：优先用 state（事件已带当前值），避免同步 Query 偶发空值
    _SearchTypeFromState(id, key, state, fallback := 1) {
        maxType := this._SearchTypeMax(id)
        if (IsObject(state) && state.Has(key) && state[key] != "") {
            st := this._SearchTypeFromText(state[key])
            if (st >= 1 && st <= maxType)
                return st
            if (IsNumber(state[key])) {
                n := Integer(state[key])
                if (n >= 0 && n < maxType)
                    return n + 1
                if (n >= 1 && n <= maxType)
                    return n
            }
        }
        if (this.ui != "") {
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0) {
                st := Integer(idx) + 1
                if (st >= 1 && st <= maxType)
                    return st
            }
        }
        fb := Integer(fallback)
        return (fb >= 1 && fb <= maxType) ? fb : 1
    }

    ; 搜索类型变更：写回数据并切换类型相关行的显隐
    _OnSearchType(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "STypeCmb_" id
        data.SearchType := this._SearchTypeFromState(id, key, state, data.SearchType)
        SaveMacroCMDData(data)
        this._RefreshSearchVisibility(id, data)
        this._Apply()
    }

    ; 按搜索类型切换 颜色/文本/图片 行的显隐（兼容 搜索 与 搜索Pro）
    ; 同时同步控件值，确保切换类型后内容与数据模型一致
    ; dataOpt：传入已写回的数据对象，避免刚 Save 删缓存后再读失败导致显隐不刷新
    _RefreshSearchVisibility(id, dataOpt := "") {
        data := IsObject(dataOpt) ? dataOpt : this._SearchData(id)
        if (data == "" || this.ui == "")
            return
        st := data.SearchType
        c := this._SearchTypeClass(st)
        ; 同步控件值，避免切换类型后显示旧值
        if (ObjHasOwnProp(data, "SearchColor"))
            this.ui.Update("SColor_" id, "Text", data.SearchColor)
        if (ObjHasOwnProp(data, "SearchText"))
            this.ui.Update("SText_" id, "Text", data.SearchText)
        if (c.isImage) {
            imgPath := data.HasOwnProp("SearchImagePath") ? data.SearchImagePath : ""
            ; 搜索Pro：完整路径（过长左侧 ...）；普通搜索仍只显示文件名
            if (this._IsNodePro(id))
                this._SetSearchImgDisplay(id, imgPath)
            else
                this.ui.Update("SImg_" id, "Text", (imgPath != "") ? RegExReplace(imgPath, ".*\\", "") : GetLang("未设置"))
        }
        this.ui.Update("SColorRow_" id, "Visibility", c.isColor ? "Visible" : "Collapsed")
        this.ui.Update("STextRow_" id, "Visibility", c.isText ? "Visible" : "Collapsed")
        this.ui.Update("SImgRow_" id, "Visibility", c.isImage ? "Visible" : "Collapsed")
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
            resOn := (data.ResultToggle == 1 || data.ResultToggle == "1" || data.ResultToggle == true)
            coordOn := (data.CoordToogle == 1 || data.CoordToogle == "1" || data.CoordToogle == true)
            this.ui.Update("SResFields_" id, "Visibility", resOn ? "Visible" : "Collapsed")
            this.ui.Update("SCoordFields_" id, "Visibility", coordOn ? "Visible" : "Collapsed")
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

    ; 估算文本显示宽度（半角 1、全角/非 ASCII 2），用于路径省略裁切
    _TextDisplayUnits(s) {
        n := 0, i := 1, len := StrLen(s)
        while (i <= len) {
            n += (Ord(SubStr(s, i, 1)) > 0x7F) ? 2 : 1
            i++
        }
        return n
    }

    ; 搜索图片路径展示：空→未设置；过长左侧 ...，并始终保留完整文件名（避免右缘裁掉后缀）
    ; 输入框宽 276、Padding/边框约占 10：半角约 7.5px → 预算约 35；偏保守保证整串（含扩展名）落在框内
    _SearchImgDisplayText(path) {
        if (path == "")
            return GetLang("未设置")
        maxUnits := 35
        if (this._TextDisplayUnits(path) <= maxUnits)
            return path
        SplitPath(path, &fileName)
        if (fileName == "")
            fileName := path
        ell := "..."
        ; 文件名本身很长时优先保证文件名完整
        if (this._TextDisplayUnits(ell fileName) >= maxUnits)
            return ell fileName
        budget := maxUnits - this._TextDisplayUnits(ell)
        suffix := fileName
        i := StrLen(path) - StrLen(fileName)
        while (i >= 1) {
            trial := SubStr(path, i, 1) suffix
            if (this._TextDisplayUnits(trial) > budget)
                break
            suffix := trial
            i--
        }
        return ell suffix
    }

    ; 写入搜索图片展示文本，并把光标滚到末尾（TextBox 超宽时默认从左侧裁切，否则右缘会丢掉扩展名）
    _SetSearchImgDisplay(id, path) {
        if (this.ui == "")
            return
        disp := this._SearchImgDisplayText(path)
        key := "SImg_" id
        this.ui.Update(key, "Text", disp)
        this.ui.Update(key, "CaretIndex", String(StrLen(disp)))
    }

    ; 获得焦点：还原完整路径便于编辑（空路径清空「未设置」占位）
    _OnSearchImgGotFocus(id, *) {
        data := this._SearchData(id)
        if (data == "" || this.ui == "")
            return
        path := data.HasOwnProp("SearchImagePath") ? data.SearchImagePath : ""
        key := "SImg_" id
        this.ui.Update(key, "Text", path)
        ; 编辑长路径时先看到文件名一端
        if (path != "")
            this.ui.Update(key, "CaretIndex", String(StrLen(path)))
    }

    ; 失焦：写回路径，再切回左侧省略展示
    _OnSearchImgLostFocus(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SImg_" id
        val := ""
        if (IsObject(state) && state.Has(key))
            val := state[key]
        else if (this.ui != "")
            val := this.ui.Query(key)
        if (val == GetLang("未设置"))
            val := ""
        cur := data.HasOwnProp("SearchImagePath") ? data.SearchImagePath : ""
        ; 仍是省略展示串（未真正改路径）时不覆盖
        if (val != cur && val == this._SearchImgDisplayText(cur))
            val := cur
        data.SearchImagePath := val
        SaveMacroCMDData(data)
        this._SetSearchImgDisplay(id, val)
        this._RefreshSearchTitlePreview(id)
        this._Apply()
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

    ; 从事件 state / 下拉索引解析鼠标动作编号：优先 state，其次 Query
    _SearchActionFromState(id, key, state, fallback := 1) {
        isPro := this._IsNodePro(id)
        maxAct := isPro ? 3 : 4
        if (IsObject(state) && state.Has(key) && state[key] != "") {
            act := this._SearchActionFromText(state[key])
            if (act >= 1 && act <= maxAct)
                return act
            if (IsNumber(state[key])) {
                n := Integer(state[key])
                if (n >= 0 && n < maxAct)
                    return n + 1
                if (n >= 1 && n <= maxAct)
                    return n
            }
        }
        if (this.ui != "") {
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0) {
                act := Integer(idx) + 1
                if (act >= 1 && act <= maxAct)
                    return act
            }
        }
        fb := Integer(fallback)
        return (fb >= 1 && fb <= maxAct) ? fb : 1
    }

    ; 鼠标动作变更：写回 SearchData
    _OnSearchAction(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        key := "SActCmb_" id
        data.MouseActionType := this._SearchActionFromState(id, key, state, data.MouseActionType)
        SaveMacroCMDData(data)
        ; 搜索Pro：动作变更联动 移动速度/点击次数 的显隐
        this._RefreshSearchVisibility(id, data)
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
    ; 可编辑下拉默认采集优先 SelectedItem：选「无限」后再手输时选中项常残留，
    ; 失焦/回车必须读 >Text；仅 SelectionChanged（明确点选）才按 SelectedIndex 认作无限。
    _OnSearchCount(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        ; KeyDown 只处理回车（手输后立即联动间隔显隐）
        if (IsObject(event) && event.HasProp("Key")) {
            k := event.Key
            if (k != "Return" && k != "Enter")
                return
        }
        key := "SCount_" id
        val := ""
        evName := IsObject(event) ? "" : event
        textVal := ""
        if (this.ui != "")
            textVal := this.ui.Query(key ">Text")
        if (evName == "SelectionChanged" && this.ui != "") {
            ; 用户从下拉明确点选「无限」：此时 Text 可能仍是旧手输值，以选中项为准
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0)
                val := GetLang("无限")
        }
        else if (evName == "DropDownClosed" && this.ui != "") {
            ; 下拉关闭：选中项与显示文本同为「无限」才认作无限，避免残留 SelectedIndex 盖回手输值
            idx := this.ui.Query(key ">SelectedIndex")
            if (idx != "" && IsNumber(idx) && Integer(idx) >= 0 && (textVal == "" || textVal == GetLang("无限")))
                val := GetLang("无限")
            else
                val := textVal
        }
        if (val == "") {
            if (textVal != "")
                val := textVal
            else if (IsObject(state) && state.Has(key) && state[key] != "")
                val := state[key]
        }
        if (val == "") {
            this._RefreshSearchVisibility(id, data)
            return
        }
        if (val == GetLang("无限")) {
            data.SearchCount := -1
            if (this.ui != "")
                this.ui.Update(key, "Text", GetLang("无限"))
        }
        else if (IsNumber(val) && val + 0 >= 1) {
            data.SearchCount := val + 0
            if (this.ui != "") {
                ; 清掉残留的「无限」选中项，再写手数，避免下次默认采集又读回无限
                this.ui.Update(key, "SelectedIndex", "-1")
                this.ui.Update(key, "Text", "" data.SearchCount)
            }
        }
        else {
            this._RefreshSearchVisibility(id, data)
            return
        }
        SaveMacroCMDData(data)
        this._RefreshSearchVisibility(id, data)
        this._Apply()
    }

    ; CheckBox 勾选状态：Checked/Unchecked 事件名最可靠，其次 state，最后 Query
    _CheckBoxOn(idPrefix, id, state, event) {
        if (IsSet(event)) {
            if (event == "Checked")
                return true
            if (event == "Unchecked")
                return false
        }
        key := idPrefix id
        if (IsObject(state) && state.Has(key)) {
            v := state[key]
            return (v == "True" || v == true || v == 1 || v == "1")
        }
        if (this.ui != "") {
            v := this.ui.Query(key)
            return (v == "True" || v == true || v == 1 || v == "1")
        }
        return false
    }

    ; 结果保存开关：写回并显隐内部字段
    _OnSearchResultToggle(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        data.ResultToggle := this._CheckBoxOn("SResTog_", id, state, event) ? 1 : 0
        if (data.ResultToggle == 1 && data.ResultSaveName != "")
            MySoftData.GlobalVariMap[data.ResultSaveName] := true
        SaveMacroCMDData(data)
        this._RefreshSearchVisibility(id, data)
        this._Apply()
    }

    ; 目标点保存开关：写回并显隐内部字段
    _OnSearchCoordToggle(id, state, ctrl, event) {
        data := this._SearchData(id)
        if (data == "")
            return
        data.CoordToogle := this._CheckBoxOn("SCoordTog_", id, state, event) ? 1 : 0
        if (data.CoordToogle == 1) {
            if (data.CoordXName != "")
                MySoftData.GlobalVariMap[data.CoordXName] := true
            if (data.CoordYName != "")
                MySoftData.GlobalVariMap[data.CoordYName] := true
        }
        SaveMacroCMDData(data)
        this._RefreshSearchVisibility(id, data)
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
        if (MainSoftData.ScreenShotType == 1) {
            SetClipboard("")
            Run("ms-screenclip:")
            SetTimer(this._searchClipAction, 500)
            TogGetSelectArea(true, this._OnSearchShotArea.Bind(this, id))
        }
        else if (MainSoftData.ScreenShotType == 3) {
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

    ; ----------------------------------------------------------------- 输入 / 输出节点内联编辑

    ; 输入序列码判定（如 "输入1"）：去掉结尾数字后与「输入」完全匹配
    _IsInputName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("输入")
    }

    ; 输出序列码判定（如 "输出1"）：去掉结尾数字后与「输出」完全匹配
    _IsOutputName(name) {
        if (name == "")
            return false
        return RegExReplace(name, "\d+$", "") == GetLang("输出")
    }

    _InputData(id) {
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

    _OutputData(id) {
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

    _InputTypeIndex(typeKey) {
        typeNames := GetLangArr(["弹窗", "状态", "继续", "继续&取消"])
        target := GetLang(typeKey)
        Loop typeNames.Length {
            if (typeNames[A_Index] == target)
                return A_Index - 1
        }
        return 0
    }

    _InputTypeFromText(text) {
        for key in ["弹窗", "状态", "继续", "继续&取消"] {
            if (text == GetLang(key))
                return key
        }
        return "弹窗"
    }

    _InputPauseTypeIndex(typeKey) {
        typeNames := GetLangArr(["暂停当前宏", "暂停所有宏"])
        target := GetLang(typeKey)
        Loop typeNames.Length {
            if (typeNames[A_Index] == target)
                return A_Index - 1
        }
        return 0
    }

    _InputPauseTypeFromText(text) {
        for key in ["暂停当前宏", "暂停所有宏"] {
            if (text == GetLang(key))
                return key
        }
        return "暂停当前宏"
    }

    _InputCancelTypeIndex(typeKey) {
        typeNames := GetLangArr(["终止当前宏", "终止所有宏"])
        target := GetLang(typeKey)
        Loop typeNames.Length {
            if (typeNames[A_Index] == target)
                return A_Index - 1
        }
        return 0
    }

    _InputCancelTypeFromText(text) {
        for key in ["终止当前宏", "终止所有宏"] {
            if (text == GetLang(key))
                return key
        }
        return "终止当前宏"
    }

    _OutputTypeIndex(outputTypeKey) {
        typeNames := GetLangArr(["发送内容", "粘贴内容", "临时提示", "指令窗口", "软件弹窗", "系统语音", "复制到剪切板", "字符变量"])
        target := GetLang(outputTypeKey)
        Loop typeNames.Length {
            if (typeNames[A_Index] == target)
                return A_Index - 1
        }
        return 0
    }

    _OutputTypeFromText(text) {
        for key in ["发送内容", "粘贴内容", "临时提示", "指令窗口", "软件弹窗", "系统语音", "复制到剪切板", "字符变量"] {
            if (text == GetLang(key))
                return key
        }
        return "发送内容"
    }

    _OnInputType(id, state, ctrl, event) {
        data := this._InputData(id)
        if (data == "")
            return
        key := "InTypeCmb_" id
        if (state.Has(key) && state[key] != "")
            data.Type := this._InputTypeFromText(state[key])
        SaveMacroCMDData(data)
        this._RefreshInputVisibility(id)
        this._Apply()
    }

    _OnInputPauseType(id, state, ctrl, event) {
        data := this._InputData(id)
        if (data == "")
            return
        key := "InPauseCmb_" id
        if (state.Has(key) && state[key] != "")
            data.PauseType := this._InputPauseTypeFromText(state[key])
        SaveMacroCMDData(data)
        this._Apply()
    }

    _OnInputCancelType(id, state, ctrl, event) {
        data := this._InputData(id)
        if (data == "")
            return
        key := "InCancelCmb_" id
        if (state.Has(key) && state[key] != "")
            data.CancelType := this._InputCancelTypeFromText(state[key])
        SaveMacroCMDData(data)
        this._Apply()
    }

    _OnInputField(id, field, state, ctrl, event) {
        data := this._InputData(id)
        if (data == "")
            return
        if (field == "SaveName") {
            key := "InSave_" id
            if (state.Has(key)) {
                val := state[key]
                if (val == "")
                    return
                data.SaveName := GetVarName(val)
                if (data.Type == "弹窗" || data.Type == "状态")
                    MySoftData.GlobalVariMap[data.SaveName] := true
                SaveMacroCMDData(data)
            }
        }
        this._Apply()
    }

    _RefreshInputVisibility(id) {
        data := this._InputData(id)
        if (data == "" || this.ui == "")
            return
        typeKey := data.Type
        showCancel := (typeKey == "继续&取消")
        showRes := (typeKey == "弹窗" || typeKey == "状态")
        ; 同步控件值，确保切换类型后内容与数据模型一致
        if (ObjHasOwnProp(data, "CancelType"))
            this.ui.Update("InCancelCmb_" id, "SelectedIndex", this._InputCancelTypeIndex(data.CancelType))
        if (ObjHasOwnProp(data, "SaveName"))
            this.ui.Update("InSave_" id, "Text", data.SaveName)
        this.ui.Update("InCancelRow_" id, "Visibility", showCancel ? "Visible" : "Collapsed")
        this.ui.Update("InSaveRow_" id, "Visibility", showRes ? "Visible" : "Collapsed")
    }

    ; 完整编辑器确定后刷新输入节点内联显示
    _RefreshInputNode(id, d) {
        if (this.ui == "")
            return
        typeKey := d.HasOwnProp("inputType") ? d.inputType : "弹窗"
        this.ui.Update("Title_" id, "Text", d.type)
        this.ui.Update("InTypeCmb_" id, "SelectedIndex", this._InputTypeIndex(typeKey))
        this.ui.Update("InPauseCmb_" id, "SelectedIndex", this._InputPauseTypeIndex(d.HasOwnProp("pauseType") ? d.pauseType : "暂停当前宏"))
        this.ui.Update("InCancelCmb_" id, "SelectedIndex", this._InputCancelTypeIndex(d.HasOwnProp("cancelType") ? d.cancelType : "终止当前宏"))
        if (d.HasOwnProp("saveName"))
            this.ui.Update("InSave_" id, "Text", d.saveName)
        this._RefreshInputVisibility(id)
    }

    _OnOutputType(id, state, ctrl, event) {
        data := this._OutputData(id)
        if (data == "")
            return
        key := "OutTypeCmb_" id
        if (state.Has(key) && state[key] != "")
            data.OutputType := this._OutputTypeFromText(state[key])
        SaveMacroCMDData(data)
        this._RefreshOutputVisibility(id)
        this._Apply()
    }

    _OnOutputField(id, field, state, ctrl, event) {
        data := this._OutputData(id)
        if (data == "")
            return
        if (field == "Text") {
            key := "OutText_" id
            if (state.Has(key))
                data.Text := GetLangStr(state[key], 2)
        }
        else if (field == "VariableName") {
            key := "OutVar_" id
            if (state.Has(key)) {
                val := state[key]
                if (val == "")
                    return
                data.VariableName := GetVarName(val)
                if (data.OutputType == "字符变量")
                    MySoftData.GlobalVariMap[data.VariableName] := true
            }
        }
        SaveMacroCMDData(data)
        this._Apply()
    }

    _RefreshOutputVisibility(id) {
        data := this._OutputData(id)
        if (data == "" || this.ui == "")
            return
        isCharVar := (data.OutputType == "字符变量")
        ; 同步控件值，确保切换类型后内容与数据模型一致
        if (ObjHasOwnProp(data, "VariableName"))
            this.ui.Update("OutVar_" id, "Text", data.VariableName)
        if (ObjHasOwnProp(data, "Text"))
            this.ui.Update("OutText_" id, "Text", GetLangStr(data.Text, 1))
        this.ui.Update("OutVarRow_" id, "Visibility", isCharVar ? "Visible" : "Collapsed")
    }

    ; 完整编辑器确定后刷新输出节点内联显示
    _RefreshOutputNode(id, d) {
        if (this.ui == "")
            return
        outputTypeKey := d.HasOwnProp("outputType") ? d.outputType : "发送内容"
        varName := (d.HasOwnProp("variableName") && d.variableName != "") ? d.variableName : "Data"
        this.ui.Update("Title_" id, "Text", d.type)
        this.ui.Update("OutTypeCmb_" id, "SelectedIndex", this._OutputTypeIndex(outputTypeKey))
        this.ui.Update("OutVar_" id, "Text", varName)
        if (d.HasOwnProp("text"))
            this.ui.Update("OutText_" id, "Text", GetLangStr(d.text, 1))
        this._RefreshOutputVisibility(id)
    }
}

_GraftMacroGraphMixin(MacroGraphHandlersMixin)
