#Requires AutoHotkey v2.0

class MacroGraphFormalMixin {
    ; 转义 XAML 特殊字符：{ } 在 XAML 中是标记扩展语法，需要转义
    _XamlEscape(text) {
        if (text == "")
            return text
        ; 如果文本以 { 开头，前面加 {} 转义
        if (SubStr(text, 1, 1) == "{")
            text := "{}" text
        return text
    }

    _FormalNodeTypes() {
        types := []
        for key in this._FormalIniCmdKeys()
            types.Push(GetLang(key))
        types.Push(GetLang("RMT指令"))
        return types
    }

    _IsFormalNodeType(typeStr) {
        for t in this._FormalNodeTypes() {
            if (t == typeStr)
                return true
        }
        return false
    }

    _FormalIniData(id) {
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

    _FormalEditorMap() {
        return Map(
            GetLang("宏操作"), this.SubMacroGui,
            GetLang("变量"), this.VariableGui,
            GetLang("变量提取"), this.ExVariableGui,
            GetLang("运算"), this.OperationGui,
            GetLang("运行"), this.RunGui,
            GetLang("文件读写"), this.FileIOGui,
            GetLang("文本处理"), this.TextOpsGui,
            GetLang("数组"), this.ArrayGui,
            GetLang("RMT指令"), this.RMTCMDGui,
            GetLang("后台鼠标"), this.BGMouseGui,
            GetLang("后台按键"), this.BGKeyGui,
            GetLang("窗口管理"), this.WindowManageGui,
            GetLang("按键检测"), this.KeyCheckGui,
            GetLang("抓图"), this.ScreenShotGui
        )
    }

    _RmtOpList() {
        return GetLangArr(["截图", "截图提取文本", "自由贴", "启用键鼠", "禁用键鼠", "显示菜单", "关闭菜单",
            "暂停所有宏", "恢复所有宏", "终止所有宏", "开启变量监视", "关闭变量监视", "开启指令显示",
            "关闭指令显示", "关闭软件", "休眠", "重载"])
    }

    _RmtOpIndex(opText) {
        ops := this._RmtOpList()
        loop ops.Length {
            if (ops[A_Index] == opText)
                return A_Index - 1
        }
        return 0
    }

    _FormalNodeWidth(type) {
        ; 变量提取参数较多：与搜索Pro同宽(380)，内部两列布局
        if (type == GetLang("变量提取"))
            return 380
        return 200
    }

    _FormalLW() {
        return "80"
    }

    _FormalCW() {
        return "96"
    }

    _FormalContentW() {
        return "188"
    }

    _FormalVarSlotOn(v) {
        return v == 1 || v == "1" || v == true || v == "True"
    }

    _FormalVarOpTypes() {
        return GetLangArr(["数值", "随机数值", "字符", "系统", "删除"])
    }

    _FormalMacroIndexItems(macroType) {
        items := []
        mt := GetLangKey(macroType)
        if (mt == "当前宏")
            return items
        tableIndex := GetTableIndex(mt)
        if (tableIndex == 0)
            return items
        try {
            for index, remark in MySoftData.TableInfo[tableIndex].RemarkArr
                items.Push(index ". " remark)
        }
        return items
    }

    _FormalMenuIndexItems() {
        items := []
        try {
            foldInfo := MySoftData.TableInfo[3].FoldInfo
            loop foldInfo.RemarkArr.Length
                items.Push(A_Index ". " foldInfo.RemarkArr[A_Index])
        }
        return items
    }

    _FormalFileIOOperModes(operType) {
        m := Map(
            GetLang("读取Excel"), GetLangArr(["单元格", "指定行", "指定列", "指定区域-行", "指定区域-列"]),
            GetLang("写入Excel"), GetLangArr(["单元格", "行号自增", "列号自增", "指定区域-行", "指定区域-列"]),
            GetLang("读取文本文件"), GetLangArr(["读取全部内容", "逐行读取", "指定行"]),
            GetLang("写入文本文件"), GetLangArr(["覆盖写入", "追加写入", "追加写入-行", "指定行", "行号自增"])
        )
        ot := GetLang(operType)
        return m.Has(ot) ? m[ot] : GetLangArr(["单元格"])
    }

    _FormalTextOpsArgsTypes(typeName) {
        m := Map(
            GetLang("去除空格"), GetLangArr(["去除前空白字符", "去除后空白字符", "去除前后空白字符", "去除所有空白字符"]),
            GetLang("大小写转换"), GetLangArr(["全部大写", "全部小写", "首字母大写"]),
            GetLang("文本统计"), GetLangArr(["字符数", "单词数", "行数"]),
            GetLang("文本提取"), GetLangArr(["数字提取", "字母提取", "中文提取", "正则匹配"]),
            GetLang("文本分割"), GetLangArr(["内容分割", "定长分割", "正则匹配"]),
            GetLang("文本替换"), GetLangArr(["普通文本", "正则匹配"]),
            GetLang("文本拼接"), GetLangArr(["拼接文本"])
        )
        tn := GetLang(typeName)
        return m.Has(tn) ? m[tn] : []
    }

    ; 注意：控件命名统一为 "<prefix>_<id>"，故此处必须用 name "_" id（缺下划线会绑定到不存在的控件，导致内联事件永不触发）。
    _FormalTrackCombo(id, name, handler, runtime) {
        this._TrackCtrl(name "_" id, runtime)
        this._BindCtrl(name "_" id, "SelectionChanged", handler, runtime)
    }

    _FormalTrackField(id, name, handler, runtime) {
        this._TrackCtrl(name "_" id, runtime)
        this._BindCtrl(name "_" id, "LostFocus", handler, runtime)
    }

    _FormalTrackEditCombo(id, name, handler, runtime) {
        this._TrackCtrl(name "_" id, runtime)
        this._BindCtrl(name "_" id, "LostFocus", handler, runtime)
        this._BindCtrl(name "_" id, "SelectionChanged", handler, runtime)
        ; 可编辑 ComboBox 从下拉里选变量时，SelectionChanged 偶发不提交（编辑态文本滞后），
        ; 补绑 DropDownClosed：下拉关闭时 SelectedItem/Text 已确定，确保选择能落库（否则只能手输）。
        this._BindCtrl(name "_" id, "DropDownClosed", handler, runtime)
    }

    _FormalTrackCheck(id, name, handler, runtime) {
        this._TrackCtrl(name "_" id, runtime)
        this._BindCtrl(name "_" id, "Click", handler, runtime)
    }

    _FormalInitArrText(initArr) {
        if (!IsObject(initArr) || initArr.Length == 0)
            return "1,2,3,4,5"
        parts := []
        for v in initArr
            parts.Push(String(v))
        return parts.Join(",")
    }

    _FillFormalNodeBody(id, d, body) {
        if (d.type == GetLang("宏操作"))
            this._FillSubMacroBody(id, d, body)
        else if (d.type == GetLang("变量"))
            this._FillVariableBody(id, d, body)
        else if (d.type == GetLang("变量提取"))
            this._FillExVariableBody(id, d, body)
        else if (d.type == GetLang("运算"))
            this._FillOperationBody(id, d, body)
        else if (d.type == GetLang("运行"))
            this._FillRunBody(id, d, body)
        else if (d.type == GetLang("文件读写"))
            this._FillFileIOBody(id, d, body)
        else if (d.type == GetLang("文本处理"))
            this._FillTextOpsBody(id, d, body)
        else if (d.type == GetLang("数组"))
            this._FillArrayBody(id, d, body)
        else if (d.type == GetLang("RMT指令"))
            this._FillRmtBody(id, d, body)
        else if (d.type == GetLang("后台鼠标"))
            this._FillBGMouseBody(id, d, body)
        else if (d.type == GetLang("后台按键"))
            this._FillBGKeyBody(id, d, body)
        else if (d.type == GetLang("窗口管理"))
            this._FillWindowManageBody(id, d, body)
        else if (d.type == GetLang("按键检测"))
            this._FillKeyCheckBody(id, d, body)
        else if (d.type == GetLang("抓图"))
            this._FillScreenShotBody(id, d, body)
    }

    _AddFormalHint(body) {
        body.Add("TextBlock").Text(GetLang("双击编辑")).Foreground("#888888").FontSize(this._MGFontSize(10)).Margin("0,4,0,0")
    }

    _FillSubMacroBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        macroTypes := GetLangArr(["当前宏", "按键宏", "字串宏", "菜单宏", "定时宏", "宏"])
        callTypes := GetLangArr(["插入到当前宏", "触发", "暂停", "取消暂停", "终止"])
        mt := d.HasOwnProp("macroType") ? d.macroType : "按键宏"
        ct := d.HasOwnProp("callType") ? d.callType : "触发"
        idx := d.HasOwnProp("index") ? d.index : 1
        ins := d.HasOwnProp("insertCount") ? d.insertCount : "1"
        idxItems := this._FormalMacroIndexItems(mt)
        showIdx := (GetLangKey(mt) != "当前宏") && idxItems.Length > 0
        showIns := this._FormalSubCallIsInsert(id, ct)
        this._AddComboRow(body, "SubTypeRow_" id, GetLang("宏类型："), "SubTypeCmb_" id, macroTypes, this._IndexInLangArr(macroTypes, GetLang(mt)), true, true, lw, cw)
        this._AddComboRow(body, "SubCallRow_" id, GetLang("操作类型："), "SubCallCmb_" id, callTypes, this._IndexInLangArr(callTypes, GetLang(ct)), true, true, lw, cw)
        ; 插入次数置于宏序号上方（出现时紧跟操作类型）
        this._AddEditableComboRow(body, "SubInsRow_" id, GetLang("插入次数："), "SubIns_" id, GetGuiVarArr(), ins, showIns, lw, cw)
        this._AddComboRow(body, "SubIdxRow_" id, GetLang("宏序号："), "SubIdxCmb_" id, idxItems, Max(0, idx - 1), showIdx, showIdx, lw, cw)
        this._AddFormalHint(body)
    }

    ; 变量槽（对齐「变量编辑器」：开关 + 变量名 + 变量类型 + 选择/输入 / 最小 / 最大）。
    ; 变量类型：1数值 2随机数值 3字符 4系统 5删除。
    ;   - 数值/字符：显示「选择/输入」行（CopyRow）
    ;   - 系统：显示系统变量下拉（SysRow）
    ;   - 随机数值：显示「最小/最大」两行
    ;   - 删除：仅变量名
    _FillVariableSlot(body, id, slot, d) {
        lw := "66", cw := "94"
        p := "VarS" slot
        toggled := d.HasOwnProp("toggle" slot) ? d["toggle" slot] : (slot == 1 ? 1 : 0)
        on := this._FormalVarSlotOn(toggled)
        ot := d.HasOwnProp("operaType" slot) ? d["operaType" slot] : 1
        vn := d.HasOwnProp("variable" slot) ? d["variable" slot] : "Var" slot
        cv := d.HasOwnProp("copyVar" slot) ? d["copyVar" slot] : "0"
        minv := d.HasOwnProp("minVar" slot) ? d["minVar" slot] : "0"
        maxv := d.HasOwnProp("maxVar" slot) ? d["maxVar" slot] : "10"
        opTypes := this._FormalVarOpTypes()
        showNum := on && ot == 1
        showChar := on && ot == 3
        showSys := on && ot == 4
        showMinMax := on && ot == 2
        ; 每个变量独立卡片：分组清晰、表现更佳，开关/字段集中显示
        card := body.Add("Border").BorderBrush("#3A3A4C").BorderThickness("1").CornerRadius("4").Background("#2A2A38").Margin("0,6,0,0").Padding("6,2,6,6")
        inner := card.Add("StackPanel")
        this._AddCheckRow(inner, p "TogRow_" id, p "Tog_" id, GetLang("变量") slot, on, true)
        this._AddEditableComboRow(inner, p "NameRow_" id, GetLang("变量名："), p "Name_" id, GetGuiVarArr(), vn, on, lw, cw)
        this._AddComboRow(inner, p "OpRow_" id, GetLang("类型："), p "OpCmb_" id, opTypes, ot - 1, on, true, lw, cw)
        ; 数值：可下拉选变量或手输数字；字符：纯文本输入框（无下拉）。两行各自固定标签、按类型显隐切换。
        this._AddEditableComboRow(inner, p "CopyRow_" id, GetLang("数值："), p "Copy_" id, GetGuiVarArr(), cv, showNum, lw, cw)
        this._AddFieldRow(inner, p "CharRow_" id, GetLang("字符："), p "CopyTxt_" id, cv, showChar, true, "", "", "", lw, cw)
        sysItems := GetSystemVarArr()
        sysIdx := this._IndexInLangArr(sysItems, GetLang(cv))
        this._AddComboRow(inner, p "SysRow_" id, GetLang("系统："), p "SysCmb_" id, sysItems, sysIdx, showSys, true, lw, cw)
        this._AddEditableComboRow(inner, p "MinRow_" id, GetLang("最小值："), p "Min_" id, GetGuiVarArr(), minv, showMinMax, lw, cw)
        this._AddEditableComboRow(inner, p "MaxRow_" id, GetLang("最大值："), p "Max_" id, GetGuiVarArr(), maxv, showMinMax, lw, cw)
    }

    _FillVariableBody(id, d, body) {
        ; 同时构建「摘要」与「完整」两套容器，靠显隐切换，避免折叠时整窗重建导致闪烁
        folded := this._NodeFolded(id)
        ; 「如果变量存在则不改变数值」选项：折叠/展开都显示，可随时切换
        ign := d.HasOwnProp("isIgnoreExist") ? d.isIgnoreExist : 0
        this._AddCheckRow(body, "VarIgnRow_" id, "VarIgn_" id, GetLang("如果变量存在则不改变数值"), ign == 1 || ign == "1", true)

        sumBox := body.Add("StackPanel").Name("VarSumBox_" id)
        if (!folded)
            sumBox.Visibility("Collapsed")
        this._FillVariableSummary(id, d, sumBox)

        fullBox := body.Add("StackPanel").Name("VarFullBox_" id)
        if (folded)
            fullBox.Visibility("Collapsed")
        loop 4
            this._FillVariableSlot(fullBox, id, A_Index, d)
        this._AddFormalHint(fullBox)
    }

    ; 收起态摘要：4 个固定命名行（按启用与否显隐），逐个显示「变量名 = 值/描述」，可在折叠时就地刷新
    _FillVariableSummary(id, d, box) {
        anyOn := false
        loop 4 {
            slot := A_Index
            info := this._VarSummaryRowInfo(d, slot)
            if (info.on)
                anyOn := true
            row := box.Add("StackPanel").Name("VarSumRow_" slot "_" id).Orientation("Horizontal").Margin("0,5,0,0")
            if (!info.on)
                row.Visibility("Collapsed")
            row.Add("Ellipse").Width("7").Height("7").Fill("#5C9DED").Margin("0,0,6,0").VerticalAlignment("Center")
            row.Add("TextBlock").Name("VarSumTxt_" slot "_" id).Text(info.text).Foreground("#E8E8E8").FontSize(this._MGFontSize(12)).VerticalAlignment("Center").TextTrimming("CharacterEllipsis")
        }
        emptyTb := box.Add("TextBlock").Name("VarSumEmpty_" id).Text(GetLang("未启用任何变量")).Foreground("#999999").FontSize(this._MGFontSize(11)).Margin("0,5,0,0")
        if (anyOn)
            emptyTb.Visibility("Collapsed")
    }

    ; 单个变量的摘要信息（开关 + 「变量名 = 值/描述」文本）
    _VarSummaryRowInfo(d, slot) {
        toggled := d.HasOwnProp("toggle" slot) ? d["toggle" slot] : (slot == 1 ? 1 : 0)
        on := this._FormalVarSlotOn(toggled)
        ot := d.HasOwnProp("operaType" slot) ? d["operaType" slot] : 1
        vn := d.HasOwnProp("variable" slot) ? d["variable" slot] : "Var" slot
        cv := d.HasOwnProp("copyVar" slot) ? d["copyVar" slot] : "0"
        minv := d.HasOwnProp("minVar" slot) ? d["minVar" slot] : "0"
        maxv := d.HasOwnProp("maxVar" slot) ? d["maxVar" slot] : "10"
        return { on: on, text: vn " = " this._VarSlotSummaryValue(ot, cv, minv, maxv) }
    }

    ; 变量摘要值描述：1数值 2随机 3字符 4系统 5删除
    _VarSlotSummaryValue(ot, cv, minv, maxv) {
        if (ot == 2)
            return GetLang("随机") "[" minv "~" maxv "]"
        if (ot == 3)
            return '"' cv '"'
        if (ot == 4)
            return GetLang("系统") "：" GetLang(cv)
        if (ot == 5)
            return GetLang("删除")
        return cv
    }

    ; 变量提取节点（380 宽，双列布局）：提取类型/忽略、模板(带编辑按钮)、窗口信息、
    ; OCR类型/次数、起止坐标、间隔，最后 6 个提取变量两两并排。
    _FillExVariableBody(id, d, body) {
        LW := "70", CW := "96"   ; 与搜索Pro一致：两列(标签70+控件96)并排恰好放进 380 宽节点
        varList := GetGuiVarArr()
        extTypes := GetLangArr(["屏幕", "剪切板", "窗口"])
        ocrTypes := GetLangArr(["中文", "英文"])
        et := d.HasOwnProp("extractType") ? d.extractType : 1
        es := d.HasOwnProp("extractStr") ? d.extractStr : ""
        wi := d.HasOwnProp("winInfo") ? d.winInfo : ""
        ocr := d.HasOwnProp("ocrType") ? d.ocrType : 1
        isOcr := et == 1 || et == 3
        isWin := et == 3
        ign := d.HasOwnProp("isIgnoreExist") ? d.isIgnoreExist : 0

        ; 提取类型 | 忽略已存在
        r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellCombo(r, "ExTypeRow_" id, GetLang("提取类型："), "ExTypeCmb_" id, extTypes, et - 1, true, LW, CW, false)
        this._ProCellCheck(r, "ExIgnRow_" id, "ExIgn_" id, GetLang("忽略已存在"), ign == 1 || ign == "1", true, true)

        ; 模板（屏幕/剪切板/窗口 都需要），含「编辑」按钮打开提取模板编辑器
        exStrRow := body.Add("StackPanel").Name("ExStrRow_" id).Orientation("Horizontal").Margin("0,5,0,0")
        exStrRow.Add("TextBlock").Text(GetLang("模板：")).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(LW).VerticalAlignment("Center")
        this._MakeTextBox(exStrRow, "ExStr_" id, es, "188")
        exStrRow.Add("Button").Name("ExStrEdit_" id).Content(GetLang("编辑")).FontSize(this._MGFontSize(11)).Height("20").Margin("4,0,0,0").Padding("8,0").Cursor("Hand")

        ; 窗口信息（窗口类型才显示）
        this._AddFieldRow(body, "ExWinRow_" id, GetLang("窗口信息："), "ExWin_" id, wi, isWin, true, "", "", "", LW, "226")

        ; OCR类型（单独一行）
        r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellCombo(r, "ExOcrRow_" id, GetLang("OCR类型："), "ExOcrCmb_" id, ocrTypes, ocr - 1, isOcr, LW, CW, false)

        ; 起始X | 起始Y
        r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(r, "ExSXRow_" id, GetLang("起始X："), "ExSX_" id, varList, "" (d.HasOwnProp("startPosX") ? d.startPosX : 0), isOcr, LW, CW, false)
        this._ProCellEdit(r, "ExSYRow_" id, GetLang("起始Y："), "ExSY_" id, varList, "" (d.HasOwnProp("startPosY") ? d.startPosY : 0), isOcr, LW, CW, true)

        ; 终止X | 终止Y
        r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(r, "ExEXRow_" id, GetLang("终止X："), "ExEX_" id, varList, "" (d.HasOwnProp("endPosX") ? d.endPosX : A_ScreenWidth), isOcr, LW, CW, false)
        this._ProCellEdit(r, "ExEYRow_" id, GetLang("终止Y："), "ExEY_" id, varList, "" (d.HasOwnProp("endPosY") ? d.endPosY : A_ScreenHeight), isOcr, LW, CW, true)

        ; 次数 | 间隔（次数在前）
        sc := d.HasOwnProp("searchCount") ? d.searchCount : 1
        scText := (sc == -1 || sc == "-1" || sc == GetLang("无限")) ? GetLang("无限") : String(sc)
        r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
        this._ProCellEdit(r, "ExCntRow_" id, GetLang("次数："), "ExCnt_" id, [GetLang("无限")], scText, isOcr, LW, CW, false)
        this._ProCellField(r, "ExIntRow_" id, GetLang("间隔："), "ExInt_" id, d.HasOwnProp("searchInterval") ? d.searchInterval : 1000, isOcr, "", LW, CW, true)

        ; 提取变量：6 个，复选框+名称为一格，两格一行
        loop 3 {
            r := body.Add("StackPanel").Orientation("Horizontal").Margin("0,5,0,0")
            this._FillExVarSlotCell(r, id, A_Index * 2 - 1, d, varList, false)
            this._FillExVarSlotCell(r, id, A_Index * 2, d, varList, true)
        }
        this._AddFormalHint(body)
    }

    _FillOperationSlot(body, id, slot, d) {
        lw := this._FormalLW(), cw := this._FormalCW()
        p := "OpS" slot
        toggled := d.HasOwnProp("opToggle" slot) ? d["opToggle" slot] : (slot == 1 ? 1 : 0)
        un := d.HasOwnProp("updateName" slot) ? d["updateName" slot] : "Var" slot
        ex := d.HasOwnProp("expression" slot) ? d["expression" slot] : ""
        this._AddCheckRow(body, p "TogRow_" id, p "Tog_" id, GetLang("变量") slot, toggled == 1 || toggled == "1", true)
        ; 表达式行：文本框 + 编辑按钮（输入框宽度140px）
        ; 注意：表达式中可能包含 { } 变量语法，需要 XAML 转义
        exprRow := body.Add("StackPanel").Name(p "ExprRow_" id).Orientation("Horizontal").Margin("0,5,0,0")
        if (!toggled)
            exprRow.Visibility("Collapsed")
        exprRow.Add("TextBox").Name(p "Expr_" id).Text(this._XamlEscape(ex)).Width("140").Height("20").MinHeight("0").FontSize("11").Padding("4,0").VerticalContentAlignment("Center").TextAlignment("Center").CaretBrush("White")
        exprRow.Add("Button").Name(p "ExprEdit_" id).Content(GetLang("编辑")).Width("32").Height("20").FontSize(this._MGFontSize(10)).Padding("0").Margin("4,0,0,0").VerticalAlignment("Center").Cursor("Hand").Background("#3A3A4C").Foreground("White").BorderThickness("1").BorderBrush("#5A5A6C")
        ; 结果变量下拉
        this._AddEditableComboRow(body, p "TargetRow_" id, GetLang("结果变量："), p "Target_" id, GetGuiVarArr(), un, toggled, lw, cw)
    }

    ; 运算表达式编辑按钮：打开表达式编辑器，确定后回写表达式
    _OnOperationExprEdit(id, slot, *) {
        ; 先从 UI 输入框获取当前表达式（这是最新的值）
        ex := ""
        if (this.ui != "") {
            try {
                ex := this.ui.Get("OpS" slot "Expr_" id, "Text")
            }
        }
        ; 如果 UI 没有，尝试从数据对象获取
        if (ex == "") {
            data := this._FormalIniData(id)
            if (data != "") {
                ; 优先从 ExpressionArr 数组获取（Data 类实例）
                if (data.HasOwnProp("ExpressionArr") && data.ExpressionArr.Length >= slot) {
                    ex := data.ExpressionArr[slot]
                }
                ; 其次从 expression1/expression2... 获取（动态对象）
                else if (data.HasOwnProp("expression" slot)) {
                    ex := data["expression" slot]
                }
            }
        }
        ; 确保 OperationSubGui 已初始化并创建 GUI
        opGui := this.OperationGui
        if (opGui.OperationSubGui == "") {
            opGui.OperationSubGui := OperationSubGui()
        }
        exGui := opGui.OperationSubGui
        exGui.ParentTile := ""
        exGui.OwnerHwnd := ""
        ; 确保 GUI 已创建
        if (exGui.Gui == "") {
            exGui.AddGui()
        }
        ; OperationSubGui.OnClickSureBtn 调用 action(this.Index, expression)
        exGui.SureBtnAction := (idx, expr) => this._OnOperationExprEditSure(id, slot, idx, expr)
        ; 显示编辑器
        exGui.ShowGui(slot, ex)
    }

    ; 表达式编辑器确定回调
    _OnOperationExprEditSure(id, slot, idx, expr, *) {
        ; 直接更新输入框文本
        if (this.ui != "") {
            this.ui.Update("OpS" slot "Expr_" id, "Text", expr)
        }
        ; 同时保存数据
        data := this._FormalIniData(id)
        if (data != "") {
            data.ExpressionArr[slot] := expr
            SaveMacroCMDData(data)
        }
        ; 折叠态刷新摘要
        if (this._NodeFolded(id))
            this._RefreshOperationSummary(id)
        this._Apply()
    }

    _FillOperationBody(id, d, body) {
        ; 同时构建「摘要」与「完整」两套容器，靠显隐切换，避免折叠时整窗重建导致闪烁
        folded := this._NodeFolded(id)

        sumBox := body.Add("StackPanel").Name("OpSumBox_" id)
        if (!folded)
            sumBox.Visibility("Collapsed")
        this._FillOperationSummary(id, d, sumBox)

        fullBox := body.Add("StackPanel").Name("OpFullBox_" id)
        if (folded)
            fullBox.Visibility("Collapsed")
        loop 4
            this._FillOperationSlot(fullBox, id, A_Index, d)
        this._AddFormalHint(fullBox)
    }

    ; 收起态摘要：4 个固定命名行（按启用与否显隐），逐个显示「目标 = 表达式」
    _FillOperationSummary(id, d, box) {
        anyOn := false
        loop 4 {
            slot := A_Index
            info := this._OpSummaryRowInfo(d, slot)
            if (info.on)
                anyOn := true
            row := box.Add("StackPanel").Name("OpSumRow_" slot "_" id).Orientation("Horizontal").Margin("0,5,0,0")
            if (!info.on)
                row.Visibility("Collapsed")
            row.Add("Ellipse").Width("7").Height("7").Fill("#5C9DED").Margin("0,0,6,0").VerticalAlignment("Center")
            row.Add("TextBlock").Name("OpSumTxt_" slot "_" id).Text(this._XamlEscape(info.text)).Foreground("#E8E8E8").FontSize(this._MGFontSize(12)).VerticalAlignment("Center").TextTrimming("CharacterEllipsis")
        }
        emptyTb := box.Add("TextBlock").Name("OpSumEmpty_" id).Text(GetLang("未启用任何变量")).Foreground("#999999").FontSize(this._MGFontSize(11)).Margin("0,5,0,0")
        if (anyOn)
            emptyTb.Visibility("Collapsed")
    }

    ; 单个运算槽的摘要信息
    _OpSummaryRowInfo(d, slot) {
        toggled := d.HasOwnProp("opToggle" slot) ? d["opToggle" slot] : (slot == 1 ? 1 : 0)
        on := toggled == 1 || toggled == "1" || toggled == true || toggled == "True"
        un := d.HasOwnProp("updateName" slot) ? d["updateName" slot] : "Var" slot
        ex := d.HasOwnProp("expression" slot) ? d["expression" slot] : ""
        return { on: on, text: un " = " (ex != "" ? ex : "...") }
    }

    ; 就地刷新运算节点摘要（收起态显示）
    _RefreshOperationSummary(id) {
        if (this.ui == "")
            return
        d := this._FormalDFromId(id)
        loop 4 {
            slot := A_Index
            info := this._OpSummaryRowInfo(d, slot)
            rowName := "OpSumRow_" slot "_" id
            txtName := "OpSumTxt_" slot "_" id
            try {
                this.ui.Update(rowName, "Visibility", info.on ? "Visible" : "Collapsed")
                this.ui.Update(txtName, "Text", info.text)
            }
        }
    }

    _FillRunBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        modes := GetLangArr(["不等待", "等待+返回值", "等待+完整输出"])
        saveLabels := [GetLang("退出码"), GetLang("标准输出"), GetLang("标准错误")]
        rm := d.HasOwnProp("runMode") ? d.runMode : 1
        rp := d.HasOwnProp("runPath") ? d.runPath : ""
        showSave := rm >= 2
        ; 路径行：输入框 + 文件按钮（无标签，输入框宽度+30px）
        runPathRow := body.Add("StackPanel").Name("RunPathRow_" id).Orientation("Horizontal").Margin("0,5,0,0")
        runPathRow.Add("TextBox").Name("RunPath_" id).Text(rp).Width(cw + 25).Height("22").MinHeight("0").FontSize("12").Padding("4,0").VerticalContentAlignment("Center")
        runPathRow.Add("Button").Name("RunPathBrowse_" id).Content(GetLang("文件")).Width("50").Height("22").FontSize(this._MGFontSize(10)).Padding("0").Margin("4,0,0,0").VerticalAlignment("Center").Cursor("Hand").Background("#3A3A4C").Foreground("White").BorderThickness("1").BorderBrush("#5A5A6C")
        this._AddComboRow(body, "RunModeRow_" id, GetLang("模式："), "RunModeCmb_" id, modes, rm - 1, true, true, lw, cw)
        loop 3 {
            i := A_Index
            sn := d.HasOwnProp("runSave" i) ? d["runSave" i] : (i == 1 ? "ExitCode" : (i == 2 ? "StdOut" : "StdErr"))
            this._AddEditableComboRow(body, "RunSave" i "Row_" id, saveLabels[i] "：", "RunSave" i "_" id, GetGuiVarArr(), sn, showSave, lw, cw)
        }
        this._AddFormalHint(body)
    }

