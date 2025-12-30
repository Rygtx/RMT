#Requires AutoHotkey v2.0
#Include ItemUtil.ahk

LoadItemFold(index) {
    tableItem := MySoftData.TableInfo[index]
    FoldInfo := tableItem.FoldInfo
    MyGui := MySoftData.MyGui
    tableItem.UnderPosY := MySoftData.TabPosY
    tableItem.FoldOffsetArr := []
    tableItem.FoldBtnArr := []
    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    titleHeight := isMenu ? 85 : 55
    UpdateUnderPosY(index, 25)
    for foldIndex, IndexSpanStr in FoldInfo.IndexSpanArr {
        tableItem.FoldOffsetArr.Push(0)
        LoadItemFoldTitle(tableItem, foldIndex, tableItem.UnderPosY)
        UpdateUnderPosY(index, titleHeight)
        IndexSpan := StrSplit(IndexSpanStr, "-")
        if (!IsInteger(IndexSpan[1]) || !IsInteger(IndexSpan[2]))
            continue

        LoadItemFoldTip(tableItem, foldIndex, tableItem.UnderPosY)
        CurUnderPosY := tableItem.UnderPosY + 25
        if (!FoldInfo.FoldStateArr[foldIndex])
            UpdateUnderPosY(index, 25)

        loop IndexSpan[2] - IndexSpan[1] + 1 {
            itemIndex := A_Index + IndexSpan[1] - 1
            ; LoadTabItemUI(tableItem, itemIndex, foldIndex, CurUnderPosY)
            CurUnderPosY += 40
            if (!FoldInfo.FoldStateArr[foldIndex])
                UpdateUnderPosY(index, 40)
        }
        UpdateUnderPosY(index, 5)
    }
    LoadTabItem(tableItem)
    UpdateItemConPos(tableItem, true)
}

LoadItemFoldTitle(tableItem, foldIndex, PosY) {
    FoldInfo := tableItem.FoldInfo
    MyGui := MySoftData.MyGui
    isMenu := CheckIsMenuMacroTable(tableItem.Index)

    GroupHeight := GetFoldGroupHeight(FoldInfo, foldIndex, isMenu)
    con := MyGui.Add("GroupBox", Format("x{} y{} w900 h{}", MySoftData.TabPosX + 10, posY + 2,
        GroupHeight))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.AllGroup.InsertAt(foldIndex, con)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)
    PosY += 20

    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 20, posY + 2), GetLang("备注："))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)

    con := MyGui.Add("Edit", Format("x{} y{} w150 h27", MySoftData.TabPosX + 60, posY), FoldInfo.RemarkArr[
        foldIndex])
    con.OnEvent("Change", OnFoldRemarkChange.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 230, posY + 2), GetLang("前台:"))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)

    FrontCon := MyGui.Add("Edit", Format("x{} y{} w150 h27", MySoftData.TabPosX + 270, posY), FoldInfo.FrontInfoArr[
        foldIndex])
    FrontCon.OnEvent("Change", OnFoldFrontInfoChange.Bind(tableItem))
    conInfo := ItemConInfo(FrontCon, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[FrontCon] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("Button", Format("x{} y{} h29", MySoftData.TabPosX + 422, posY - 1), GetLang("编辑"))
    con.OnEvent("Click", OnFoldFrontInfoEdit.Bind(tableItem, FrontCon))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("Button", Format("x{} y{} h29", MySoftData.TabPosX + 490, posY - 1), GetLang("新增宏"))
    con.OnEvent("Click", OnItemAddMacroBtnClick.Bind(tableItem))
    con.Visible := !isMenu
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("Button", Format("x{} y{} h29", MySoftData.TabPosX + 560, posY - 1), GetLang("新增模块"))
    con.OnEvent("Click", OnItemAddFoldBtnClick.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("Button", Format("x{} y{} h29", MySoftData.TabPosX + 645, posY - 1), GetLang("删除模块"))
    con.OnEvent("Click", OnItemDelFoldBtnClick.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    con := MyGui.Add("CheckBox", Format("x{} y{}", MySoftData.TabPosX + 750, posY + 2), GetLang("禁用"))
    con.Value := FoldInfo.ForbidStateArr[foldIndex]
    con.OnEvent("Click", OnFoldForbidChange.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)

    btnStr := FoldInfo.FoldStateArr[foldIndex] ? "🞃" : "❯"
    con := MyGui.Add("Button", Format("x{} y{} w{} +BackgroundTrans", MySoftData.TabPosX + 840, posY - 2, 30),
    btnStr)
    con.OnEvent("Click", OnFoldBtnClick.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(-10000, conInfo)
    tableItem.FoldBtnArr.InsertAt(foldIndex, con)

    if (isMenu)
        LoadItemFoldTK(tableItem, foldIndex, PosY + 35)
}

LoadItemFoldTK(tableItem, foldIndex, PosY) {
    FoldInfo := tableItem.FoldInfo
    MyGui := MySoftData.MyGui

    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 20, posY + 2), GetLang("菜单触发键："))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)

    TriggerTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", MySoftData.TabPosX + 100, posY - 3, 70),
    GetLangArr(["按下", "松开", "松止", "开关", "长按"]))
    TriggerTypeCon.Value := FoldInfo.TKTypeArr[foldIndex]
    TriggerTypeCon.OnEvent("Change", OnFlodTKTypeChange.Bind(tableItem))
    conInfo := ItemConInfo(TriggerTypeCon, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[TriggerTypeCon] := MacroItemInfo(-10000, conInfo)

    TkCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", MySoftData.TabPosX + 175, posY - 3, 100,),
    "")
    TkCon.Value := FoldInfo.TKArr[foldIndex]
    TkCon.OnEvent("Change", OnFlodTKChange.Bind(tableItem))
    conInfo := ItemConInfo(TkCon, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[TkCon] := MacroItemInfo(-10000, conInfo)

    btnStr := GetLang("编辑")
    TKBtnCon := MyGui.Add("Button", Format("x{} y{} w60 h29", MySoftData.TabPosX + 280, posY - 4), btnStr)
    TKBtnCon.OnEvent("Click", OnFlodTKEditClick.Bind(TkCon, tableItem))
    conInfo := ItemConInfo(TKBtnCon, tableItem, foldIndex)
    conInfo.IsTitle := true
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[TKBtnCon] := MacroItemInfo(-10000, conInfo)
}

