#Requires AutoHotkey v2.0

; 鼠标移动策略统一入口
; 按「按键类型」(ModeArr) + 「移动模式」(绝对/相对/游戏视角) 分发到 AHK / 罗技 / AHI
;
; keyMode : 1 默认(AHK) | 2 游戏(AHK键) | 3 罗技 | 4 AHI
; moveMode: 0 绝对 | 1 相对 | 2 游戏视角（相对位移；罗技/AHI 会再点一下左键，AHK 仅相对移动）
;
; 速度约定（与编辑器一致）：uiSpeed 0~100，越大越快，100 为瞬移
; - AHK MouseMove / SetDefaultMouseSpeed：需转为 0 最快 ~ 100 最慢
; - 罗技 / AHI 平滑：越大越快，>=100 瞬移

; 从宏项读取按键类型
GetMacroKeyMode(tableItem, index) {
    try
        return Integer(tableItem.ModeArr[index])
    catch
        return 1
}

NormalizeUiMouseSpeed(uiSpeed) {
    try
        return Max(0, Min(100, Integer(uiSpeed)))
    catch
        return 90
}

; AHK：0 最快，100 最慢
UiSpeedToAhkSpeed(uiSpeed) {
    uiSpeed := NormalizeUiMouseSpeed(uiSpeed)
    return (uiSpeed >= 100) ? 0 : (100 - uiSpeed)
}

; 罗技/AHI：越大越快；0 表示最慢（用 1，避免旧接口把 <=0 当成瞬移）
UiSpeedToDriverSpeed(uiSpeed) {
    uiSpeed := NormalizeUiMouseSpeed(uiSpeed)
    if (uiSpeed >= 100)
        return 100
    if (uiSpeed <= 0)
        return 1
    return uiSpeed
}

; 初始化对应后端；失败返回 false（AHI/罗技不可用时上层应中止）
EnsureMouseBackend(keyMode) {
    keyMode := Integer(keyMode)
    if (keyMode == 3) {
        if (!InitMouseControl())
            return false
        return true
    }
    if (keyMode == 4)
        return InitAHI()
    return true
}

; 按按键类型点击左键
MouseClickByKeyMode(keyMode, clickCount := 1) {
    keyMode := Integer(keyMode)
    clickCount := Max(1, Integer(clickCount))
    if (keyMode == 3) {
        if (!InitLogitechGHubNew())
            return false
        IbClick("Left", , , clickCount)
        return true
    }
    if (keyMode == 4) {
        AhiClick("L", clickCount)
        return true
    }
    Click(, , , clickCount)
    return true
}

; 绝对移动（屏幕坐标）；speed 为界面速度 0~100
MouseMoveAbsByKeyMode(keyMode, x, y, speed := 90, isHuman := false) {
    keyMode := Integer(keyMode)
    x := Round(x), y := Round(y)
    uiSpeed := NormalizeUiMouseSpeed(speed)
    SendMode("Event")
    CoordMode("Mouse", "Screen")

    if (isHuman && keyMode != 3 && keyMode != 4) {
        hm := HumanMouse.GetInstance()
        hm.SetParams({ IsEnabled: true, Speed: uiSpeed })
        hm.Move(x, y)
        return true
    }
    if (keyMode == 3) {
        MC_MoveAbsSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        return true
    }
    if (keyMode == 4) {
        AhiMoveAbsSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        return true
    }
    MouseMove(x, y, UiSpeedToAhkSpeed(uiSpeed))
    return true
}

; 相对移动；speed 为界面速度 0~100
MouseMoveRelByKeyMode(keyMode, x, y, speed := 90, isHuman := false) {
    keyMode := Integer(keyMode)
    x := Integer(x), y := Integer(y)
    uiSpeed := NormalizeUiMouseSpeed(speed)
    SendMode("Event")
    CoordMode("Mouse", "Screen")

    if (isHuman && keyMode != 3 && keyMode != 4) {
        MouseGetPos(&curX, &curY)
        hm := HumanMouse.GetInstance()
        hm.SetParams({ IsEnabled: true, Speed: uiSpeed })
        hm.Move(curX + x, curY + y)
        return true
    }
    if (keyMode == 3) {
        MC_MoveRSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        return true
    }
    if (keyMode == 4) {
        AhiMoveRSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        return true
    }
    MouseMove(x, y, UiSpeedToAhkSpeed(uiSpeed), "R")
    return true
}

