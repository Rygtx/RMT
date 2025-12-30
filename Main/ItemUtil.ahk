#Requires AutoHotkey v2.0

ItemFreeConPoolMap := Map()
ItemUseConPoolMap := Map()

LoadTabItem(tableItem) {
    MaxShowItemNum := 15
    LoadItemNum := tableItem.ModeArr.Length > MaxShowItemNum ? MaxShowItemNum : tableItem.ModeArr.Length
    ItemFreeConPoolMap.Set(tableItem.Index, [])
    ItemUseConPoolMap.Set(tableItem.Index, Map())

    loop LoadItemNum {
        ItemConObj := Object()
        LoadTabSingleItem(tableItem, ItemConObj)
        ItemFreeConPoolMap[tableItem.Index].Push(ItemConObj)
    }
}

LoadTabSingleItem(tableItem, ItemConObj) {
    MyGui := MySoftData.MyGui
    TabPosX := MySoftData.TabPosX
    tableIndex := tableItem.Index
    isMacro := CheckIsMacroTable(tableIndex)
    isNormal := CheckIsNormalTable(tableIndex)
    isTriggerStr := CheckIsStringMacroTable(tableIndex)
    isTiming := CheckIsTimingMacroTable(tableIndex)
    isMenu := CheckIsMenuMacroTable(tableIndex)
    isSubMacro := CheckIsSubMacroTable(tableIndex)
    isNoTriggerKey := CheckIsNoTriggerKey(tableIndex)

    ;颜色
    ColorCon := MyGui.Add("Pic", Format("x{} y{} w{} h27", TabPosX + 20, -1000, 29),
    "Images\Soft\GreenColor.png")
    ColorCon.Visible := false
    ColorCon.OriPosX := TabPosX + 20

    ;序号
    IndexCon := MyGui.Add("Text", Format("x{} y{} w{} +BackgroundTrans", TabPosX + 20, -1000, 30), 0 ".")
    IndexCon.OffsetY := 5
    IndexCon.OriPosX := TabPosX + 20

    ;备注
    RemarkCon := MyGui.Add("Edit", Format("x{} y{} w180", TabPosX + 60, -1000), "")
    RemarkCon.OriPosX := TabPosX + 60

    ;触发按键
    btnStr := isTiming ? GetLang("定时") : GetLang("编辑")
    TKBtnCon := MyGui.Add("Button", Format("x{} y{} w100 h29", TabPosX + 250, -1000), btnStr)
    TKBtnCon.Enabled := !isSubMacro && !isMenu
    TKBtnCon.OffsetY := -1
    TKBtnCon.OriPosX := TabPosX + 250

    ;触发类型
    TKTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", TabPosX + 360, -1000, 70),
    GetLangArr(["按下", "松开", "松止", "开关", "长按"]))
    TKTypeCon.Enabled := isNormal
    TKTypeCon.OriPosX := TabPosX + 360

    ;循环次数
    LoopCon := MyGui.Add("ComboBox", Format("x{} y{} w60 R5 center", TabPosX + 440, -1000), GetLangArr(["无限"]))
    LoopCon.Text := GetLang("无限")
    LoopCon.Enabled := isMacro
    LoopCon.OriPosX := TabPosX + 440

    SettingCon := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 510, -1000), GetLang("设置"))
    SettingCon.OffsetY := -1
    SettingCon.OriPosX := TabPosX + 510

    ;编辑
    EditCon := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 580, -1000 - 1), GetLang("编辑"))
    EditCon.OffsetY := -1
    EditCon.OriPosX := TabPosX + 580

    ;上
    PreCon := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 700, -1000), "↑")
    PreCon.OriPosX := TabPosX + 700

    ;下
    NextCon := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 725, -1000), "↓")
    NextCon.OriPosX := TabPosX + 725

    ;禁用
    ForbidCon := MyGui.Add("Checkbox", Format("x{} y{}", TabPosX + 755, -1000), GetLang("禁用"))
    ForbidCon.OffsetY := 4
    ForbidCon.OriPosX := TabPosX + 755

    ;删除
    DelCon := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 810, -1000), GetLang("删除"))
    DelCon.Enabled := !isMenu
    DelCon.OffsetY := -1
    DelCon.OriPosX := TabPosX + 810

    ;分割线
    LineCon := ""
    if (MySoftData.ShowSplitLine) {
        LineCon := MyGui.Add("Text", Format("x{} y{} w870 h1 0x10", TabPosX + 20, -1000), "") ; SS_ETCHEDHORZ
        LineCon.Offset := 32
        LineCon.OriPosX := TabPosX + 20
    }

    ItemConObj.ColorCon := ColorCon
    ItemConObj.IndexCon := IndexCon
    ItemConObj.RemarkCon := RemarkCon
    ItemConObj.TKBtnCon := TKBtnCon
    ItemConObj.TKTypeCon := TKTypeCon
    ItemConObj.LoopCon := LoopCon
    ItemConObj.SettingCon := SettingCon
    ItemConObj.EditCon := EditCon
    ItemConObj.PreCon := PreCon
    ItemConObj.NextCon := NextCon
    ItemConObj.ForbidCon := ForbidCon
    ItemConObj.DelCon := DelCon
    ItemConObj.LineCon := LineCon

    ItemConObj.ConArr := [ColorCon, IndexCon, RemarkCon, TKBtnCon, TKTypeCon, LoopCon, SettingCon,
        EditCon, PreCon, NextCon, ForbidCon, DelCon, LineCon]
}