LoadItemFoldTip(tableItem, foldIndex, PosY) {
    MyGui := MySoftData.MyGui
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 70, posY), GetLang("宏名称"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 265, posY), GetLang("触发编辑器"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 360, posY), GetLang("触发类型"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 440, posY), GetLang("循环次数"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 518, posY), GetLang("宏设置"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
    con := MyGui.Add("Text", Format("x{} y{}", MySoftData.TabPosX + 580, posY), GetLang("宏编辑器"))
    tableItem.AllConArr.Push(ItemConInfo(con, tableItem, foldIndex))
}

LoadTabItemUI(tableItem, itemIndex, foldIndex, PosY) {
    MyGui := MySoftData.MyGui
    TabPosX := MySoftData.TabPosX
    tableIndex := tableItem.Index
    isMacro := CheckIsMacroTable(tableIndex)
    isNormal := CheckIsNormalTable(tableIndex)
    isSubMacro := CheckIsSubMacroTable(tableIndex)
    isMenu := CheckIsMenuMacroTable(tableIndex)
    isNoTriggerKey := CheckIsNoTriggerKey(tableIndex)
    isTiming := CheckIsTimingMacroTable(tableIndex)
    isTriggerStr := CheckIsStringMacroTable(tableIndex)
    EditTriggerAction := isTriggerStr ? OnItemEditTriggerStr : OnItemEditTriggerKey
    EditTriggerAction := isTiming ? OnItemEditTiming : EditTriggerAction
    EditMacroAction := isMacro ? OnItemEditMacro : OnItemEditReplaceKey
    InfoHeight := 60

    ;颜色
    colorCon := MyGui.Add("Pic", Format("x{} y{} w{} h27", TabPosX + 20, posY, 29),
    "Images\Soft\GreenColor.png")
    colorCon.Visible := false
    conInfo := ItemConInfo(colorCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[colorCon] := MacroItemInfo(ItemIndex, conInfo)
    ;序号
    IndexCon := MyGui.Add("Text", Format("x{} y{} w{} +BackgroundTrans", TabPosX + 20, posY + 5,
        30), ItemIndex ".")
    conInfo := ItemConInfo(IndexCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[IndexCon] := MacroItemInfo(ItemIndex, conInfo)

    ;备注
    RemarkCon := MyGui.Add("Edit", Format("x{} y{} w180", TabPosX + 60, posY), ""
    )
    RemarkCon.value := tableItem.RemarkArr[ItemIndex]
    conInfo := ItemConInfo(RemarkCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[RemarkCon] := MacroItemInfo(ItemIndex, conInfo)

    ;触发按键
    btnStr := isTiming ? GetLang("定时") : tableItem.TKArr[ItemIndex] == "" ? GetLang("编辑") : tableItem.TKArr[ItemIndex]
    TKBtnCon := MyGui.Add("Button", Format("x{} y{} w100 h29", TabPosX + 250, posY - 1), btnStr)
    TKBtnCon.OnEvent("Click", EditTriggerAction.Bind(tableItem))
    TKBtnCon.OnEvent("ContextMenu", OnItemCustomEditTriggerStr.Bind(tableItem))
    TKBtnCon.Enabled := !isSubMacro && !isMenu
    conInfo := ItemConInfo(TKBtnCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[TKBtnCon] := MacroItemInfo(ItemIndex, conInfo)

    ;触发类型
    TriggerTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", TabPosX + 360, posY, 70),
    GetLangArr(["按下", "松开", "松止", "开关", "长按"]))
    TriggerTypeCon.Value := tableItem.TriggerTypeArr[ItemIndex]
    TriggerTypeCon.Enabled := isNormal
    conInfo := ItemConInfo(TriggerTypeCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[TriggerTypeCon] := MacroItemInfo(ItemIndex, conInfo)

    ;循环次数
    LoopCon := MyGui.Add("ComboBox", Format("x{} y{} w60 R5 center", TabPosX + 440, posY), GetLangArr(["无限"]))
    conValue := tableItem.LoopCountArr[ItemIndex]
    conValue := conValue == "-1" ? GetLang("无限") : conValue
    LoopCon.Text := conValue
    LoopCon.Enabled := isMacro
    conInfo := ItemConInfo(LoopCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[LoopCon] := MacroItemInfo(ItemIndex, conInfo)

    con := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 510, posY - 1), GetLang("设置"))
    con.OnEvent("Click", OnItemEditMacroSetting.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(ItemIndex, conInfo)

    ;编辑
    con := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 580, posY - 1), GetLang("编辑"))
    con.OnEvent("Click", EditMacroAction.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(ItemIndex, conInfo)

    ;上
    con := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 700, posY), "↑")
    con.OnEvent("Click", OnItemMoveUp.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(ItemIndex, conInfo)

    ;下
    con := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 725, posY), "↓")
    con.OnEvent("Click", OnItemMoveDown.Bind(tableItem))
    conInfo := ItemConInfo(con, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[con] := MacroItemInfo(ItemIndex, conInfo)

    ;禁用
    ForbidCon := MyGui.Add("Checkbox", Format("x{} y{}", TabPosX + 755, posY + 4), GetLang("禁用"))
    ForbidCon.value := tableItem.ForbidArr[ItemIndex]
    conInfo := ItemConInfo(ForbidCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[ForbidCon] := MacroItemInfo(ItemIndex, conInfo)

    ;删除
    DelCon := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 810, posY - 1),
    GetLang("删除"))
    DelCon.OnEvent("Click", OnItemDelMacroBtnClick.Bind(tableItem))
    DelCon.Enabled := !isMenu
    conInfo := ItemConInfo(DelCon, tableItem, foldIndex)
    tableItem.AllConArr.Push(conInfo)
    tableItem.ConIndexMap[DelCon] := MacroItemInfo(ItemIndex, conInfo)

    ;分割线
    if (MySoftData.ShowSplitLine) {
        LineCon := MyGui.Add("Text", Format("x{} y{} w870 h1 0x10", TabPosX + 20, PosY + 32), "") ; SS_ETCHEDHORZ
        conInfo := ItemConInfo(LineCon, tableItem, foldIndex)
        tableItem.AllConArr.Push(conInfo)
        tableItem.ConIndexMap[LineCon] := MacroItemInfo(ItemIndex, conInfo)
    }

    tableItem.ColorStateArr.InsertAt(itemIndex, 0)
    tableItem.ColorConArr.InsertAt(itemIndex, colorCon)
    tableItem.IndexConArr.InsertAt(itemIndex, IndexCon)
    tableItem.RemarkConArr.InsertAt(itemIndex, RemarkCon)
    tableItem.TKConArr.InsertAt(itemIndex, TKBtnCon)
    tableItem.TriggerTypeConArr.InsertAt(itemIndex, TriggerTypeCon)
    tableItem.LoopCountConArr.InsertAt(itemIndex, LoopCon)
    tableItem.ForbidConArr.InsertAt(itemIndex, ForbidCon)
}