    ; 选择文件按钮：打开文件选择对话框，选择后填入路径输入框
    _OnRunPathBrowse(id, *) {
        try {
            ; 尝试获取当前路径作为初始目录
            curPath := ""
            if (this.ui != "") {
                try {
                    curPath := this.ui.Get("RunPath_" id, "Text")
                }
            }
            ; 打开文件选择对话框（支持所有文件类型）
            selectedPath := FileSelect(1, curPath, GetLang("选择运行程序"), "All files (*.*)")
            if (selectedPath != "") {
                if (this.ui != "") {
                    this.ui.Update("RunPath_" id, "Text", selectedPath)
                }
            }
        }
    }

    ; 文件路径选择按钮：打开文件选择对话框
    _OnFIOPathBrowse(id, *) {
        try {
            curPath := ""
            if (this.ui != "") {
                try {
                    curPath := this.ui.Get("FIOPath_" id, "Text")
                }
            }
            ; 根据文件类型显示不同的文件选择对话框
            selectedPath := FileSelect(1, curPath, GetLang("选择文件"), "All files (*.*)")
            if (selectedPath != "") {
                if (this.ui != "") {
                    this.ui.Update("FIOPath_" id, "Text", selectedPath)
                }
            }
        }
    }

    _FillFileIOBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        operTypes := GetLangArr(["读取Excel", "写入Excel", "读取文本文件", "写入文本文件"])
        encodings := GetLangArr(["UTF-8", "UTF-16", "GBK", "ANSI"])
        saveTypes := GetLangArr(["变量", "数组"])
        ot := d.HasOwnProp("operType") ? d.operType : "读取Excel"
        om := d.HasOwnProp("operMode") ? d.operMode : "单元格"
        modeItems := this._FormalFileIOOperModes(ot)
        fp := d.HasOwnProp("filePath") ? d.filePath : ""
        enc := d.HasOwnProp("encoding") ? d.encoding : "UTF-8"
        st := d.HasOwnProp("saveType") ? d.saveType : "变量"
        sn := d.HasOwnProp("saveName") ? d.saveName : "Data"
        IsRead := ot == "读取Excel" || ot == "读取文本文件"
        IsWrite := !IsRead
        IsExcel := ot == "读取Excel" || ot == "写入Excel"
        IsText := ot == "读取文本文件" || ot == "写入文本文件"
        IsExcelRange := IsExcel && (om == "指定行" || om == "指定列" || om == "指定区域-行" || om == "指定区域-列")
        HasTextRow := IsText && (om == "指定行" || om == "逐行读取" || om == "行号自增")
        HasRegion := IsRead && (om == "指定区域-行" || om == "指定区域-列")
        HasWriteContent := IsWrite && !IsExcelRange
        HasWriteArr := IsWrite && IsExcelRange
        this._AddComboRow(body, "FIOTypeRow_" id, GetLang("类型："), "FIOTypeCmb_" id, operTypes, this._IndexInLangArr(operTypes, GetLang(ot)), true, true, lw, cw)
        this._AddComboRow(body, "FIOModeRow_" id, GetLang("模式："), "FIOModeCmb_" id, modeItems, this._IndexInLangArr(modeItems, GetLang(om)), true, true, lw, cw)
        ; 路径行：输入框 + 文件按钮（无标签，与运行节点一致）
        fioPathRow := body.Add("StackPanel").Name("FIOPathRow_" id).Orientation("Horizontal").Margin("0,5,0,0")
        fioPathRow.Add("TextBox").Name("FIOPath_" id).Text(fp).Width(cw + 25).Height("22").MinHeight("0").FontSize("12").Padding("4,0").VerticalContentAlignment("Center")
        fioPathRow.Add("Button").Name("FIOPathBrowse_" id).Content(GetLang("文件")).Width("50").Height("22").FontSize(this._MGFontSize(10)).Padding("0").Margin("4,0,0,0").VerticalAlignment("Center").Cursor("Hand").Background("#3A3A4C").Foreground("White").BorderThickness("1").BorderBrush("#5A5A6C")
        ; 表名/序号（仅Excel时显示，默认值1）
        nameOrSerial := d.HasOwnProp("NameOrSerial") ? d.NameOrSerial : 1
        this._AddFieldRow(body, "FIOSheetRow_" id, GetLang("表名："), "FIOSheet_" id, nameOrSerial, IsExcel, true, "", "", "", lw, cw)
        this._AddComboRow(body, "FIOEncRow_" id, GetLang("编码："), "FIOEncCmb_" id, encodings, this._IndexInLangArr(encodings, GetLang(enc)), IsText, true, lw, cw)
        this._AddEditableComboRow(body, "FIORowRow_" id, GetLang("行号："), "FIORow_" id, GetGuiVarArr(), d.HasOwnProp("rowVar") ? d.rowVar : 1, IsExcel, lw, cw)
        this._AddEditableComboRow(body, "FIOColRow_" id, GetLang("列号："), "FIOCol_" id, GetGuiVarArr(), d.HasOwnProp("colVar") ? d.colVar : 1, IsExcel, lw, cw)
        this._AddEditableComboRow(body, "FIORowEndRow_" id, GetLang("终止行："), "FIORowEnd_" id, GetGuiVarArr(), d.HasOwnProp("rowEndVar") ? d.rowEndVar : 1, HasRegion, lw, cw)
        this._AddEditableComboRow(body, "FIOColEndRow_" id, GetLang("终止列："), "FIOColEnd_" id, GetGuiVarArr(), d.HasOwnProp("colEndVar") ? d.colEndVar : 1, HasRegion, lw, cw)
        this._AddEditableComboRow(body, "FIOTxtRowRow_" id, GetLang("文本行："), "FIOTxtRow_" id, GetGuiVarArr(), d.HasOwnProp("textRowVar") ? d.textRowVar : 1, HasTextRow, lw, cw)
        this._AddMultilineFieldBlock(body, "FIOContentBlock_" id, GetLang("写入内容："), "FIOContent_" id, d.HasOwnProp("content") ? d.content : GetLang("写入的内容"), HasWriteContent, this._FormalContentW())
        this._AddEditableComboRow(body, "FIOArrRow_" id, GetLang("数组名："), "FIOArr_" id, GetGuiArrNameArr(), d.HasOwnProp("arrName") ? d.arrName : "Arr", HasWriteArr, lw, cw)
        this._AddComboRow(body, "FIOSaveTypeRow_" id, GetLang("保存类型："), "FIOSaveTypeCmb_" id, saveTypes, this._IndexInLangArr(saveTypes, GetLang(st)), IsRead || HasWriteArr, true, lw, cw)
        this._AddEditableComboRow(body, "FIOSaveRow_" id, GetLang("保存名："), "FIOSave_" id, GetGuiVarArr(), sn, IsRead || HasWriteArr, lw, cw)
        this._AddFormalHint(body)
    }

    _FillTextOpsBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        typeNames := GetLangArr(["文本分割", "文本替换", "文本提取", "去除空格", "大小写转换", "文本统计", "文本拼接"])
        saveTypes := GetLangArr(["变量", "数组"])
        tt := d.HasOwnProp("textOpsType") ? d.textOpsType : "文本分割"
        tn := d.HasOwnProp("textName") ? d.textName : "TextVar"
        at := d.HasOwnProp("argsType") ? d.argsType : ","
        an := d.HasOwnProp("argsName") ? d.argsName : ","
        sr := d.HasOwnProp("search") ? d.search : ""
        rp := d.HasOwnProp("replace") ? d.replace : ""
        st := d.HasOwnProp("saveType") ? d.saveType : "变量"
        sn := d.HasOwnProp("saveName") ? d.saveName : "Data"
        IsReplace := tt == "文本替换"
        IsSplit := tt == "文本分割"
        IsGetEx := tt == "文本提取"
        IsConcat := tt == "文本拼接"
        ShowArgsType := IsSplit || IsGetEx || tt == "大小写转换" || tt == "去除空格" || tt == "文本统计" || IsConcat || IsReplace
        ShowArgsName := IsSplit || IsConcat || IsGetEx
        argsItems := this._FormalTextOpsArgsTypes(tt)
        argsIdx := argsItems.Length ? this._IndexInLangArr(argsItems, GetLang(at)) : 0
        this._AddComboRow(body, "TxtTypeRow_" id, GetLang("类型："), "TxtTypeCmb_" id, typeNames, this._IndexInLangArr(typeNames, GetLang(tt)), true, true, lw, cw)
        this._AddEditableComboRow(body, "TxtNameRow_" id, GetLang("文本变量："), "TxtName_" id, GetGuiVarArr(), tn, true, lw, cw)
        this._AddComboRow(body, "TxtArgsTypeRow_" id, GetLang("参数类型："), "TxtArgsTypeCmb_" id, argsItems, argsIdx, ShowArgsType && argsItems.Length > 0, true, lw, cw)
        this._AddEditableComboRow(body, "TxtArgsNameRow_" id, GetLang("参数值："), "TxtArgsName_" id, GetGuiVarArr(2), an, ShowArgsName, lw, cw)
        this._AddFieldRow(body, "TxtSearchRow_" id, GetLang("查找："), "TxtSearch_" id, sr, IsReplace, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "TxtReplaceRow_" id, GetLang("替换："), "TxtReplace_" id, rp, IsReplace, true, "", "", "", lw, cw)
        this._AddComboRow(body, "TxtSaveTypeRow_" id, GetLang("保存类型："), "TxtSaveTypeCmb_" id, saveTypes, this._IndexInLangArr(saveTypes, GetLang(st)), true, true, lw, cw)
        this._AddEditableComboRow(body, "TxtSaveRow_" id, GetLang("保存名："), "TxtSave_" id, GetGuiVarArr(), sn, true, lw, cw)
        this._AddFormalHint(body)
    }

    _FillArrayBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        typeNames := GetLangArr(["创建", "克隆", "删除", "包含", "取值", "赋值", "插入", "追加", "移除", "移除最后", "反转", "长度"])
        saveTypes := GetLangArr(["变量", "数组"])
        argsTypes := GetLangArr(["变量或值", "数组"])
        at := d.HasOwnProp("arrayType") ? d.arrayType : "创建"
        an := d.HasOwnProp("arrayName") ? d.arrayName : "Arr"
        ign := d.HasOwnProp("isIgnoreExist") ? d.isIgnoreExist : 0
        initTxt := d.HasOwnProp("initArr") ? this._FormalInitArrText(d.initArr) : "1,2,3,4,5"
        mi := d.HasOwnProp("mainIndex") ? d.mainIndex : 0
        ai := d.HasOwnProp("argsIndex") ? d.argsIndex : 1
        agt := d.HasOwnProp("argsType") ? d.argsType : "变量或值"
        agn := d.HasOwnProp("argsName") ? d.argsName : "Var1"
        st := d.HasOwnProp("saveType") ? d.saveType : "变量"
        sn := d.HasOwnProp("saveName") ? d.saveName : "Data"
        IsCreate := at == "创建"
        IsClone := at == "克隆"
        IsDelete := at == "删除"
        IsContain := at == "包含"
        IsGet := at == "取值"
        IsSetValue := at == "赋值"
        IsInsert := at == "插入"
        IsAdd := at == "追加"
        IsRemove := at == "移除"
        IsReverse := at == "反转"
        IsLength := at == "长度"
        IsRemoveLast := at == "移除最后"
        IsShowResult := IsGet || IsLength || IsClone || IsRemove || IsRemoveLast || IsContain || IsReverse
        IsShowMainIndex := !IsCreate && !IsDelete
        IsShowArgs := IsGet || IsSetValue || IsInsert || IsAdd || IsRemove || IsContain
        ShowIgn := IsCreate || IsClone || IsGet || IsLength || IsRemove || IsRemoveLast || IsContain
        this._AddComboRow(body, "ArrTypeRow_" id, GetLang("操作："), "ArrTypeCmb_" id, typeNames, this._IndexInLangArr(typeNames, GetLang(at)), true, true, lw, cw)
        this._AddEditableComboRow(body, "ArrNameRow_" id, GetLang("数组："), "ArrName_" id, GetGuiArrNameArr(), an, true, lw, cw)
        this._AddCheckRow(body, "ArrIgnRow_" id, "ArrIgn_" id, GetLang("忽略已存在"), (ign == 1 || ign == "1") && ShowIgn, ShowIgn)
        this._AddFieldRow(body, "ArrInitRow_" id, GetLang("初始值："), "ArrInit_" id, initTxt, IsCreate, true, "", "", "", lw, cw)
        this._AddEditableComboRow(body, "ArrMainRow_" id, GetLang("主索引："), "ArrMain_" id, GetGuiVarArr(), mi, IsShowMainIndex, lw, cw)
        this._AddEditableComboRow(body, "ArrArgsIdxRow_" id, GetLang("参数索引："), "ArrArgsIdx_" id, GetGuiVarArr(), ai, IsShowArgs, lw, cw)
        this._AddComboRow(body, "ArrArgsTypeRow_" id, GetLang("参数类型："), "ArrArgsTypeCmb_" id, argsTypes, this._IndexInLangArr(argsTypes, GetLang(agt)), IsShowArgs, true, lw, cw)
        this._AddEditableComboRow(body, "ArrArgsNameRow_" id, GetLang("参数值："), "ArrArgsName_" id, GetGuiVarArr(), agn, IsShowArgs, lw, cw)
        this._AddComboRow(body, "ArrSaveTypeRow_" id, GetLang("保存类型："), "ArrSaveTypeCmb_" id, saveTypes, this._IndexInLangArr(saveTypes, GetLang(st)), IsShowResult, true, lw, cw)
        this._AddEditableComboRow(body, "ArrSaveRow_" id, GetLang("保存名："), "ArrSave_" id, GetGuiVarArr(), sn, IsShowResult, lw, cw)
        this._AddFormalHint(body)
    }

    _FillRmtBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        ops := this._RmtOpList()
        op := d.HasOwnProp("rmtOp") ? d.rmtOp : GetLang("截图")
        menuIdx := d.HasOwnProp("rmtMenuIdx") ? Integer(d.rmtMenuIdx) : 1
        menuItems := this._FormalMenuIndexItems()
        showMenu := op == GetLang("显示菜单")
        this._AddComboRow(body, "RmtOpRow_" id, GetLang("操作："), "RmtOpCmb_" id, ops, this._RmtOpIndex(op), true, true, lw, cw)
        this._AddComboRow(body, "RmtMenuRow_" id, GetLang("菜单序号："), "RmtMenuCmb_" id, menuItems, Max(0, menuIdx - 1), showMenu && menuItems.Length > 0, showMenu, lw, cw)
        this._AddFormalHint(body)
    }

    _FillBGMouseBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        varList := GetGuiVarArr()
        opTypes := GetLangArr(["点击", "双击", "按下", "松开"])
        mouseTypes := GetLangArr(["左键", "中键", "右键", "滚轮"])
        ot := d.HasOwnProp("bgOperateType") ? d.bgOperateType : 1
        mt := d.HasOwnProp("bgMouseType") ? d.bgMouseType : 1
        isScroll := mt == 4
        tt := d.HasOwnProp("targetTitle") ? d.targetTitle : ""
        px := d.HasOwnProp("bgPosVarX") ? d.bgPosVarX : 100
        py := d.HasOwnProp("bgPosVarY") ? d.bgPosVarY : 100
        sv := d.HasOwnProp("scrollV") ? d.scrollV : 1
        sh := d.HasOwnProp("scrollH") ? d.scrollH : 0
        ct := d.HasOwnProp("clickTime") ? d.clickTime : 50
        this._AddFieldRow(body, "BgmTitleRow_" id, GetLang("窗口标题："), "BgmTitle_" id, tt, true, true, "", "", "", lw, cw)
        this._AddComboRow(body, "BgmOpRow_" id, GetLang("动作："), "BgmOpCmb_" id, opTypes, ot - 1, !isScroll, !isScroll, lw, cw)
        this._AddComboRow(body, "BgmMouseRow_" id, GetLang("按键："), "BgmMouseCmb_" id, mouseTypes, mt - 1, true, true, lw, cw)
        this._AddEditableComboRow(body, "BgmXRow_" id, GetLang("坐标X："), "BgmX_" id, varList, px, !isScroll, lw, cw)
        this._AddEditableComboRow(body, "BgmYRow_" id, GetLang("坐标Y："), "BgmY_" id, varList, py, !isScroll, lw, cw)
        this._AddFieldRow(body, "BgmSVRow_" id, GetLang("垂直滚动："), "BgmSV_" id, sv, isScroll, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "BgmSHRow_" id, GetLang("水平滚动："), "BgmSH_" id, sh, isScroll, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "BgmTimeRow_" id, GetLang("点击时间："), "BgmTime_" id, ct, !isScroll, true, "", "", "", lw, cw)
        this._AddFormalHint(body)
    }

    _FillBGKeyBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        typeNames := GetLangArr(["按下", "松开", "点击"])
        tt := d.HasOwnProp("bgKeyType") ? d.bgKeyType : 1
        cnt := d.HasOwnProp("bgKeyCount") ? d.bgKeyCount : 0
        fs := d.HasOwnProp("frontStr") ? d.frontStr : ""
        ctm := d.HasOwnProp("clickTime") ? d.clickTime : 100
        cc := d.HasOwnProp("clickCount") ? d.clickCount : 1
        ci := d.HasOwnProp("clickInterval") ? d.clickInterval : 100
        isClick := tt == 3
        this._AddComboRow(body, "BgkTypeRow_" id, GetLang("类型："), "BgkTypeCmb_" id, typeNames, tt - 1, true, true, lw, cw)
        this._AddFieldRow(body, "BgkFrontRow_" id, GetLang("前置文本："), "BgkFront_" id, fs, true, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "BgkTimeRow_" id, GetLang("点击时长："), "BgkTime_" id, ctm, isClick, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "BgkCountRow_" id, GetLang("点击次数："), "BgkCount_" id, cc, isClick, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "BgkInterRow_" id, GetLang("每次间隔："), "BgkInter_" id, ci, isClick, true, "", "", "", lw, cw)
        body.Add("TextBlock").Name("BgkHint_" id).Text(cnt " " GetLang("键")).Foreground("#DDDDDD").FontSize(this._MGFontSize(11)).Margin("0,5,0,0")
        this._AddFormalHint(body)
    }

    _FillWindowManageBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        varList := GetGuiVarArr()
        actions := GetLangArr(["激活窗口", "最大化窗口", "最小化窗口", "还原窗口", "关闭窗口", "移动窗口",
            "调整大小", "置顶窗口", "取消置顶", "修改标题", "修改透明度"])
        at := d.HasOwnProp("wmActionType") ? d.wmActionType : "激活窗口"
        sv := d.HasOwnProp("wmSearchValue") ? d.wmSearchValue : ""
        isMove := at == "移动窗口"
        isSize := at == "调整大小"
        isTitle := at == "修改标题"
        isTrans := at == "修改透明度"
        this._AddComboRow(body, "WmActRow_" id, GetLang("操作："), "WmActCmb_" id, actions, this._IndexInLangArr(actions, GetLang(at)), true, true, lw, cw)
        this._AddFieldRow(body, "WmWinRow_" id, GetLang("窗口信息："), "WmWin_" id, sv, true, true, "", "", "", lw, cw)
        this._AddEditableComboRow(body, "WmXRow_" id, GetLang("坐标X："), "WmX_" id, varList, d.HasOwnProp("wmPosX") ? d.wmPosX : 0, isMove, lw, cw)
        this._AddEditableComboRow(body, "WmYRow_" id, GetLang("坐标Y："), "WmY_" id, varList, d.HasOwnProp("wmPosY") ? d.wmPosY : 0, isMove, lw, cw)
        this._AddEditableComboRow(body, "WmWRow_" id, GetLang("宽度："), "WmW_" id, varList, d.HasOwnProp("wmWidth") ? d.wmWidth : 0, isSize, lw, cw)
        this._AddEditableComboRow(body, "WmHRow_" id, GetLang("高度："), "WmH_" id, varList, d.HasOwnProp("wmHeight") ? d.wmHeight : 0, isSize, lw, cw)
        this._AddEditableComboRow(body, "WmTitleRow_" id, GetLang("新标题："), "WmTitle_" id, varList, d.HasOwnProp("wmNewTitle") ? d.wmNewTitle : "", isTitle, lw, cw)
        this._AddEditableComboRow(body, "WmTransRow_" id, GetLang("透明度："), "WmTrans_" id, varList, d.HasOwnProp("wmTransparency") ? d.wmTransparency : "80", isTrans, lw, cw)
        this._AddFormalHint(body)
    }

    _FillKeyCheckBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        checkTypes := GetLangArr(["同时按下", "有一个按下"])
        stateTypes := GetLangArr(["物理状态", "逻辑状态"])
        ct := d.HasOwnProp("kcCheckType") ? d.kcCheckType : 1
        st := d.HasOwnProp("kcStateType") ? d.kcStateType : 1
        vn := d.HasOwnProp("kcVarName") ? d.kcVarName : ""
        kcnt := d.HasOwnProp("kcKeyCount") ? d.kcKeyCount : 0
        this._AddComboRow(body, "KcCheckRow_" id, GetLang("检测："), "KcCheckCmb_" id, checkTypes, ct - 1, true, true, lw, cw)
        this._AddComboRow(body, "KcStateRow_" id, GetLang("状态类型："), "KcStateCmb_" id, stateTypes, st - 1, true, true, lw, cw)
        this._AddEditableComboRow(body, "KcVarRow_" id, GetLang("变量："), "KcVar_" id, GetGuiVarArr(), vn, true, lw, cw)
        body.Add("TextBlock").Name("KcHint_" id).Text(kcnt " " GetLang("键")).Foreground("#DDDDDD").FontSize(this._MGFontSize(11)).Margin("0,5,0,0")
        this._AddFormalHint(body)
    }

    _FillScreenShotBody(id, d, body) {
        lw := this._FormalLW(), cw := this._FormalCW()
        varList := GetGuiVarArr()
        typeNames := GetLangArr(["屏幕抓图", "窗口抓图"])
        nameTypes := GetLangArr(["默认", "固定名称"])
        st := d.HasOwnProp("ssType") ? d.ssType : 1
        isWin := st == 2
        nt := d.HasOwnProp("ssNameType") ? d.ssNameType : 1
        toggle := d.HasOwnProp("ssResultToggle") ? d.ssResultToggle : 0
        rn := d.HasOwnProp("ssResultSaveName") ? d.ssResultSaveName : GetLang("图片路径")
        this._AddComboRow(body, "SsTypeRow_" id, GetLang("类型："), "SsTypeCmb_" id, typeNames, st - 1, true, true, lw, cw)
        this._AddFieldRow(body, "SsWinRow_" id, GetLang("窗口信息："), "SsWin_" id, d.HasOwnProp("ssWinInfo") ? d.ssWinInfo : "", isWin, true, "", "", "", lw, cw)
        this._AddEditableComboRow(body, "SsSXRow_" id, GetLang("起始X："), "SsSX_" id, varList, d.HasOwnProp("ssStartX") ? d.ssStartX : 0, true, lw, cw)
        this._AddEditableComboRow(body, "SsSYRow_" id, GetLang("起始Y："), "SsSY_" id, varList, d.HasOwnProp("ssStartY") ? d.ssStartY : 0, true, lw, cw)
        this._AddEditableComboRow(body, "SsEXRow_" id, GetLang("终止X："), "SsEX_" id, varList, d.HasOwnProp("ssEndX") ? d.ssEndX : A_ScreenWidth, true, lw, cw)
        this._AddEditableComboRow(body, "SsEYRow_" id, GetLang("终止Y："), "SsEY_" id, varList, d.HasOwnProp("ssEndY") ? d.ssEndY : A_ScreenHeight, true, lw, cw)
        this._AddComboRow(body, "SsNameTypeRow_" id, GetLang("命名方式："), "SsNameTypeCmb_" id, nameTypes, nt - 1, true, true, lw, cw)
        this._AddFieldRow(body, "SsFixedRow_" id, GetLang("固定名称："), "SsFixed_" id, d.HasOwnProp("ssFixedName") ? d.ssFixedName : "", nt == 2, true, "", "", "", lw, cw)
        this._AddFieldRow(body, "SsPathRow_" id, GetLang("保存路径："), "SsPath_" id, d.HasOwnProp("ssSavePath") ? d.ssSavePath : "", true, true, "", "", "", lw, cw)
        this._AddCheckRow(body, "SsResTogRow_" id, "SsResTog_" id, GetLang("保存到变量"), toggle == 1 || toggle == "1", true)
        this._AddEditableComboRow(body, "SsResNameRow_" id, GetLang("变量名："), "SsResName_" id, varList, rn, toggle == 1 || toggle == "1", lw, cw)
        this._AddFormalHint(body)
    }

    _IndexInLangArr(arr, target) {
        loop arr.Length {
            if (arr[A_Index] == target)
                return A_Index - 1
        }
        return 0
    }

    _RegisterFormalNodeEvents(id, d, runtime := false) {
        t := d.type
        if (t == GetLang("宏操作")) {
            h := this._OnFormalSubMacro.Bind(this, id)
            this._FormalTrackCombo(id, "SubTypeCmb", h, runtime)
            this._FormalTrackCombo(id, "SubCallCmb", h, runtime)
            this._FormalTrackCombo(id, "SubIdxCmb", h, runtime)
            this._FormalTrackEditCombo(id, "SubIns", h, runtime)
        } else if (t == GetLang("变量")) {
            h := this._OnFormalVariable.Bind(this, id)
            this._FormalTrackCheck(id, "VarIgn", h, runtime)
            loop 4 {
                p := "VarS" A_Index
                this._FormalTrackCheck(id, p "Tog", h, runtime)
                this._FormalTrackCombo(id, p "OpCmb", h, runtime)
                this._FormalTrackEditCombo(id, p "Name", h, runtime)
                this._FormalTrackEditCombo(id, p "Copy", h, runtime)
                this._FormalTrackField(id, p "CopyTxt", h, runtime)
                this._FormalTrackCombo(id, p "SysCmb", h, runtime)
                this._FormalTrackEditCombo(id, p "Min", h, runtime)
                this._FormalTrackEditCombo(id, p "Max", h, runtime)
            }
        } else if (t == GetLang("变量提取")) {
            h := this._OnFormalExVariable.Bind(this, id)
            this._FormalTrackCheck(id, "ExIgn", h, runtime)
            this._FormalTrackCombo(id, "ExTypeCmb", h, runtime)
            this._FormalTrackField(id, "ExStr", h, runtime)
            this._BindCtrl("ExStrEdit_" id, "Click", this._OnFormalExTemplateEdit.Bind(this, id), runtime)
            this._FormalTrackField(id, "ExWin", h, runtime)
            this._FormalTrackCombo(id, "ExOcrCmb", h, runtime)
            for nm in ["ExSX", "ExSY", "ExEX", "ExEY", "ExCnt"]
                this._FormalTrackEditCombo(id, nm, h, runtime)
            this._FormalTrackField(id, "ExInt", h, runtime)
            loop 6 {
                p := "ExV" A_Index
                this._FormalTrackCheck(id, p "Tog", h, runtime)
                this._FormalTrackEditCombo(id, p "Name", h, runtime)
            }
        } else if (t == GetLang("运算")) {
            h := this._OnFormalOperation.Bind(this, id)
            loop 4 {
                p := "OpS" A_Index
                this._FormalTrackCheck(id, p "Tog", h, runtime)
                this._FormalTrackEditCombo(id, p "Target", h, runtime)
                this._FormalTrackField(id, p "Expr", h, runtime)
                this._BindCtrl(p "ExprEdit_" id, "Click", this._OnOperationExprEdit.Bind(this, id, A_Index), runtime)
            }
        } else if (t == GetLang("运行")) {
            h := this._OnFormalRun.Bind(this, id)
            this._FormalTrackField(id, "RunPath", h, runtime)
            this._BindCtrl("RunPathBrowse_" id, "Click", this._OnRunPathBrowse.Bind(this, id), runtime)
            this._FormalTrackCombo(id, "RunModeCmb", h, runtime)
            loop 3
                this._FormalTrackEditCombo(id, "RunSave" A_Index, h, runtime)
        } else if (t == GetLang("文件读写")) {
            h := this._OnFormalFileIO.Bind(this, id)
            this._FormalTrackCombo(id, "FIOTypeCmb", h, runtime)
            this._FormalTrackCombo(id, "FIOModeCmb", h, runtime)
            this._FormalTrackField(id, "FIOPath", h, runtime)
            this._BindCtrl("FIOPathBrowse_" id, "Click", this._OnFIOPathBrowse.Bind(this, id), runtime)
            this._FormalTrackField(id, "FIOSheet", h, runtime)
            this._FormalTrackCombo(id, "FIOEncCmb", h, runtime)
            for nm in ["FIORow", "FIOCol", "FIORowEnd", "FIOColEnd", "FIOTxtRow", "FIOArr", "FIOSave"]
                this._FormalTrackEditCombo(id, nm, h, runtime)
            this._FormalTrackField(id, "FIOContent", h, runtime)
            this._FormalTrackCombo(id, "FIOSaveTypeCmb", h, runtime)
        } else if (t == GetLang("文本处理")) {
            h := this._OnFormalTextOps.Bind(this, id)
            this._FormalTrackCombo(id, "TxtTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "TxtName", h, runtime)
            this._FormalTrackCombo(id, "TxtArgsTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "TxtArgsName", h, runtime)
            this._FormalTrackField(id, "TxtSearch", h, runtime)
            this._FormalTrackField(id, "TxtReplace", h, runtime)
            this._FormalTrackCombo(id, "TxtSaveTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "TxtSave", h, runtime)
        } else if (t == GetLang("数组")) {
            h := this._OnFormalArray.Bind(this, id)
            this._FormalTrackCombo(id, "ArrTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "ArrName", h, runtime)
            this._FormalTrackCheck(id, "ArrIgn", h, runtime)
            this._FormalTrackField(id, "ArrInit", h, runtime)
            this._FormalTrackEditCombo(id, "ArrMain", h, runtime)
            this._FormalTrackEditCombo(id, "ArrArgsIdx", h, runtime)
            this._FormalTrackCombo(id, "ArrArgsTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "ArrArgsName", h, runtime)
            this._FormalTrackCombo(id, "ArrSaveTypeCmb", h, runtime)
            this._FormalTrackEditCombo(id, "ArrSave", h, runtime)
        } else if (t == GetLang("RMT指令")) {
            h := this._OnFormalRmt.Bind(this, id)
            this._FormalTrackCombo(id, "RmtOpCmb", h, runtime)
            this._FormalTrackCombo(id, "RmtMenuCmb", h, runtime)
        } else if (t == GetLang("后台鼠标")) {
            h := this._OnFormalBGMouse.Bind(this, id)
            this._FormalTrackField(id, "BgmTitle", h, runtime)
            this._FormalTrackCombo(id, "BgmOpCmb", h, runtime)
            this._FormalTrackCombo(id, "BgmMouseCmb", h, runtime)
            this._FormalTrackEditCombo(id, "BgmX", h, runtime)
            this._FormalTrackEditCombo(id, "BgmY", h, runtime)
            this._FormalTrackField(id, "BgmSV", h, runtime)
            this._FormalTrackField(id, "BgmSH", h, runtime)
            this._FormalTrackField(id, "BgmTime", h, runtime)
        } else if (t == GetLang("后台按键")) {
            h := this._OnFormalBGKey.Bind(this, id)
            this._FormalTrackCombo(id, "BgkTypeCmb", h, runtime)
            this._FormalTrackField(id, "BgkFront", h, runtime)
            this._FormalTrackField(id, "BgkTime", h, runtime)
            this._FormalTrackField(id, "BgkCount", h, runtime)
            this._FormalTrackField(id, "BgkInter", h, runtime)
        } else if (t == GetLang("窗口管理")) {
            h := this._OnFormalWindowManage.Bind(this, id)
            this._FormalTrackCombo(id, "WmActCmb", h, runtime)
            this._FormalTrackField(id, "WmWin", h, runtime)
            for nm in ["WmX", "WmY", "WmW", "WmH", "WmTitle", "WmTrans"]
                this._FormalTrackEditCombo(id, nm, h, runtime)
        } else if (t == GetLang("按键检测")) {
            h := this._OnFormalKeyCheck.Bind(this, id)
            this._FormalTrackCombo(id, "KcCheckCmb", h, runtime)
            this._FormalTrackCombo(id, "KcStateCmb", h, runtime)
            this._FormalTrackEditCombo(id, "KcVar", h, runtime)
        } else if (t == GetLang("抓图")) {
            h := this._OnFormalScreenShot.Bind(this, id)
            this._FormalTrackCombo(id, "SsTypeCmb", h, runtime)
            this._FormalTrackField(id, "SsWin", h, runtime)
            for nm in ["SsSX", "SsSY", "SsEX", "SsEY"]
                this._FormalTrackEditCombo(id, nm, h, runtime)
            this._FormalTrackCombo(id, "SsNameTypeCmb", h, runtime)
            this._FormalTrackField(id, "SsFixed", h, runtime)
            this._FormalTrackField(id, "SsPath", h, runtime)
            this._FormalTrackCheck(id, "SsResTog", h, runtime)
            this._FormalTrackEditCombo(id, "SsResName", h, runtime)
        }
    }
}

_GraftMacroGraphMixin(MacroGraphFormalMixin)