RefreshTabItem(tableItem) {
    ItemUsePool := ItemUseConPoolMap[tableItem.Index]
    FoldInfo := tableItem.FoldInfo
    ;因为遍历里面涉及对ItemUsePool的Delete操作，会影响遍历操作
    UsePool := ItemUsePool.Clone()
    for index, ItemConObj in UsePool {
        foldIndex := GetItemFoldIndex(tableItem, index)
        isFold := foldIndex == 0 ? true : FoldInfo.FoldStateArr[foldIndex]
        if (isFold) {
            RecycleTabSingleItem(tableItem, index)
            continue
        }

        FoldCon := tableItem.AllGroup[foldIndex]
        FoldCon.GetPos(&FoldX, &FoldY, &w, &h)
        IndexSpanStr := FoldInfo.IndexSpanArr[foldIndex]
        IndexSpan := StrSplit(IndexSpanStr, "-")
        isMenu := CheckIsMenuMacroTable(tableItem.Index)
        titleHeight := isMenu ? 105 : 75
        OffsetNum := index - IndexSpan[1]
        PosY := OffsetNum * 40 + titleHeight + FoldY
        isOverScreen := PosY < -50 || PosY > 600
        if (isOverScreen || isFold) {
            RecycleTabSingleItem(tableItem, index)
            continue
        }

        for Index, Con in ItemConObj.ConArr {
            if (Con == "")
                continue

            SelfOffsetY := ObjHasOwnProp(Con, "OffsetY") ? Con.OffsetY : 0
            Con.Move(Con.OriPosX, PosY + SelfOffsetY)
        }
    }
}

RefreshGroupItem(tableItem, foldIndex) {
    isMacro := CheckIsMacroTable(tableItem.Index)
    if (!isMacro)
        return

    FoldInfo := tableItem.FoldInfo
    isFold := FoldInfo.FoldStateArr[foldIndex]
    if (isFold)
        return

    FoldCon := tableItem.AllGroup[foldIndex]
    FoldCon.GetPos(&FoldX, &FoldY, &w, &h)
    if (FoldY + h < -50 || FoldY > 600)
        return

    IndexSpanStr := FoldInfo.IndexSpanArr[foldIndex]
    IndexSpan := StrSplit(IndexSpanStr, "-")
    if (!IsInteger(IndexSpan[1]) || !IsInteger(IndexSpan[2]))
        return

    isMenu := CheckIsMenuMacroTable(tableItem.Index)
    titleHeight := isMenu ? 105 : 75
    loop IndexSpan[2] - IndexSpan[1] + 1 {
        itemIndex := IndexSpan[1] + A_Index - 1
        PosY := (A_Index - 1) * 40 + titleHeight + FoldY
        if (PosY < -50 || PosY > 600)
            continue

        ItemConObj := GetItemConObj(tableItem, itemIndex)
        for Index, Con in ItemConObj.ConArr {
            if (Con == "")
                continue

            SelfOffsetY := ObjHasOwnProp(Con, "OffsetY") ? Con.OffsetY : 0
            Con.Move(Con.OriPosX, PosY + SelfOffsetY)
        }
    }
}