;按钮事件
;增加宏配置
OnItemAddMacroBtnClick(tableItem, btn, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[btn].itemConInfo.FoldIndex
    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    titleHeight := isMenu ? 85 : 55
    AddIndex := GetFoldAddItemIndex(foldInfo, foldIndex)
    if (foldInfo.FoldStateArr[foldIndex])  ;没开打的话，自动打开
        OnFoldBtnClick(tableItem, btn)

    isFirst := foldInfo.IndexSpanArr[foldIndex] == "无-无"
    UpdateFoldIndexInfo(foldInfo, AddIndex, foldIndex, true)
    UpdateConItemIndex(tableItem, AddIndex, foldIndex, true)
    tableItem.TKArr.InsertAt(AddIndex, "")
    tableItem.TriggerTypeArr.InsertAt(AddIndex, 1)
    tableItem.MacroArr.InsertAt(AddIndex, "")
    tableItem.ModeArr.InsertAt(AddIndex, 1)
    tableItem.ForbidArr.InsertAt(AddIndex, 0)
    tableItem.RemarkArr.InsertAt(AddIndex, "")
    tableItem.LoopCountArr.InsertAt(AddIndex, "1")
    tableItem.HoldTimeArr.InsertAt(AddIndex, 500)
    tableItem.SerialArr.InsertAt(AddIndex, GetSerialStr(""))
    tableItem.TimingSerialArr.InsertAt(AddIndex, GetSerialStr("Timing"))
    tableItem.StartTipSoundArr.InsertAt(AddIndex, 1)
    tableItem.EndTipSoundArr.InsertAt(AddIndex, 1)
    tableItem.IsWorkIndexArr.InsertAt(AddIndex, 0)

    PosY := 1000000
    for index, value in tableItem.AllConArr {
        if (foldIndex == value.FoldIndex && PosY > value.OriPosY)
            PosY := value.OriPosY
    }

    PosY += titleHeight
    if (isFirst) {
        MySoftData.TabCtrl.UseTab(tableItem.Index)
        LoadItemFoldTip(tableItem, foldIndex, PosY)
        LoadTabItemUI(tableItem, AddIndex, foldIndex, PosY + 25)
        MySoftData.TabCtrl.UseTab()
    }
    else {
        IndexSpan := StrSplit(foldInfo.IndexSpanArr[foldIndex], "-")
        PosY += (IndexSpan[2] - IndexSpan[1]) * 40 + 25
        MySoftData.TabCtrl.UseTab(tableItem.Index)
        LoadTabItemUI(tableItem, AddIndex, foldIndex, PosY)
        MySoftData.TabCtrl.UseTab()
    }

    afterHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
    tableItem.AllGroup[foldIndex].Move(, , , afterHei)

    addHei := isFirst ? 75 : 40
    tableItem.FoldOffsetArr[foldIndex] += addHei
    for index, value in tableItem.IndexConArr {
        value.Text := index
    }

    MySlider.RefreshTab()
}

