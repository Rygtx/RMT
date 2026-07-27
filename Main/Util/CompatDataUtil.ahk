#Requires AutoHotkey v2.0

; 内存数据结构的旧版本兼容补齐，主程序与Worker都会用到，故放在共享层（AssetUtil.ahk）
; 配置文件的迁移改写逻辑见 FixCompatUtil.ahk，那些仅主程序需要，不要在此处引用

;1.0.8F4到新版本兼容, 模块中新增菜单模块相关数据
Compat1_0_8F4FlodInfo(FoldInfo) {
    if (FoldInfo == "")
        return

    ; 逐字段检查，避免"有FrontInfoArr但缺UnorderedTriggerArr"的中间版本漏网
    needsFix := !ObjHasOwnProp(FoldInfo, "FrontInfoArr")
              || !ObjHasOwnProp(FoldInfo, "TKTypeArr")
              || !ObjHasOwnProp(FoldInfo, "TKArr")
              || !ObjHasOwnProp(FoldInfo, "HoldTimeArr")
              || !ObjHasOwnProp(FoldInfo, "UnorderedTriggerArr")

    if (!needsFix)
        return

    if (!ObjHasOwnProp(FoldInfo, "FrontInfoArr"))
        FoldInfo.FrontInfoArr := []
    if (!ObjHasOwnProp(FoldInfo, "TKTypeArr"))
        FoldInfo.TKTypeArr := []
    if (!ObjHasOwnProp(FoldInfo, "TKArr"))
        FoldInfo.TKArr := []
    if (!ObjHasOwnProp(FoldInfo, "HoldTimeArr"))
        FoldInfo.HoldTimeArr := []
    if (!ObjHasOwnProp(FoldInfo, "UnorderedTriggerArr"))
        FoldInfo.UnorderedTriggerArr := []

    loop FoldInfo.RemarkArr.Length {
        if (FoldInfo.FrontInfoArr.Length < A_Index)
            FoldInfo.FrontInfoArr.Push("")
        if (FoldInfo.TKTypeArr.Length < A_Index)
            FoldInfo.TKTypeArr.Push(1)
        if (FoldInfo.TKArr.Length < A_Index)
            FoldInfo.TKArr.Push("")
        if (FoldInfo.HoldTimeArr.Length < A_Index)
            FoldInfo.HoldTimeArr.Push(500)
        if (FoldInfo.UnorderedTriggerArr.Length < A_Index)
            FoldInfo.UnorderedTriggerArr.Push(false)
    }
}

;旧版本兼容：确保各数组长度与ModeArr一致（新增字段补齐）
CompatEnsureArrLength(tableItem) {
    if (tableItem.ModeArr.Length == tableItem.StartTipSoundArr.Length &&
        tableItem.ModeArr.Length == tableItem.EndTipSoundArr.Length &&
        tableItem.ModeArr.Length == tableItem.IcoPathArr.Length &&
        tableItem.ModeArr.Length == tableItem.UnorderedTriggerArr.Length)
        return

    for index, value in tableItem.ModeArr {
        if (tableItem.StartTipSoundArr.Length < index)
            tableItem.StartTipSoundArr.Push(1)
        if (tableItem.EndTipSoundArr.Length < index)
            tableItem.EndTipSoundArr.Push(1)
        if (tableItem.IcoPathArr.Length < index)
            tableItem.IcoPathArr.Push("")
        if (tableItem.UnorderedTriggerArr.Length < index)
            tableItem.UnorderedTriggerArr.Push(0)
    }
}