GetItemConObj(tableItem, itemIndex) {
    ItemUsePool := ItemUseConPoolMap[tableItem.Index]
    if (ItemUsePool.Has(itemIndex))
        return ItemUsePool[itemIndex]

    ItemFreeArr := ItemFreeConPoolMap[tableItem.Index]
    if (ItemFreeArr.Length == 0) {
        MySoftData.TabCtrl.UseTab(tableItem.Index)
        ItemConObj := Object()
        LoadTabSingleItem(tableItem, ItemConObj)
        MySoftData.TabCtrl.UseTab()
        ItemFreeArr.Push(ItemConObj)
    }
    ItemConObj := ItemFreeArr.Pop()
    ItemUsePool.Set(itemIndex, ItemConObj)

    isTiming := CheckIsTimingMacroTable(tableItem.Index)
    isMacro := CheckIsMacroTable(tableItem.Index)
    isTriggerStr := CheckIsStringMacroTable(tableItem.Index)
    TKBtnStr := isTiming ? GetLang("定时") : tableItem.TKArr[ItemIndex]
    TKBtnStr := TKBtnStr == "" ? GetLang("编辑") : TKBtnStr
    LoopStr := tableItem.LoopCountArr[ItemIndex] == "-1" ? GetLang("无限") : tableItem.LoopCountArr[ItemIndex]
    EditTKAction := isTriggerStr ? OnItemEditTriggerStr : OnItemEditTriggerKey
    EditTKAction := isTiming ? OnItemEditTiming : EditTKAction
    EditMacroAction := isMacro ? OnItemEditMacro : OnItemEditReplaceKey

    ItemConObj.ColorCon.Value := GetItemColorValue(tableItem.ColorStateArr[itemIndex])
    ItemConObj.ColorCon.Visible := tableItem.ColorStateArr[itemIndex] != 0
    ItemConObj.IndexCon.Value := itemIndex "."
    ItemConObj.RemarkCon.Value := tableItem.RemarkArr[ItemIndex]
    ItemConObj.TKBtnCon.Text := TKBtnStr
    ItemConObj.TKTypeCon.Value := tableItem.TriggerTypeArr[ItemIndex]
    ItemConObj.LoopCon.Text := LoopStr
    ItemConObj.ForbidCon.Value := tableItem.ForbidArr[ItemIndex]

    ItemConObj.TKBtnCon.OnEvent("Click", EditTKAction.Bind(tableItem, itemIndex))
    ItemConObj.SettingCon.OnEvent("Click", OnItemEditMacroSetting.Bind(tableItem, itemIndex))
    ItemConObj.EditCon.OnEvent("Click", EditMacroAction.Bind(tableItem, itemIndex))
    ItemConObj.PreCon.OnEvent("Click", OnItemMoveUp.Bind(tableItem, itemIndex))
    ItemConObj.NextCon.OnEvent("Click", OnItemMoveDown.Bind(tableItem, itemIndex))
    ItemConObj.DelCon.OnEvent("Click", "", 0)
    ItemConObj.DelCon.OnEvent("Click", OnItemDelMacroBtnClick.Bind(tableItem, itemIndex))
    return ItemConObj
}

RecycleTabSingleItem(tableItem, itemIndex) {
    ItemUsePool := ItemUseConPoolMap[tableItem.Index]
    if (!ItemUsePool.Has(itemIndex))
        return

    ItemFreeArr := ItemFreeConPoolMap[tableItem.Index]
    ItemConObj := ItemUsePool[itemIndex]
    ItemUsePool.Delete(itemIndex)
    ItemFreeArr.Push(ItemConObj)

    ColorState := GetItemColorState(ItemConObj.ColorCon.Value)
    LoopValue := ItemConObj.LoopCon.Text == GetLang("无限") ? -1 : ItemConObj.LoopCon.Text

    ;记录可能修改的值
    tableItem.ColorStateArr[itemIndex] := ColorState
    tableItem.TKArr[itemIndex] := ItemConObj.TKBtnCon.Text
    tableItem.TriggerTypeArr[itemIndex] := ItemConObj.TKTypeCon.Value
    tableItem.ForbidArr[itemIndex] := ItemConObj.ForbidCon.Value
    tableItem.RemarkArr[itemIndex] := ItemConObj.RemarkCon.Value
    tableItem.LoopCountArr[itemIndex] := LoopValue

    for Index, Con in ItemConObj.ConArr {
        if (Con == "")
            continue
        Con.Move(Con.OriPosX, -1000)
    }
}

RecycleTabItem(tableItem) {
    ItemUsePool := ItemUseConPoolMap[tableItem.Index]
    FoldInfo := tableItem.FoldInfo
    ;因为遍历里面涉及对ItemUsePool的Delete操作，会影响遍历操作
    UsePool := ItemUsePool.Clone()
    for itemIndex, ItemConObj in UsePool {
        RecycleTabSingleItem(tableItem, itemIndex)
    }
}