;删除宏配置
OnItemDelMacroBtnClick(tableItem, btn, *) {
    foldInfo := tableItem.FoldInfo
    DelIndex := tableItem.ConIndexMap[btn].index
    foldIndex := tableItem.ConIndexMap[btn].itemConInfo.FoldIndex
    result := MsgBox(GetLang("是否删除当前宏"), GetLang("提示"), 1)
    if (result == "Cancel")
        return

    OnItemDelMacro(tableItem, DelIndex, foldInfo, foldIndex)
    MySlider.RefreshTab()
}

OnItemDelMacro(tableItem, itemIndex, foldInfo, foldIndex) {
    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    beforeHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
    UpdateFoldIndexInfo(foldInfo, itemIndex, foldIndex, false)
    UpdateConItemIndex(tableItem, itemIndex, foldIndex, false)
    HandleItemTopLabel(foldInfo, tableItem, foldIndex)
    afterHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
    tableItem.FoldOffsetArr[foldIndex] += afterHei - beforeHei
    tableItem.AllGroup[foldIndex].Move(, , , afterHei)

    tableItem.SerialArr.RemoveAt(itemIndex)
    tableItem.TKArr.RemoveAt(itemIndex)
    tableItem.MacroArr.RemoveAt(itemIndex)
    tableItem.LoopCountArr.RemoveAt(itemIndex)
    tableItem.ModeArr.RemoveAt(itemIndex)
    tableItem.ForbidArr.RemoveAt(itemIndex)
    tableItem.HoldTimeArr.RemoveAt(itemIndex)
    tableItem.RemarkArr.RemoveAt(itemIndex)
    tableItem.TimingSerialArr.RemoveAt(itemIndex)
    tableItem.StartTipSoundArr.RemoveAt(itemIndex)
    tableItem.EndTipSoundArr.RemoveAt(itemIndex)

    tableItem.ColorStateArr.RemoveAt(itemIndex)
    tableItem.ColorConArr.RemoveAt(itemIndex)
    tableItem.IndexConArr.RemoveAt(itemIndex)
    tableItem.RemarkConArr.RemoveAt(itemIndex)
    tableItem.TKConArr.RemoveAt(itemIndex)
    tableItem.TriggerTypeConArr.RemoveAt(itemIndex)
    tableItem.LoopCountConArr.RemoveAt(itemIndex)
    tableItem.ForbidConArr.RemoveAt(itemIndex)
    tableItem.IsWorkIndexArr.RemoveAt(itemIndex)
    for index, value in tableItem.IndexConArr {
        value.Text := index
    }
}