; 游戏视角：相对位移；罗技/AHI 额外点击左键（与历史行为一致）
MouseMoveGameViewByKeyMode(keyMode, x, y, speed := 90) {
    keyMode := Integer(keyMode)
    x := Integer(x), y := Integer(y)
    uiSpeed := NormalizeUiMouseSpeed(speed)
    SendMode("Event")
    CoordMode("Mouse", "Screen")

    if (keyMode == 3) {
        MC_MoveRSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        Sleep(30)
        return MouseClickByKeyMode(3, 1)
    }
    if (keyMode == 4) {
        AhiMoveRSmooth(x, y, UiSpeedToDriverSpeed(uiSpeed))
        Sleep(30)
        return MouseClickByKeyMode(4, 1)
    }
    ; AHK：仅相对移动（不点击）
    SendInput("{Click " Round(x) " " Round(y) " 0 Relative}")
    return true
}

; 统一策略：移动，可选随后点击
; speed: 界面速度 0~100（越大越快，100 瞬移）
; clickCount: 0=只移动；>0=移动后左键点击次数
; moveMode: 0 绝对 | 1 相对 | 2 游戏视角（忽略 clickCount/isHuman，走游戏视角语义）
MouseMoveByStrategy(keyMode, moveMode, x, y, speed := 90, clickCount := 0, isHuman := false) {
    keyMode := Integer(keyMode)
    moveMode := Integer(moveMode)
    clickCount := Integer(clickCount)
    uiSpeed := NormalizeUiMouseSpeed(speed)
    if (!EnsureMouseBackend(keyMode))
        return false

    if (moveMode == 2)
        return MouseMoveGameViewByKeyMode(keyMode, x, y, uiSpeed)

    ; AHK：带点击时用 Click 一步完成（含位移），避免相对位移执行两次
    if (clickCount > 0 && keyMode != 3 && keyMode != 4) {
        SetDefaultMouseSpeed(UiSpeedToAhkSpeed(uiSpeed))
        if (moveMode == 1)
            Click(Format("{} {} {} Relative"), Integer(x), Integer(y), clickCount)
        else
            Click(Format("{} {} {}"), Round(x), Round(y), clickCount)
        return true
    }

    ok := (moveMode == 1)
        ? MouseMoveRelByKeyMode(keyMode, x, y, uiSpeed, isHuman && clickCount <= 0)
        : MouseMoveAbsByKeyMode(keyMode, x, y, uiSpeed, isHuman && clickCount <= 0)
    if (!ok)
        return false

    if (clickCount > 0) {
        if (moveMode == 1)
            Sleep(30)
        return MouseClickByKeyMode(keyMode, clickCount)
    }
    return true
}

; 搜索等场景：屏幕绝对坐标移动，可选点击/双击
; actionType: 2=只移动 | 3=移动后点击 | 4=移动后双击
; speed: 界面速度 0~100
SearchMouseActionByStrategy(keyMode, actionType, x, y, speed := 90, clickCount := 1) {
    keyMode := Integer(keyMode)
    actionType := Integer(actionType)
    uiSpeed := NormalizeUiMouseSpeed(speed)
    if (!EnsureMouseBackend(keyMode))
        return false

    if (actionType == 2)
        return MouseMoveAbsByKeyMode(keyMode, x, y, uiSpeed, false)

    n := (actionType == 4) ? 2 : Max(1, Integer(clickCount))
    if (keyMode == 3 || keyMode == 4) {
        if (!MouseMoveAbsByKeyMode(keyMode, x, y, uiSpeed, false))
            return false
        return MouseClickByKeyMode(keyMode, n)
    }
    SetDefaultMouseSpeed(UiSpeedToAhkSpeed(uiSpeed))
    Click(Format("{} {} {}"), Round(x), Round(y), n)
    return true
}
