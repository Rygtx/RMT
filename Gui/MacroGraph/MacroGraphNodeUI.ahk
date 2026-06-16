#Requires AutoHotkey v2.0

; ============================================================================
; MacroGraphGui 职能拆分 —— 节点界面构建
;
; 节点外壳/标题/端口、各指令类型节点主体填充、搜索Pro 主体、行控件辅助、
; 真/假分支节点的界面构建与刷新等。方法体保持原样，this 仍为 MacroGraphGui 实例，
; 通过 _GraftMacroGraphMixin 嫁接到 MacroGraphGui.Prototype。
; ============================================================================

class MacroGraphNodeUIMixin {
    ; 图形节点字号整体偏移（临时 +1，确认效果后改回 0 即可回退）
    _MGFontSize(base) {
        return String(base + 1)
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
        nodeW := this._IsFormalNodeType(d.type) ? this._FormalNodeWidth(d.type) : ""
        body := ""
        this._NewNodeShell(id, d.type, "Process", &body, nodeW)
        this._FillNodeBody(id, d, body)
        if (d.type == GetLang("如果Pro") && this._nodeShellGrid != "")
            this._AddIfProBranchPortEls(this._nodeShellGrid, id)
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
            body.Add("TextBlock").Name("KeyName_" id).Text(d.key).Foreground("#FFD27F").FontWeight("Bold").FontSize(this._MGFontSize(13)).TextWrapping("Wrap")

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
            shotBtn := ops.Add("Button").Name("SShot_" id).Content(GetLang("截图")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
            picBtn := ops.Add("Button").Name("SPic_" id).Content(GetLang("选择图片")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
            pickBtn := ops.Add("Button").Name("SPick_" id).Content(GetLang("定位取色器")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
            ops.Add("Button").Name("SArea_" id).Content(GetLang("框选范围")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
            if (st != 1) {
                shotBtn.Visibility("Collapsed")
                picBtn.Visibility("Collapsed")
            }
            if (st != 2)
                pickBtn.Visibility("Collapsed")
            ; 真/假分支以「强制绑定的外部分支节点」呈现（见 _BuildBranchPair），此处不再内嵌泳道
        }
        else if (d.type == GetLang("输入")) {
            typeKey := d.HasOwnProp("inputType") ? d.inputType : "弹窗"
            pauseKey := d.HasOwnProp("pauseType") ? d.pauseType : "暂停当前宏"
            cancelKey := d.HasOwnProp("cancelType") ? d.cancelType : "终止当前宏"
            saveName := d.HasOwnProp("saveName") ? d.saveName : "Data"
            showCancel := (typeKey == "继续&取消")
            showRes := (typeKey == "弹窗" || typeKey == "状态")
            typeNames := GetLangArr(["弹窗", "状态", "继续", "继续&取消"])
            pauseNames := GetLangArr(["暂停当前宏", "暂停所有宏"])
            cancelNames := GetLangArr(["终止当前宏", "终止所有宏"])
            varList := GetGuiVarArr()
            this._AddComboRow(body, "InTypeRow_" id, GetLang("输入类型:"), "InTypeCmb_" id, typeNames, this._InputTypeIndex(typeKey), true)
            this._AddComboRow(body, "InPauseRow_" id, GetLang("交互时:"), "InPauseCmb_" id, pauseNames, this._InputPauseTypeIndex(pauseKey), true)
            this._AddComboRow(body, "InCancelRow_" id, GetLang("取消时:"), "InCancelCmb_" id, cancelNames, this._InputCancelTypeIndex(cancelKey), showCancel)
            this._AddEditableComboRow(body, "InSaveRow_" id, GetLang("保存变量") "：", "InSave_" id, varList, saveName, showRes)
        }
        else if (d.type == GetLang("输出")) {
            ; 内容区略收紧左右边距，使多行输出文本更贴边
            body.Margin("6,6,6,8")
            outputTypeKey := d.HasOwnProp("outputType") ? d.outputType : "发送内容"
            isCharVar := (outputTypeKey == "字符变量")
            outputTypeNames := GetLangArr(["发送内容", "粘贴内容", "临时提示", "指令窗口", "软件弹窗", "系统语音", "复制到剪切板", "字符变量"])
            textVal := d.HasOwnProp("text") ? GetLangStr(d.text, 1) : GetLang("将要输出的文本")
            varName := (d.HasOwnProp("variableName") && d.variableName != "") ? d.variableName : "Data"
            varList := GetGuiVarArr()
            this._AddComboRow(body, "OutTypeRow_" id, GetLang("输出类型:"), "OutTypeCmb_" id, outputTypeNames, this._OutputTypeIndex(outputTypeKey), true)
            this._AddEditableComboRow(body, "OutVarRow_" id, GetLang("保存变量") "：", "OutVar_" id, varList, varName, isCharVar)
            ; 节点宽 200、左右 margin 6 → 内容区 188，与下方单行控件同宽
            this._AddMultilineFieldBlock(body, "OutTextBlock_" id, GetLang("输出内容："), "OutText_" id, textVal, true, "188")
        }
        else if (this._IsFormalNodeType(d.type)) {
            body.Margin("10,6,10,8")
            this._FillFormalNodeBody(id, d, body)
        }
        else {
            body.Add("TextBlock").Text(GetLang("临时节点")).Foreground("#FF9E9E").FontSize(this._MGFontSize(12))
            body.Add("TextBlock").Text(d.raw).Foreground("#DDDDDD").FontSize(this._MGFontSize(11)).TextWrapping("Wrap")
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
        winRow.Add("TextBlock").Text(GetLang("窗口信息:")).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(LW).VerticalAlignment("Center")
        this._MakeTextBox(winRow, "SWin_" id, d.HasOwnProp("winInfo") ? d.winInfo : "", "196")
        winRow.Add("Button").Name("SWinEdit_" id).Content(GetLang("编辑")).FontSize(this._MGFontSize(11)).Height("20").Margin("4,0,0,0").Padding("8,0")

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
        shotBtn := ops.Add("Button").Name("SShot_" id).Content(GetLang("截图")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
        picBtn := ops.Add("Button").Name("SPic_" id).Content(GetLang("选择图片")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
        pickBtn := ops.Add("Button").Name("SPick_" id).Content(GetLang("定位取色器")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
        ops.Add("Button").Name("SArea_" id).Content(GetLang("框选范围")).FontSize(this._MGFontSize(11)).Height("22").Margin("0,0,4,4").Padding("6,0")
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
        cell.Add("TextBlock").Text(label).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(lw).VerticalAlignment("Center")
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
        cell.Add("TextBlock").Text(label).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(lw).VerticalAlignment("Center")
        cmb := cell.Add("ComboBox").Name(comboName).Width(cw).Height("22").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,0").MaxDropDownHeight("200").Foreground("White").IsEditable("True").IsTextSearchEnabled("False")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
        cmb.SetProp("Text", textVal)
    }

    ; 行内单元格：标签 + 不可编辑下拉（类型选择等）
    _ProCellCombo(rowSP, cellName, label, comboName, items, selIndex, visible, lw, cw, rightCell) {
        cell := rowSP.Add("StackPanel").Name(cellName).Orientation("Horizontal")
        if (rightCell)
            cell.Margin("14,0,0,0")
        if (!visible)
            cell.Visibility("Collapsed")
        cell.Add("TextBlock").Text(label).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(lw).VerticalAlignment("Center")
        cmb := cell.Add("ComboBox").Name(comboName).Width(cw).Height("22").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,0").MaxDropDownHeight("200").SelectedIndex(selIndex)
            .Background("{DynamicResource ControlBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
    }

    ; 行内单元格：复选框
    _ProCellCheck(rowSP, cellName, chkName, label, isChecked, visible, rightCell) {
        cell := rowSP.Add("StackPanel").Name(cellName).Orientation("Horizontal")
        if (rightCell)
            cell.Margin("14,0,0,0")
        if (!visible)
            cell.Visibility("Collapsed")
        chk := cell.Add("CheckBox").Name(chkName).Content(label).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
        if (isChecked == 1 || isChecked == "1")
            chk.IsChecked("True")
    }

    ; 提取变量单元格：复选框「变量N」+ 可编辑下拉（变量名）。名称常显，便于预填，启用与否由复选框控制。
    _FillExVarSlotCell(rowSP, id, slot, d, varList, rightCell) {
        p := "ExV" slot
        toggled := d.HasOwnProp("exToggle" slot) ? d["exToggle" slot] : (slot == 1 ? 1 : 0)
        on := toggled == 1 || toggled == "1"
        vn := d.HasOwnProp("exVariable" slot) ? d["exVariable" slot] : "Var" slot
        cell := rowSP.Add("StackPanel").Name(p "TogRow_" id).Orientation("Horizontal")
        if (rightCell)
            cell.Margin("14,0,0,0")
        chk := cell.Add("CheckBox").Name(p "Tog_" id).Content(GetLang("变量") slot).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).VerticalAlignment("Center").Margin("0,0,4,0")
        if (on)
            chk.IsChecked("True")
        cmb := cell.Add("ComboBox").Name(p "Name_" id).Width("96").Height("22").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,0").MaxDropDownHeight("200").Foreground("White").IsEditable("True").IsTextSearchEnabled("False")
        for it in varList
            cmb.Add("ComboBoxItem").Content(it)
        cmb.SetProp("Text", vn)
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
        chk := sp.Add("CheckBox").Name(togName).Content(title).Foreground("#FFD27F").FontWeight("Bold").FontSize(this._MGFontSize(12))
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
            tfRow.Add("TextBlock").Text(GetLang("真值") "：").Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width("44").VerticalAlignment("Center")
            this._MakeTextBox(tfRow, "SResTrue_" id, "" (d.HasOwnProp("trueValue") ? d.trueValue : 1), "80")
            tfRow.Add("TextBlock").Text(GetLang("假值") "：").Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width("44").Margin("12,0,0,0").VerticalAlignment("Center")
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

    ; 解析分支合成 ID，命中返回 { searchId, isTrue, proIdx }，否则返回 ""
    _BranchInfo(nodeId) {
        if (nodeId != "" && RegExMatch(nodeId, "^(.+)__B([TF])$", &m))
            return { searchId: m[1], isTrue: (m[2] == "T"), proIdx: -1 }
        if (nodeId != "" && RegExMatch(nodeId, "^(.+)__BP(\d+)$", &m2))
            return { searchId: m2[1], isTrue: "", proIdx: Integer(m2[2]) }
        return ""
    }

    _IsBranchId(nodeId) {
        return this._BranchInfo(nodeId) != ""
    }

    ; 把分支节点 ID 归一为其所属父节点 ID；非分支 ID 原样返回
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

    ; 该 id 是否为如果节点
    _IsIfNodeId(id) {
        if (!this.cmdNodes.Has(id))
            return false
        return this._Parse(this.cmdNodes[id].CurCMD).type == GetLang("如果")
    }

    ; 该节点是否处于折叠态（折叠则隐藏分支节点、搜索直连后续）
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

    ; 需要显示真/假/多分支节点的父节点（展开搜索 / 如果 / 如果Pro）
    _HasVisibleBranches(id) {
        return this._IsExpandedSearch(id) || this._IsIfNodeId(id) || this._IsExpandedIfPro(id)
    }

    ; 分支父节点宽度
    _BranchParentWidth(parentId) {
        if (this._IsIfProNodeId(parentId))
            return this._IfProNodeWidth()
        if (this._IsIfNodeId(parentId))
            return 200
        return this._SearchNodeWidth(parentId)
    }

    ; 分支节点标题
    _BranchTitleFor(parentId, isTrue) {
        if (this._IsIfNodeId(parentId))
            return isTrue ? (GetLang("真") "-" GetLang("分支")) : (GetLang("假") "-" GetLang("分支"))
        return isTrue ? GetLang("找到（真）") : GetLang("未找到（假）")
    }

    ; 搜索/搜索Pro 节点宽度（Pro 更宽，分支节点需据此偏移，避免重叠）
    _SearchNodeWidth(searchId) {
        return this._IsNodePro(searchId) ? 380 : 200
    }

    ; 分支节点相对搜索节点的逻辑坐标。
    ; 优先使用节点上「保存过的相对偏移」(TrueBranch*/FalseBranch*)，使收缩/展开/重载后分支位置稳定；
    ; 未保存过时回退到默认计算：X = 节点宽度 + 固定间距（落在右侧、Pro 更宽不重叠），
    ; Y：真分支与搜索齐平、假分支在其下方偏移。
    _BranchPos(searchId, isTrue) {
        sp := this.pos.Has(searchId) ? this.pos[searchId] : { x: 200, y: 200 }
        rel := this._SavedBranchOffset(searchId, isTrue)
        if (rel != "")
            return { x: sp.x + rel.dx, y: sp.y + rel.dy }
        return { x: sp.x + this._BranchParentWidth(searchId) + 100, y: sp.y + (isTrue ? 0 : 210) }
    }

    ; 取节点上保存的分支相对偏移 { dx, dy }；未保存（字段为空）返回 ""
    _SavedBranchOffset(searchId, isTrue) {
        if (!this.cmdNodes.Has(searchId))
            return ""
        node := this.cmdNodes[searchId]
        dxProp := isTrue ? "TrueBranchDX" : "FalseBranchDX"
        dyProp := isTrue ? "TrueBranchDY" : "FalseBranchDY"
        if (!node.HasOwnProp(dxProp) || !node.HasOwnProp(dyProp))
            return ""
        dx := node.%dxProp%, dy := node.%dyProp%
        if (dx == "" || dy == "" || !IsNumber(dx) || !IsNumber(dy))
            return ""
        return { dx: dx + 0, dy: dy + 0 }
    }

    _BranchTitle(isTrue) {
        return isTrue ? GetLang("找到（真）") : GetLang("未找到（假）")
    }

    ; 如果分支流程控制选项
    _IfFlowTypes() {
        return GetLangArr(["无", "循环-跳过本轮", "循环-跳出", "分支-跳出"])
    }

    ; 构建单个分支节点的 Border 元素（标题 + 指令条 + 展开按钮 + 端口）。
    ; asFragment=true 时附带 xmlns 命名空间，供运行时 AddXamlItem 注入。
    _MakeBranchBorderEl(searchId, isTrue, x, y, asFragment := false) {
        brId := this._BranchId(searchId, isTrue)
        headerColor := isTrue ? "#2E7D32" : "#C62828"
        borderColor := isTrue ? "#3FA34D" : "#D04545"
        title := this._BranchTitleFor(searchId, isTrue)

        border := XAMLElement("Border")
        if (asFragment)
            border.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation").SetProp("xmlns:x", "http://schemas.microsoft.com/winfx/2006/xaml")
        border.Name("Node_" brId).Background("{DynamicResource DropdownBg}").BorderBrush(borderColor).BorderThickness("1").CornerRadius("6").Width("200").SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        border.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")
        grid := border.Add("Grid")
        grid.Rows("28", "Auto")
        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background(headerColor).CornerRadius("5,5,0,0")
        hp := header.Add("StackPanel").Orientation("Horizontal").VerticalAlignment("Center").Margin("8,0")
        hp.Add("TextBlock").Text(title).Foreground("White").FontWeight("Bold").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
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
        g.nodes.Push({ Id: brId, Title: this._BranchTitleFor(searchId, isTrue), X: x, Y: y, W: 200, H: 60, Type: "Process" })
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
        g.nodes.Push({ Id: brId, Title: this._BranchTitleFor(searchId, isTrue), X: x, Y: y, W: 200, H: 60, Type: "Process" })
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
            panel.Add("TextBlock").Text("（" GetLang("空") "）").Foreground("#888888").FontSize(this._MGFontSize(11))
        } else {
            Loop shown {
                chip := panel.Add("Border").Background("#33000000").CornerRadius("3").Margin("0,2,0,0").Padding("5,2")
                chip.Add("TextBlock").Text(cmds[A_Index]).Foreground("#DDDDDD").FontSize(this._MGFontSize(11)).TextWrapping("Wrap")
            }
        }
        ; 展开/收起按钮：始终创建（便于运行时显隐），不超过预览条数时隐藏
        btn := body.Add("Button").Name("SBExpand_" brId).Content(expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")")).FontSize(this._MGFontSize(10)).Height("20").Margin("0,4,0,0").Padding("6,0").HorizontalAlignment("Left")
        if (cmds.Length <= this._BranchPreviewCount())
            btn.Visibility("Collapsed")
        ; 如果分支：流程控制在指令执行之后（CompareGui 语义一致）
        if (this._IsIfNodeId(searchId)) {
            flowTypes := this._IfFlowTypes()
            data := this._BranchParentData(searchId)
            ct := "无"
            if (data != "") {
                raw := isTrue ? (data.HasOwnProp("TrueControlType") ? data.TrueControlType : "无") : (data.HasOwnProp("FalseControlType") ? data.FalseControlType : "无")
                ct := GetLang(raw)
            }
            fidx := this._IndexInLangArr(flowTypes, ct)
            if (fidx < 0)
                fidx := this._IndexInLangArr(flowTypes, GetLang(GetLangKey(ct)))
            this._AddComboRow(body, "BrFlowRow_" brId, GetLang("流程控制："), "BrFlowCmb_" brId, flowTypes, Max(0, fidx), true, true, "58", "120")
        }
        body.Add("TextBlock").Text(GetLang("双击编辑分支")).Foreground("#888888").FontSize(this._MGFontSize(10)).Margin("0,4,0,0")
    }

    ; 单个指令小卡片的 XAML 片段（带命名空间，供运行时 AddXamlItem 注入）
    _BranchChipXaml(text) {
        ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
        return '<Border ' ns ' Background="#33000000" CornerRadius="3" Margin="0,2,0,0" Padding="5,2"><TextBlock Text="' this._XmlEsc(text) '" Foreground="#DDDDDD" FontSize="' this._MGFontSize(11) '" TextWrapping="Wrap"/></Border>'
    }

    ; 运行时按当前展开态重建分支指令卡片（清空后重新注入）
    _RebuildBranchChips(brId, cmds, expanded) {
        this.ui.Update("SBChipsPanel_" brId, "ClearItems", "")
        if (cmds.Length == 0) {
            ns := 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
            this.ui.Update("SBChipsPanel_" brId, "AddXamlItem", '<TextBlock ' ns ' Text="（' this._XmlEsc(GetLang("空")) '）" Foreground="#888888" FontSize="' this._MGFontSize(11) '"/>')
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
        if (this._IsIfNodeId(searchId)) {
            flowTypes := this._IfFlowTypes()
            data := this._BranchParentData(searchId)
            ct := "无"
            if (data != "") {
                raw := isTrue ? (data.HasOwnProp("TrueControlType") ? data.TrueControlType : "无") : (data.HasOwnProp("FalseControlType") ? data.FalseControlType : "无")
                ct := GetLang(raw)
            }
            fidx := this._IndexInLangArr(flowTypes, ct)
            if (fidx < 0)
                fidx := this._IndexInLangArr(flowTypes, GetLang(GetLangKey(ct)))
            this.ui.Update("BrFlowCmb_" brId, "SelectedIndex", Max(0, fidx))
        }
        cmds := this._BranchGraphCmds(this._BranchStartSerial(searchId, isTrue))
        expanded := this._branchExpanded.Has(brId) && this._branchExpanded[brId]
        this._RebuildBranchChips(brId, cmds, expanded)
        this.ui.Update("SBExpand_" brId, "Visibility", cmds.Length > this._BranchPreviewCount() ? "Visible" : "Collapsed")
        this.ui.Update("SBExpand_" brId, "Content", expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
    }

    ; 取分支保存内容（图形开始节点序列码 或 线性宏串）
    _BranchStartSerial(searchId, isTrue) {
        data := this._BranchParentData(searchId)
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

    ; ----------------------------------------------------------------- 循环体外置节点（强制绑定，方案B 侧边回环）

    ; 循环体合成 ID："<loopId>__LB"（循环节点本身仍是 cmdNodes 中的 id）
    _LoopBodyId(loopId) {
        return loopId "__LB"
    }

    ; 解析循环体合成 ID，命中返回 { loopId }，否则返回 ""
    _LoopBodyInfo(nodeId) {
        if (nodeId != "" && RegExMatch(nodeId, "^(.+)__LB$", &m))
            return { loopId: m[1] }
        return ""
    }

    _IsLoopBodyId(nodeId) {
        return this._LoopBodyInfo(nodeId) != ""
    }

    ; 该 id 是否为循环节点
    _IsLoopNodeId(id) {
        if (!this.cmdNodes.Has(id))
            return false
        return this._Parse(this.cmdNodes[id].CurCMD).type == GetLang("循环")
    }

    ; 循环节点且未折叠（展开态需显示外置循环体节点）
    _IsExpandedLoop(id) {
        return this._IsLoopNodeId(id) && !this._NodeFolded(id)
    }

    ; 循环节点宽度
    _LoopNodeWidth(loopId) {
        return this._FormalNodeWidth(GetLang("循环"))
    }

    ; 循环体外置节点相对循环节点的逻辑坐标。
    ; 优先使用节点上保存的相对偏移(LoopBodyDX/DY)，未保存时回退默认（落在循环节点右下方）。
    _LoopBodyPos(loopId) {
        sp := this.pos.Has(loopId) ? this.pos[loopId] : { x: 200, y: 200 }
        rel := this._SavedLoopBodyOffset(loopId)
        if (rel != "")
            return { x: sp.x + rel.dx, y: sp.y + rel.dy }
        ; 默认：节点水平间距 50px；纵向偏移 60(网格 20 的整数倍，吸附后仍保持)。
        ; 此偏移下循环右侧两点与循环体左侧两点中心 Y 相等(回环路径为水平直线)：
        ;   循环上点中心=循环Y+90 / 循环体上点(入点位)中心=循环体Y+30=循环Y+90；
        ;   循环下点中心=循环Y+146 / 循环体下点中心=循环体Y+86=循环Y+146。
        return { x: sp.x + this._LoopNodeWidth(loopId) + 50, y: sp.y + 60 }
    }

    ; 取循环节点上保存的循环体相对偏移 { dx, dy }；未保存返回 ""
    _SavedLoopBodyOffset(loopId) {
        if (!this.cmdNodes.Has(loopId))
            return ""
        node := this.cmdNodes[loopId]
        if (!node.HasOwnProp("LoopBodyDX") || !node.HasOwnProp("LoopBodyDY"))
            return ""
        dx := node.LoopBodyDX, dy := node.LoopBodyDY
        if (dx == "" || dy == "" || !IsNumber(dx) || !IsNumber(dy))
            return ""
        return { dx: dx + 0, dy: dy + 0 }
    }

    ; 回环交互点中心 Y 偏移（相对节点顶边，与 _LoopBodyPos 默认 dy=60 配套，吸附后仍水平对齐）。
    _LoopCyEnterY() => 90      ; 循环右侧上点（进入循环体），margin top 54
    _LoopCyReturnY() => 146    ; 循环右侧下点（循环体返回），margin top 110
    _LoopBodyEnterY() => 30    ; 循环体左侧上点（通用入点），margin top -6
    _LoopBodyReturnY() => 86   ; 循环体左侧下点，margin top 50

    ; 给循环节点 grid 追加右侧两个回环交互点（出点不变、入点不变；额外的进入/返回点）。
    _AddLoopCyclePortEls(grid, id) {
        vis := this._NodeFolded(id) ? "Collapsed" : "Visible"
        oEl := XAMLElement("Ellipse")
        oEl.Name("LoopCyO_" id)
        oEl._Props["Width"] := "12", oEl._Props["Height"] := "12"
        oEl._Props["Fill"] := "#5C6BC0", oEl._Props["Stroke"] := "#1A237E", oEl._Props["StrokeThickness"] := "1"
        oEl._Props["Grid.Row"] := "1", oEl._Props["VerticalAlignment"] := "Top", oEl._Props["HorizontalAlignment"] := "Right", oEl._Props["Margin"] := "0,54,-6,0"
        oEl._Props["Panel.ZIndex"] := "10", oEl._Props["Visibility"] := vis, oEl._Props["ToolTip"] := GetLang("进入循环体")
        grid._Children.Push(oEl)
        iEl := XAMLElement("Ellipse")
        iEl.Name("LoopCyI_" id)
        iEl._Props["Width"] := "12", iEl._Props["Height"] := "12"
        iEl._Props["Fill"] := "#9575CD", iEl._Props["Stroke"] := "#311B92", iEl._Props["StrokeThickness"] := "1"
        iEl._Props["Grid.Row"] := "1", iEl._Props["VerticalAlignment"] := "Top", iEl._Props["HorizontalAlignment"] := "Right", iEl._Props["Margin"] := "0,110,-6,0"
        iEl._Props["Panel.ZIndex"] := "10", iEl._Props["Visibility"] := vis, iEl._Props["ToolTip"] := GetLang("循环体返回")
        grid._Children.Push(iEl)
    }

    ; 给循环体外置节点 grid 追加左侧两个回环交互点（与循环节点右侧两点对应连接）。
    ; 上点(BI)对齐通用节点「入点」位置(行顶左缘，中心 Y = 头30)；下点(BO)中心 Y = 头30+56 = 86。
    _AddLoopBodyCyclePortEls(grid, bid) {
        biEl := XAMLElement("Ellipse")
        biEl.Name("LoopCyBI_" bid)
        biEl._Props["Width"] := "12", biEl._Props["Height"] := "12"
        biEl._Props["Fill"] := "#5C6BC0", biEl._Props["Stroke"] := "#1A237E", biEl._Props["StrokeThickness"] := "1"
        biEl._Props["Grid.Row"] := "1", biEl._Props["VerticalAlignment"] := "Top", biEl._Props["HorizontalAlignment"] := "Left", biEl._Props["Margin"] := "-6,-6,0,0"
        biEl._Props["Panel.ZIndex"] := "10", biEl._Props["ToolTip"] := GetLang("进入循环体")
        grid._Children.Push(biEl)
        boEl := XAMLElement("Ellipse")
        boEl.Name("LoopCyBO_" bid)
        boEl._Props["Width"] := "12", boEl._Props["Height"] := "12"
        boEl._Props["Fill"] := "#9575CD", boEl._Props["Stroke"] := "#311B92", boEl._Props["StrokeThickness"] := "1"
        boEl._Props["Grid.Row"] := "1", boEl._Props["VerticalAlignment"] := "Top", boEl._Props["HorizontalAlignment"] := "Left", boEl._Props["Margin"] := "-6,50,0,0"
        boEl._Props["Panel.ZIndex"] := "10", boEl._Props["ToolTip"] := GetLang("循环体返回")
        grid._Children.Push(boEl)
    }

    ; 回环路径的三次贝塞尔几何串（与引擎连线一致的风格，支持任意左右方向）。
    _LoopCycGeom(sx, sy, ex, ey) {
        off := Max(Abs(ex - sx) * 0.5, 40)
        sgn := (ex >= sx) ? 1 : -1
        return Format("M{},{} C{},{} {},{} {},{}", sx, sy, sx + sgn * off, sy, ex - sgn * off, ey, ex, ey)
    }

    ; 刷新循环↔循环体的两条回环路径几何。坐标缺省时从引擎节点画布坐标取（被拖动节点用其实时坐标传入）。
    _UpdateLoopCyclePaths(loopId, loopX := "", loopY := "", bodyX := "", bodyY := "") {
        if (this.graph == "" || this.ui == "")
            return
        g := this.graph
        bid := this._LoopBodyId(loopId)
        if (bid == "")
            return
        ln := g.GetNode(loopId), bn := g.GetNode(bid)
        if (!ln || !bn)
            return
        lw := this._LoopNodeWidth(loopId)
        lx := (loopX != "") ? loopX : ln.X
        ly := (loopY != "") ? loopY : ln.Y
        bx := (bodyX != "") ? bodyX : bn.X
        by := (bodyY != "") ? bodyY : bn.Y
        rx := lx + lw
        ey := this._LoopCyEnterY(), ry := this._LoopCyReturnY()
        bey := this._LoopBodyEnterY(), bry := this._LoopBodyReturnY()
        ; 进入：循环右上点 → 循环体入点（水平对齐时 Y 相同）
        this.ui.Update("LoopEnterPath_" loopId, "Data", this._LoopCycGeom(rx, ly + ey, bx, by + bey))
        ; 返回：循环体左下点 → 循环右下点（水平对齐时 Y 相同）
        this.ui.Update("LoopReturnPath_" loopId, "Data", this._LoopCycGeom(bx, by + bry, rx, ly + ry))
        ; 三角固定在端点：进入 ▶ 在循环体入点；返回 ◀ 在循环节点右侧返回入点
        this.ui.Update("LoopEnterTri_" loopId, "SetPosition", Format("{},{}", bx - 12, by + bey - 9))
        this.ui.Update("LoopReturnTri_" loopId, "SetPosition", Format("{},{}", rx + 4, ly + ry - 9))
    }

    ; 循环体外置节点 Border 元素（标题 + 指令小卡片 + 端口）。
    _MakeLoopBodyBorderEl(loopId, x, y, asFragment := false) {
        bid := this._LoopBodyId(loopId)
        border := XAMLElement("Border")
        if (asFragment)
            border.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation").SetProp("xmlns:x", "http://schemas.microsoft.com/winfx/2006/xaml")
        border.Name("Node_" bid).Background("{DynamicResource DropdownBg}").BorderBrush("#5C6BC0").BorderThickness("1.5").CornerRadius("6").Width("200").SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        border.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")
        grid := border.Add("Grid")
        grid.Rows("30", "Auto")
        header := grid.Add("Border").Grid_Row(0).Cursor("SizeAll").Background("#3949AB").CornerRadius("5,5,0,0")
        hp := header.Add("StackPanel").Orientation("Horizontal").VerticalAlignment("Center").Margin("8,0")
        hp.Add("TextBlock").Text("↻ " GetLang("循环体")).Foreground("White").FontWeight("Bold").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
        body := grid.Add("StackPanel").Grid_Row(1).Margin("8,6,8,8")
        this._FillLoopBodyNodeBody(loopId, body, bid)
        ; 循环体不参与主流程，不用标准入/出端口；仅左侧两个回环交互点（与循环节点右侧两点对应）
        this._AddLoopBodyCyclePortEls(grid, bid)
        return border
    }

    ; 填充循环体外置节点内容：指令小卡片(预览 5 条 + 展开/收起按钮，同搜索分支节点) + 双击提示
    _FillLoopBodyNodeBody(loopId, body, bid) {
        cmds := this._LoopBodyCmds(this._FormalDFromId(loopId))
        this._FillLoopChips(body, "LoopExtChips_" bid, "LoopExtExpand_" bid, bid, cmds)
        body.Add("TextBlock").Text(GetLang("双击编辑循环体")).Foreground("#9FA8DA").FontSize(this._MGFontSize(10)).Margin("0,4,0,0")
    }

    ; 回环路径元素（Path，画布级，非引擎连线）：构建供静态加入画布。
    _MakeLoopCyclePathEl(name, color, asFragment := false) {
        el := XAMLElement("Path")
        if (asFragment)
            el.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation")
        el.Name(name)
        el._Props["Stroke"] := color, el._Props["StrokeThickness"] := "3", el._Props["Opacity"] := "0.95"
        el._Props["Panel.ZIndex"] := "-1", el._Props["StrokeStartLineCap"] := "Round", el._Props["StrokeEndLineCap"] := "Round"
        return el
    }

    ; 创建连接线上的三角字符 TextBlock
    _MakeLoopTriangleEl(name, content, color, cx, cy, asFragment := false) {
        el := XAMLElement("TextBlock")
        if (asFragment)
            el.SetProp("xmlns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation")
        el.Name(name)
        el.Text(content)
        el.Foreground(color)
        el.FontSize(this._MGFontSize(12))
        el.FontWeight("Bold")
        el.SetProp("Panel.ZIndex", "1")
        el.SetProp("Canvas.Left", String(cx))
        el.SetProp("Canvas.Top", String(cy))
        return el
    }

    ; ---- 静态构建（_Render 期）----
    ; 为展开的循环节点构建外置循环体节点 + 两条自绘回环路径（进入/返回，连接两侧专用交互点）
    _BuildLoopBodyNode(loopId) {
        g := this.graph
        bid := this._LoopBodyId(loopId)
        bp := this._LoopBodyPos(loopId)
        this.pos[bid] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeLoopBodyBorderEl(loopId, x, y, false)
        g.canvas._Children.Push(el)
        g.nodes.Push({ Id: bid, Title: GetLang("循环体"), X: x, Y: y, W: 200, H: 60, Type: "Process" })
        ; 两条回环路径（画布级元素）。窗口尚未就绪，初始几何用静态坐标直接 SetProp。
        ; 连线高度改为 61px（奇数居中）
        ln := g.GetNode(loopId)
        lx := ln ? ln.X : x, ly := ln ? ln.Y : y
        rx := lx + this._LoopNodeWidth(loopId)
        ey := this._LoopCyEnterY(), ry := this._LoopCyReturnY()
        bey := this._LoopBodyEnterY(), bry := this._LoopBodyReturnY()
        enterEl := this._MakeLoopCyclePathEl("LoopEnterPath_" loopId, "#5C6BC0", false)
        enterEl.SetProp("Data", this._LoopCycGeom(rx, ly + ey, x, y + bey))
        retEl := this._MakeLoopCyclePathEl("LoopReturnPath_" loopId, "#9575CD", false)
        retEl.SetProp("Data", this._LoopCycGeom(x, y + bry, rx, ly + ry))
        g.canvas._Children.Push(enterEl)
        g.canvas._Children.Push(retEl)
        enterTriEl := this._MakeLoopTriangleEl("LoopEnterTri_" loopId, "▶", "#5C6BC0", x - 12, y + bey - 9, false)
        retTriEl := this._MakeLoopTriangleEl("LoopReturnTri_" loopId, "◀", "#9575CD", rx + 4, ly + ry - 9, false)
        g.canvas._Children.Push(enterTriEl)
        g.canvas._Children.Push(retTriEl)
    }

    ; ---- 运行时注入（窗口已就绪，避免整窗重建闪烁）----
    _InjectLoopBodyNode(loopId) {
        g := this.graph
        bid := this._LoopBodyId(loopId)
        bp := this._LoopBodyPos(loopId)
        this.pos[bid] := bp
        x := bp.x + g.offsetX
        y := bp.y + g.offsetY
        el := this._MakeLoopBodyBorderEl(loopId, x, y, true)
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(el.ToString()))
        g.nodes.Push({ Id: bid, Title: GetLang("循环体"), X: x, Y: y, W: 200, H: 60, Type: "Process" })
        ; 两条回环路径（画布级元素，运行时注入）
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(this._MakeLoopCyclePathEl("LoopEnterPath_" loopId, "#5C6BC0", true).ToString()))
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(this._MakeLoopCyclePathEl("LoopReturnPath_" loopId, "#9575CD", true).ToString()))
        ; 添加连接线上的三角字符
        ln := g.GetNode(loopId)
        lx := ln ? ln.X : x, ly := ln ? ln.Y : y
        rx := lx + this._LoopNodeWidth(loopId)
        ey := this._LoopCyEnterY(), ry := this._LoopCyReturnY()
        bey := this._LoopBodyEnterY(), bry := this._LoopBodyReturnY()
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(this._MakeLoopTriangleEl("LoopEnterTri_" loopId, "▶", "#5C6BC0", x - 12, y + bey - 9, true).ToString()))
        g.ui.Update(g.id, "AddXamlItem", this._FlattenXaml(this._MakeLoopTriangleEl("LoopReturnTri_" loopId, "◀", "#9575CD", rx + 4, ly + ry - 9, true).ToString()))
        g.ui.OnEvent("Node_" bid, "DragMove", ObjBindMethod(g, "OnNodeMoved", bid))
        g.ui.OnEvent("Node_" bid, "SelectNode", ObjBindMethod(g, "OnSelectNode", bid))
        g.ui.OnEvent("Node_" bid, "CtrlSelectNode", ObjBindMethod(g, "OnCtrlSelectNode", bid))
        this._RegisterLoopBodyEvents(loopId, true)
        this._loopBodyInjected[loopId] := true
        ; 注入后下一拍刷新路径几何（节点已就位）+ 启用拖动
        SetTimer(() => (this._UpdateLoopCyclePaths(loopId), g.ui.Update("Node_" bid, "EnableDrag", "grid=20")), -150)
    }

    ; 运行时刷新循环体外置节点 + 内联循环体卡片（循环体编辑器改动后调用）
    _RefreshLoopBodyNode(loopId) {
        if (this.ui == "")
            return
        cmds := this._LoopBodyCmds(this._FormalDFromId(loopId))
        if (this._loopBodyInjected.Has(loopId)) {
            bid := this._LoopBodyId(loopId)
            expanded := this._loopChipsExpanded.Has(bid) && this._loopChipsExpanded[bid]
            this._RebuildLoopChips("LoopExtChips_" bid, cmds, expanded)
            this.ui.Update("LoopExtExpand_" bid, "Visibility", cmds.Length > this._LoopPreviewCount() ? "Visible" : "Collapsed")
            this.ui.Update("LoopExtExpand_" bid, "Content", expanded ? GetLang("收起") : (GetLang("展开") " (" cmds.Length ")"))
        }
        this._RefreshLoopChips(loopId)
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

        nodeW := (d.type == GetLang("搜索Pro")) ? 380 : (this._IsFormalNodeType(d.type) ? this._FormalNodeWidth(d.type) : 200)
        border := XAMLElement("Border")
        border.SetProp("xmlns", pres).SetProp("xmlns:x", xns)
        border.Name("Node_" id).Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("6").Width(String(nodeW)).SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        if (d.type == GetLang("循环"))
            border.SetProp("MinHeight", "180")
        if (d.type == GetLang("如果Pro"))
            border.SetProp("MinHeight", "220")
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

        if (d.type != GetLang("如果Pro")) {
            portOutEl := XAMLElement("Ellipse")
            portOutEl.Name("Port_Out_" id)
            portOutEl._Props["Width"] := "14", portOutEl._Props["Height"] := "14"
            portOutEl._Props["Fill"] := "#FF5722", portOutEl._Props["Stroke"] := "#333", portOutEl._Props["StrokeThickness"] := "1"
            portOutEl._Props["Grid.Row"] := "1", portOutEl._Props["VerticalAlignment"] := "Top", portOutEl._Props["HorizontalAlignment"] := "Right", portOutEl._Props["Margin"] := "0,-7,-7,0"
            portOutEl._Props["Panel.ZIndex"] := "10", portOutEl._Props["IsHitTestVisible"] := "True", portOutEl._Props["Cursor"] := "Hand"
            grid._Children.Push(portOutEl)
        } else {
            ; 如果Pro：标题栏出点始终可见（展开时连到后续会自动拆分到各情况分支）
            portOutEl := XAMLElement("Ellipse")
            portOutEl.Name("Port_Out_" id)
            portOutEl._Props["Width"] := "14", portOutEl._Props["Height"] := "14"
            portOutEl._Props["Fill"] := "#FF5722", portOutEl._Props["Stroke"] := "#333", portOutEl._Props["StrokeThickness"] := "1"
            portOutEl._Props["Grid.Row"] := "1", portOutEl._Props["VerticalAlignment"] := "Top", portOutEl._Props["HorizontalAlignment"] := "Right", portOutEl._Props["Margin"] := "0,-7,-7,0"
            portOutEl._Props["Panel.ZIndex"] := "10", portOutEl._Props["IsHitTestVisible"] := "True", portOutEl._Props["Cursor"] := "Hand"
            grid._Children.Push(portOutEl)
        }
        ; 循环节点：右侧追加两个回环交互点（进入循环体 / 循环体返回）
        if (d.type == GetLang("循环"))
            this._AddLoopCyclePortEls(grid, id)
        if (d.type == GetLang("如果Pro"))
            this._AddIfProBranchPortEls(grid, id)

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
    _NewNodeShell(id, title, nodeType, &body, nodeW := "") {
        g := this.graph
        p := this.pos.Has(id) ? this.pos[id] : { x: 200, y: 200 }
        x := p.x + g.offsetX
        y := p.y + g.offsetY
        headerColor := nodeType == "Input" ? "#2E5A2E" : (nodeType == "Output" ? "#5A2E2E" : "#3E3E50")
        if (nodeW == "")
            nodeW := (title == GetLang("搜索Pro")) ? 380 : 200

        node := g.canvas.Add("Border").Name("Node_" id).Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("6").Width(String(nodeW)).SetProp("Canvas.Left", String(x)).SetProp("Canvas.Top", String(y))
        if (title == GetLang("循环"))
            node.SetProp("MinHeight", "180")
        if (title == GetLang("如果"))
            node.SetProp("MinHeight", "200")
        if (title == GetLang("如果Pro"))
            node.SetProp("MinHeight", "220")
        node.Add("Border.Effect").Add("DropShadowEffect").BlurRadius("8").ShadowDepth("2").Opacity("0.4").Direction("270").SetProp("Color", "Black")

        grid := node.Add("Grid")
        grid.Rows("30", "Auto")

        this._nodeShellGrid := grid

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
        if (nodeType != "Output" && title != GetLang("如果Pro")) {
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
        } else if (nodeType != "Output" && title == GetLang("如果Pro")) {
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
        ; 循环节点：右侧追加两个回环交互点（进入循环体 / 循环体返回）
        if (title == GetLang("循环"))
            this._AddLoopCyclePortEls(grid, id)

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
        hp.Add("TextBlock").Name("Title_" id).Text(title).Foreground("White").FontWeight("Bold").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
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
            btn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize(this._MGFontSize(14)).FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            btn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
            ; 图片搜索预览：浮动在节点左侧、入点下方，右上角贴近节点左边缘（不占用内容区）
            this._AddFloatingImgPreview(grid, id, d)
        }
        else if (title == GetLang("变量")) {
            ; 变量节点：标题栏展开/收起按钮。展开=完整卡片；收起=各启用变量「变量名 = 值」摘要
            folded := this._NodeFolded(id)
            fbtn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize(this._MGFontSize(14)).FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            fbtn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
        }
        else if (title == GetLang("运算")) {
            ; 运算节点：标题栏展开/收起按钮。展开=完整卡片；收起=各启用槽「目标 = 表达式」摘要
            folded := this._NodeFolded(id)
            fbtn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize(this._MGFontSize(14)).FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            fbtn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
        }
        else if (title == GetLang("循环")) {
            ; 循环节点：标题栏展开/收起按钮。展开=完整条件+外置循环体；收起=简化条件+内置循环体
            folded := this._NodeFolded(id)
            fbtn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize(this._MGFontSize(14)).FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            fbtn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
        }
        else if (title == GetLang("如果Pro")) {
            folded := this._NodeFolded(id)
            fbtn := hgrid.Add("Button").Name("SFold_" id).Grid_Column(1).Content(folded ? "▶" : "▼").FontSize(this._MGFontSize(14)).FontWeight("Bold").Foreground("White").Width("26").Height("22").Padding("0").Margin("0,0,6,0").VerticalAlignment("Center").Background("Transparent").BorderThickness("0").Cursor("Hand")
            fbtn.SetProp("ToolTip", folded ? GetLang("展开") : GetLang("收起"))
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
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(labelW).VerticalAlignment("Center")
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
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(labelW).VerticalAlignment("Center")
        cmb := row.Add("ComboBox").Name(comboName).Width(comboW).Height("22").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,0").MaxDropDownHeight("200").SelectedIndex(selIndex)
            .Background("{DynamicResource ControlBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1")
        if (!enabled)
            cmb.IsEnabled("False")
        for it in items
            cmb.Add("ComboBoxItem").Content(it)
        return row
    }

    ; 标签在上、多行文本框在下（输出内容等；约 3 行高；文本左上对齐）
    _AddMultilineFieldBlock(body, blockName, labelText, boxName, boxValue, visible, boxW := "96") {
        block := body.Add("StackPanel").Name(blockName).Margin("0,5,0,0")
        if (!visible)
            block.Visibility("Collapsed")
        block.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Margin("0,0,0,4")
        tb := block.Add("TextBox").Name(boxName).Text(boxValue).Width(boxW).Height("54").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,2")
            .Foreground("White").CaretBrush("White").Background("{DynamicResource ControlBg}").BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1")
        tb.SetProp("TextWrapping", "Wrap")
        tb.SetProp("AcceptsReturn", "True")
        tb.SetProp("VerticalScrollBarVisibility", "Auto")
        tb.SetProp("VerticalContentAlignment", "Top")
        tb.SetProp("HorizontalContentAlignment", "Left")
        tb.SetProp("TextAlignment", "Left")
        return block
    }

    ; 标签 + 可编辑下拉（IsEditable）：既能从下拉选项中选，也能手动输入文本/数值
    _AddEditableComboRow(body, rowName, labelText, comboName, items, textValue, visible, labelW := "80", comboW := "96") {
        row := body.Add("StackPanel").Name(rowName).Orientation("Horizontal").Margin("0,5,0,0")
        if (!visible)
            row.Visibility("Collapsed")
        row.Add("TextBlock").Text(labelText).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).Width(labelW).VerticalAlignment("Center")
        ; MaxDropDownHeight 限制下拉高度（约 10 项），超出时模板内 ScrollViewer 自动出现滚动条
        cmb := row.Add("ComboBox").Name(comboName).Width(comboW).Height("22").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("2,0").MaxDropDownHeight("200").Foreground("White").IsEditable("True").IsTextSearchEnabled("False")
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
        chk := row.Add("CheckBox").Name(chkName).Content(labelText).Foreground("#DDDDDD").FontSize(this._MGFontSize(12)).VerticalAlignment("Center")
        if (isChecked == 1 || isChecked == "1")
            chk.IsChecked("True")
        if (!enabled)
            chk.IsEnabled("False")
        return row
    }

    ; 统一的小高度文本框（MinHeight=0 覆盖主题默认的 36，否则高度不生效）
    _MakeTextBox(parent, name, value, width, nodeId := "", field := "") {
        return parent.Add("TextBox").Name(name).Text(value).Width(width).Height("20").MinHeight("0").FontSize(this._MGFontSize(12)).Padding("4,0").VerticalContentAlignment("Center").HorizontalContentAlignment("Center").TextAlignment("Center").CaretBrush("White")
    }
}

_GraftMacroGraphMixin(MacroGraphNodeUIMixin)