;增加宏模块
OnItemAddFoldBtnClick(tableItem, btn, *) {
    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    titleHeidht := isMenu ? 85 : 55
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[btn].itemConInfo.FoldIndex
    foldInfo.RemarkArr.InsertAt(foldIndex + 1, "")
    foldInfo.FrontInfoArr.InsertAt(foldIndex + 1, "")
    foldInfo.IndexSpanArr.InsertAt(foldIndex + 1, "无-无")
    foldInfo.ForbidStateArr.InsertAt(foldIndex + 1, false)
    foldInfo.FoldStateArr.InsertAt(foldIndex + 1, false)
    foldInfo.TKTypeArr.InsertAt(foldIndex + 1, 1)
    foldInfo.TKArr.InsertAt(foldIndex + 1, "")
    foldInfo.HoldTimeArr.InsertAt(foldIndex + 1, 500)
    tableItem.FoldOffsetArr.InsertAt(foldIndex + 1, titleHeidht)

    UpdateConFoldIndex(tableItem, foldIndex, true)
    LastGroupCon := tableItem.AllGroup[foldIndex]
    LastGroupCon.GetPos(&x, &y, &w, &h)
    LastOriPosY := tableItem.ConIndexMap[LastGroupCon].itemConInfo.OriPosY
    PosY := LastOriPosY + h - tableItem.FoldOffsetArr[foldIndex]
    MySoftData.TabCtrl.UseTab(tableItem.Index)
    LoadItemFoldTitle(tableItem, foldIndex + 1, PosY)
    MySoftData.TabCtrl.UseTab()

    if (isMenu)
        OnItemAddMenuItem(tableItem, foldIndex + 1)

    MySlider.RefreshTab()
}

OnItemAddMenuItem(tableItem, foldIndex) {
    loop 8 {
        foldInfo := tableItem.FoldInfo
        isMenu := CheckIsMenuMacroTable(tableItem.Index)
        titleHeight := isMenu ? 85 : 55
        AddIndex := GetFoldAddItemIndex(foldInfo, foldIndex)

        isFirst := foldInfo.IndexSpanArr[foldIndex] == "无-无"
        UpdateFoldIndexInfo(foldInfo, AddIndex, foldIndex, true)
        UpdateConItemIndex(tableItem, AddIndex, foldIndex, true)
        tableItem.TKArr.InsertAt(AddIndex, "")
        tableItem.TriggerTypeArr.InsertAt(AddIndex, 1)
        tableItem.MacroArr.InsertAt(AddIndex, "")
        tableItem.ModeArr.InsertAt(AddIndex, 1)
        tableItem.ForbidArr.InsertAt(AddIndex, 0)
        tableItem.RemarkArr.InsertAt(AddIndex, "")
        tableItem.LoopCountArr.InsertAt(AddIndex, "1")
        tableItem.HoldTimeArr.InsertAt(AddIndex, 500)
        tableItem.SerialArr.InsertAt(AddIndex, FormatTime(, "HHmmss"))
        tableItem.TimingSerialArr.InsertAt(AddIndex, GetSerialStr("Timing"))
        tableItem.StartTipSoundArr.InsertAt(AddIndex, 0)
        tableItem.EndTipSoundArr.InsertAt(AddIndex, 0)
        tableItem.IsWorkIndexArr.InsertAt(AddIndex, 0)

        PosY := 1000000
        for index, value in tableItem.AllConArr {
            if (foldIndex == value.FoldIndex && PosY > value.OriPosY)
                PosY := value.OriPosY
        }

        PosY += titleHeight
        if (isFirst) {
            MySoftData.TabCtrl.UseTab(tableItem.Index)
            LoadItemFoldTip(tableItem, foldIndex, PosY)
            LoadTabItemUI(tableItem, AddIndex, foldIndex, PosY + 25)
            MySoftData.TabCtrl.UseTab()
        }
        else {
            IndexSpan := StrSplit(foldInfo.IndexSpanArr[foldIndex], "-")
            PosY += (IndexSpan[2] - IndexSpan[1]) * 40 + 25
            MySoftData.TabCtrl.UseTab(tableItem.Index)
            LoadTabItemUI(tableItem, AddIndex, foldIndex, PosY)
            MySoftData.TabCtrl.UseTab()
        }

        afterHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
        tableItem.AllGroup[foldIndex].Move(, , , afterHei)

        addHei := isFirst ? 75 : 40
        tableItem.FoldOffsetArr[foldIndex] += addHei
        for index, value in tableItem.IndexConArr {
            value.Text := index
        }
    }
}

