; MouseControl.dll 鼠标驱动封装模块
; DLL 来源: https://github.com/Tjner0/MouseControl
; 使用前需安装旧版 GHub/LGS 驱动

#Requires AutoHotkey v2.0

global MCDllPath := A_ScriptDir "\Plugins\MouseControl.dll"
global MCHandle := 0
global MCIsInit := false

; 初始化 MouseControl.dll
MC_Init() {
    global MCHandle, MCIsInit, MCDllPath
    if (MCIsInit)
        return true

    MCHandle := DllCall("LoadLibrary", "Str", MCDllPath, "Ptr")
    if (!MCHandle) {
        OutputDebug("MouseControl.dll 加载失败，错误码: " A_LastError)
        return false
    }

    MCIsInit := true
    return true
}

; 释放
MC_Destroy() {
    global MCHandle, MCIsInit
    if (MCHandle) {
        DllCall("FreeLibrary", "Ptr", MCHandle)
        MCHandle := 0
    }
    MCIsInit := false
}

; ========== 相对移动 ==========

; 相对移动（瞬时）
MC_MoveR(x, y) {
    global MCDllPath
    DllCall(MCDllPath "\move_R", "Int", Integer(x), "Int", Integer(y))
}

; 绝对移动到目标屏幕坐标（虚拟桌面像素，原点为虚拟屏左上角）
; 优先调用 DLL 的 move_Abs；若多屏/加速导致未到位，再分片相对逼近
MC_MoveAbs(targetX, targetY) {
    global MCDllPath
    CoordMode("Mouse", "Screen")
    targetX := Integer(targetX)
    targetY := Integer(targetY)

    DllCall(MCDllPath "\move_Abs", "Int", targetX, "Int", targetY)

    MouseGetPos(&curX, &curY)
    if (Abs(targetX - curX) <= 2 && Abs(targetY - curY) <= 2)
        return

    ; 相对报告通常为 int8（±127），必须分片，否则跨屏会被截到当前屏边缘
    maxStep := 127
    Loop 400 {
        MouseGetPos(&curX, &curY)
        dx := targetX - curX
        dy := targetY - curY
        if (Abs(dx) <= 1 && Abs(dy) <= 1)
            return
        if (Mod(A_Index, 20) = 0)
            DllCall(MCDllPath "\move_Abs", "Int", targetX, "Int", targetY)
        stepX := Max(-maxStep, Min(maxStep, dx))
        stepY := Max(-maxStep, Min(maxStep, dy))
        MC_MoveR(stepX, stepY)
    }
}

; 带速度的绝对移动（分步插值）
; targetX/Y: 目标屏幕坐标
; speed: 0=瞬移, 1~99=速度（值越大越快，与AHK MouseMove的Speed含义一致）
MC_MoveAbsSmooth(targetX, targetY, speed := 0) {
    global MCDllPath
    if (speed <= 0 || speed >= 100) {
        MC_MoveAbs(targetX, targetY)
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&curX, &curY)
    targetX := Integer(targetX)
    targetY := Integer(targetY)

    dx := targetX - curX
    dy := targetY - curY
    dist := Sqrt(dx * dx + dy * dy)

    if (dist < 2)
        return

    ; 根据速度计算步数和延迟（模拟AHK MouseMove的速度感）
    stepCount := Max(1, Round(dist * (100 - speed) / 1500))
    stepDelay := Max(1, Round((100 - speed) / 10))

    Loop Round(stepCount) {
        nextX := Round(curX + dx * A_Index / stepCount)
        nextY := Round(curY + dy * A_Index / stepCount)
        DllCall(MCDllPath "\move_Abs", "Int", nextX, "Int", nextY)
        Sleep(stepDelay)
    }

    ; 终点闭环修正（含跨屏分片相对）
    MC_MoveAbs(targetX, targetY)
}

; 带速度的相对移动
MC_MoveRSmooth(relX, relY, speed := 0) {
    if (speed <= 0 || speed >= 100) {
        MC_MoveR(relX, relY)
        return
    }

    dist := Sqrt(relX * relX + relY * relY)
    if (dist < 2)
        return

    stepCount := Max(1, Round(dist * (100 - speed) / 1500))
    stepDelay := Max(1, Round((100 - speed) / 10))

    stepX := relX / stepCount
    stepY := relY / stepCount

    remainingX := relX
    remainingY := relY

    Loop Round(stepCount) - 1 {
        MC_MoveR(Round(stepX), Round(stepY))
        remainingX -= Round(stepX)
        remainingY -= Round(stepY)
        Sleep(stepDelay)
    }
    ; 最后一步用剩余量确保精确到达
    MC_MoveR(Round(remainingX), Round(remainingY))
}

; ========== 点击 ==========

MC_ClickLeftDown() {
    global MCDllPath
    DllCall(MCDllPath "\click_Left_down")
}

MC_ClickLeftUp() {
    global MCDllPath
    DllCall(MCDllPath "\click_Left_up")
}

MC_ClickRightDown() {
    global MCDllPath
    DllCall(MCDllPath "\click_Right_down")
}

MC_ClickRightUp() {
    global MCDllPath
    DllCall(MCDllPath "\click_Right_up")
}

; 左键点击（按下+松开）
MC_ClickLeft() {
    MC_ClickLeftDown()
    Sleep(50)
    MC_ClickLeftUp()
}

; 右键点击
MC_ClickRight() {
    MC_ClickRightDown()
    Sleep(50)
    MC_ClickRightUp()
}

; 带坐标的点击（先移过去再点）
MC_MoveAndClick(x, y, clickCount := 1, whichButton := "L") {
    MC_MoveAbs(x, y)
    Sleep(30)
    Loop clickCount {
        if (whichButton == "L") {
            MC_ClickLeft()
        } else {
            MC_ClickRight()
        }
        if (A_Index < clickCount)
            Sleep(50)
    }
}