;删除模块
OnItemDelFoldBtnClick(tableItem, btn, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[btn].itemConInfo.FoldIndex

    result := MsgBox(GetLang("是否删除当前模块以及模块中所有的宏配置"), GetLang("提示"), 1)
    if (result == "Cancel")
        return

    if (foldInfo.IndexSpanArr.Length == 1) {
        MsgBox(GetLang("最后一个模块，不可删除！！！"))
        return
    }
    hasSetting := foldInfo.IndexSpanArr[foldIndex] != "无-无"
    if (hasSetting) {
        IndexSpan := StrSplit(foldInfo.IndexSpanArr[foldIndex], "-")
        loop IndexSpan[2] - IndexSpan[1] + 1 {
            itemIndex := IndexSpan[2] - A_Index + 1
            OnItemDelMacro(tableItem, itemIndex, foldInfo, foldIndex)
        }
    }

    UpdateConFoldIndex(tableItem, foldIndex, false)
    foldInfo.RemarkArr.RemoveAt(foldIndex)
    foldInfo.FrontInfoArr.RemoveAt(foldIndex)
    foldInfo.IndexSpanArr.RemoveAt(foldIndex)
    foldInfo.ForbidStateArr.RemoveAt(foldIndex)
    foldInfo.FoldStateArr.RemoveAt(foldIndex)
    foldInfo.TKTypeArr.RemoveAt(foldIndex)
    foldInfo.TKArr.RemoveAt(foldIndex)
    foldInfo.HoldTimeArr.RemoveAt(foldIndex)
    tableItem.FoldOffsetArr.RemoveAt(foldIndex)

    MySlider.RefreshTab()
}

;编辑字串宏触发键
OnItemEditTriggerStr(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    triggerStr := tableItem.TKArr[index]

    SureAction(sureTriggerKey) {
        tableItem.TKConArr[index].Text := sureTriggerKey == "" ? GetLang("编辑") : sureTriggerKey
        tableItem.TKArr[index] := sureTriggerKey
    }
    
    MyTriggerStrGui.SaveBtnAction := OnSaveSetting
    MyTriggerStrGui.SureBtnAction := SureAction
    MyTriggerStrGui.ShowGui(triggerStr, 0, false)
}

;自定义编辑触发按键
OnItemCustomEditTriggerStr(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    isNormal := CheckIsNormalTable(tableItem.Index)
    if (!isNormal)
        return

    CustomTK := InputBox(GetLang("请输入自定义触发按键："), "修改", "w300 h100", tableItem.TKArr[index])

    ; 检查用户是否取消输入
    if CustomTK.Result = "Cancel"
        return

    tableItem.TKConArr[index].Text := CustomTK.Value == "" ? GetLang("编辑") : CustomTK.Value
    tableItem.TKArr[index] := CustomTK.Value
}

;编辑按键宏触发键
OnItemEditTriggerKey(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    triggerKey := tableItem.TKArr[index]

    SureAction(sureTriggerKey, holdTime) {
        tableItem.TKConArr[index].Text := sureTriggerKey == "" ? GetLang("编辑") : sureTriggerKey
        tableItem.TKArr[index] := sureTriggerKey
        tableItem.HoldTimeArr[index] := holdTime
    }

    MyTriggerKeyGui.SaveBtnAction := OnSaveSetting
    MyTriggerKeyGui.SureBtnAction := SureAction
    MyTriggerKeyGui.ShowGui(triggerKey, tableItem.HoldTimeArr[index], false)
}

;编辑定时器
OnItemEditTiming(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    SerialStr := tableItem.TimingSerialArr[index]
    MyTimingGui.ShowGui(SerialStr)
}

OnItemEditMacroSetting(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    MyMacroSettingGui.ShowGui(tableItem.Index, index)
}

OnItemEditMacro(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    macro := tableItem.MacroArr[index]

    SureAction(sureMacro) {
        tableItem.MacroArr[index] := sureMacro
    }

    MySoftData.SpecialTableItem.ModeArr[1] := tableItem.ModeArr[index]
    if (MyMacroGui.Gui != "") {
        style := WinGetStyle(MyMacroGui.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (isVisible) {    ;存在并且显示的话，就打开第二个编辑界面
            MacroGui := MacroEditGui()
            MacroGui.SureFocusCon := MySoftData.BtnSave
            MacroGui.SureBtnAction := SureAction
            MacroGui.SaveBtnAction := OnSaveSetting
            MacroGui.ShowGui(macro, true)
            return
        }
    }
    MyMacroGui.SureFocusCon := MySoftData.BtnSave
    MyMacroGui.SureBtnAction := SureAction
    MyMacroGui.SaveBtnAction := OnSaveSetting
    MyMacroGui.ShowGui(macro, true)
}

OnItemEditReplaceKey(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    replaceKey := tableItem.MacroArr[index]

    SureAction(sureMacro) {
        tableItem.MacroArr[index] := sureMacro
    }

    MyReplaceKeyGui.SureBtnAction := SureAction
    MyReplaceKeyGui.ShowGui(replaceKey)
}

OnItemEditFrontInfo(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    frontInfoCon := tableItem.FrontInfoConArr[index]
    MyFrontInfoGui.ShowGui(frontInfoCon)
}

OnItemMoveUp(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    if (index == 1) {
        MsgBox(GetLang("上面没有元素，无法上移！！！"))
        return
    }
    SwapTableContent(tableItem, index, index - 1)
}

OnItemMoveDown(tableItem, btn, *) {
    index := tableItem.ConIndexMap[btn].index
    lastIndex := tableItem.ModeArr.length
    if (lastIndex == index) {
        MsgBox(GetLang("下面没有元素，无法下移！！！"))
        return
    }
    SwapTableContent(tableItem, index, index + 1)
}

OnFoldRemarkChange(tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    foldInfo.RemarkArr[foldIndex] := con.text
}

OnFoldFrontInfoChange(tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    foldInfo.FrontInfoArr[foldIndex] := con.text
}

OnFoldFrontInfoEdit(tableItem, FrontCon, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    MyFrontInfoGui.SureAction := () => foldInfo.FrontInfoArr[foldIndex] := FrontCon.text
    MyFrontInfoGui.ShowGui(FrontCon)
}

OnFoldForbidChange(tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    foldInfo.ForbidStateArr[foldIndex] := con.Value
}

OnFoldBtnClick(tableItem, btn, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[btn].itemConInfo.FoldIndex
    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    beforeHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
    state := !foldInfo.FoldStateArr[foldIndex]
    foldInfo.FoldStateArr[foldIndex] := state
    afterHei := GetFoldGroupHeight(foldInfo, foldIndex, isMenu)
    tableItem.FoldOffsetArr[foldIndex] += afterHei - beforeHei

    btnStr := FoldInfo.FoldStateArr[foldIndex] ? "🞃" : "❯"
    tableItem.FoldBtnArr[foldIndex].Text := btnStr

    tableItem.AllGroup[foldIndex].Move(, , , afterHei)
    MySlider.RefreshTab()
}

OnFlodTKTypeChange(tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    foldInfo.TKTypeArr[foldIndex] := con.Value
}

OnFlodTKChange(tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    foldInfo.TKArr[foldIndex] := con.Value
}

OnFlodTKEditClick(TKEditCon, tableItem, con, *) {
    foldInfo := tableItem.FoldInfo
    foldIndex := tableItem.ConIndexMap[con].itemConInfo.FoldIndex
    SureAction(sureTriggerKey, holdTime) {
        TKEditCon.Value := sureTriggerKey
        foldInfo.TKArr[foldIndex] := sureTriggerKey
        foldInfo.HoldTimeArr[foldIndex] := holdTime
    }

    MyTriggerKeyGui.SaveBtnAction := OnSaveSetting
    MyTriggerKeyGui.SureBtnAction := SureAction
    MyTriggerKeyGui.ShowGui(TKEditCon.Value, foldInfo.HoldTimeArr[foldIndex], false)
}

;刷新函数
UpdateItemConPos(tableItem, isDown) {
    loop tableItem.AllConArr.Length {
        Index := isDown ? A_Index : tableItem.AllConArr.Length - A_Index + 1
        ConInfo := tableItem.AllConArr[Index]
        ConInfo.UpdatePos(tableItem.OffSetPosY)
    }

    for index, value in tableItem.AllGroup {
        RefreshGroupItem(tableItem, Index)
        value.Redraw()
    }
}

UpdateConItemIndex(tableItem, OperIndex, FoldIndex, IsAdd) {
    DelKeys := []
    for key, value in tableItem.ConIndexMap {
        if (value.index < OperIndex)
            continue

        if (value.index == OperIndex) {
            if (IsAdd) {
                value.index += 1
            }
            else {
                value.itemConInfo.Hide()
                DelKeys.Push(key)
            }
        }
        else if (value.index > OperIndex) {
            if (IsAdd) {
                value.index += 1
            }
            else {
                value.index -= 1
                if (FoldIndex == value.itemConInfo.FoldIndex)
                    value.itemConInfo.DelAfterOffset(40)
            }
        }
    }

    for index, value in DelKeys {
        tableItem.ConIndexMap.Delete(value)
    }
}

HandleItemTopLabel(foldInfo, tableItem, foldIndex) {
    isNull := foldInfo.IndexSpanArr[foldIndex] == "无-无"
    if (!isNull)
        return

    for index, value in tableItem.AllConArr {
        if (value.FoldIndex != foldIndex)
            continue
        if (value.IsTitle)
            continue

        value.Hide()
    }
}

UpdateConFoldIndex(tableItem, FoldIndex, IsAdd) {
    tableItem.AllGroup[FoldIndex].GetPos(&x, &y, &w, &h)
    DelOffsetY := h - tableItem.FoldOffsetArr[FoldIndex]

    for index, value in tableItem.AllConArr {
        if (isAdd) {
            if (value.FoldIndex <= FoldIndex)
                continue

            value.FoldIndex += 1
        }
        else {
            if (value.FoldIndex < FoldIndex)
                continue

            if (value.FoldIndex == FoldIndex)
                value.Hide()

            if (value.FoldIndex > FoldIndex) {
                value.FoldIndex -= 1
                value.DelAfterOffset(DelOffsetY)
            }
        }
    }
}

UpdateFoldIndexInfo(FoldInfo, OperIndex, FoldIndex, IsAdd) {
    curMaxItemIndex := 0
    for Index, IndexSpanStr in FoldInfo.IndexSpanArr {
        IndexSpan := StrSplit(IndexSpanStr, "-")
        if (Index < FoldIndex) {
            if (IsInteger(IndexSpan[1]) && IsInteger(IndexSpan[2])) {
                curMaxItemIndex := IndexSpan[2]
            }
            continue
        }
        if (Index == FoldIndex) {
            if (IsAdd) {
                ;已经存在后面数字加1
                if (IsInteger(IndexSpan[1]) && IsInteger(IndexSpan[2])) {
                    IndexSpan[2] := IndexSpan[2] + 1
                }
                else {  ;不存在直接初始化
                    IndexSpan[1] := curMaxItemIndex + 1
                    IndexSpan[2] := curMaxItemIndex + 1
                }
            }
            else {
                IndexSpan[2] := IndexSpan[2] - 1
                if (IndexSpan[2] < IndexSpan[1]) {
                    IndexSpan[1] := "无"
                    IndexSpan[2] := "无"
                }
            }
        }
        if (Index > FoldIndex) {
            Value := IsAdd ? 1 : -1
            if (IsInteger(IndexSpan[1]) && IsInteger(IndexSpan[2])) {
                IndexSpan[1] := IndexSpan[1] + Value
                IndexSpan[2] := IndexSpan[2] + Value
            }
        }
        FoldInfo.IndexSpanArr[Index] := IndexSpan[1] "-" IndexSpan[2]
    }
}

;封装方法
GetFoldGroupHeight(FoldInfo, index, isMenu) {
    height := isMenu ? 85 : 55
    if (FoldInfo.FoldStateArr[index])
        return height
    IndexSpan := StrSplit(FoldInfo.IndexSpanArr[index], "-")
    if (!IsInteger(IndexSpan[1]) || !IsInteger(IndexSpan[2]))
        return height

    height := height + 25
    height := height + (IndexSpan[2] - IndexSpan[1] + 1) * 40
    return height
}

GetFoldAddItemIndex(FoldInfo, FoldIndex) {
    IndexSpan := StrSplit(FoldInfo.IndexSpanArr[FoldIndex], "-")
    if (IsInteger(IndexSpan[1]) && IsInteger(IndexSpan[2])) {
        return IndexSpan[2] + 1
    }

    CurFoldLastIndex := 0
    for index, value in FoldInfo.IndexSpanArr {
        if (index > FoldIndex)
            break

        IndexSpan := StrSplit(value, "-")
        if (IsInteger(IndexSpan[1]) && IsInteger(IndexSpan[2])) {
            CurFoldLastIndex := IndexSpan[2]
        }
    }

    return CurFoldLastIndex + 1
}
