; MouseControl.dll 鼠标驱动封装模块
; DLL 来源: https://github.com/Tjner0/MouseControl
; 使用前需安装旧版 GHub/LGS 驱动

#Requires AutoHotkey v2.0

global MCDllPath := A_ScriptDir "\Plugins\MouseControl.dll"
global MCHandle := 0
global MCIsInit := false

; 诊断日志（写入 Log\MouseMoveDebug.log，与 MouseMoveUtil 共用）
_MC_Log(tag, msg) {
    try {
        logPath := (A_WorkingDir "\Log\MouseMoveDebug.log")
        FileAppend(FormatTime(, "HH:mm:ss") "." SubStr(A_TickCount, -2) " [" tag "] " msg "`n"
            , logPath, "UTF-8")
    }
}

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

    ; 钳制到虚拟桌面范围内，避免 DLL 收到越界坐标后行为异常
    vx := SysGet(76), vy := SysGet(77)
    vw := SysGet(78), vh := SysGet(79)
    targetX := Max(vx, Min(vx + vw - 1, targetX))
    targetY := Max(vy, Min(vy + vh - 1, targetY))

    DllCall(MCDllPath "\move_Abs", "Int", targetX, "Int", targetY)

    MouseGetPos(&curX, &curY)
    if (Abs(targetX - curX) <= 2 && Abs(targetY - curY) <= 2)
        return

    ; 相对报告通常为 int8（±127），必须分片，否则跨屏会被截到当前屏边缘
    maxStep := 127
    stuckCount := 0
    Loop 400 {
        MouseGetPos(&curX, &curY)
        dx := targetX - curX
        dy := targetY - curY
        if (Abs(dx) <= 1 && Abs(dy) <= 1)
            return
        ; 检测是否卡在屏幕边缘（坐标不再变化但目标未达成）
        if (A_Index > 1 && curX = lastX && curY = lastY)
            stuckCount++
        else
            stuckCount := 0
        if (stuckCount >= 3)
            return
        lastX := curX, lastY := curY
        if (Mod(A_Index, 20) = 0)
            DllCall(MCDllPath "\move_Abs", "Int", targetX, "Int", targetY)
        stepX := Max(-maxStep, Min(maxStep, dx))
        stepY := Max(-maxStep, Min(maxStep, dy))
        MC_MoveR(stepX, stepY)
    }
}

; 平滑移动步进参数
; speed: 1~100 越大越快
; 90+ 高速段：步长指数增长，90=46, 91=46*1.3, 92=46*1.3^2, ..., 100=46*1.3^10
MC_SmoothStepParams(speed, &maxStep, &stepDelay) {
    speed := Max(1, Min(100, Integer(speed)))
    if (speed >= 90) {
        maxStep := Round(46 * (1.3 ** (speed - 90)))
        stepDelay := 1
        return
    }
    factor := speed / 100.0
    ; 步长范围 2~50
    maxStep := Max(2, Min(50, Round(2 + 50 * (factor ** 1.2))))
    ; 延时范围 1~21ms（越大越快延时越小）
    stepDelay := Max(1, Round(21 * ((1 - factor) ** 1.2) + 1))
}

; 带速度的绝对移动
; 内部始终拆分为小步长相对移动，不调用 move_Abs 以避免 DLL 在屏幕边缘坐标映射异常
; speed: 1~100 越大越快（拆分为小步相对移动，避免单次大值）
MC_MoveAbsSmooth(targetX, targetY, speed := 0) {
    CoordMode("Mouse", "Screen")

    ; 钳制目标到虚拟桌面范围
    vx := SysGet(76), vy := SysGet(77)
    vw := SysGet(78), vh := SysGet(79)
    targetX := Max(vx, Min(vx + vw - 1, Integer(targetX)))
    targetY := Max(vy, Min(vy + vh - 1, Integer(targetY)))

    MouseGetPos(&curX, &curY)
    dx := targetX - curX
    dy := targetY - curY

    if (Abs(dx) <= 1 && Abs(dy) <= 1)
        return

    ; 全部走相对步进，避免 DLL move_Abs 在边缘坐标时的异常行为
    return MC_MoveRSmooth(dx, dy, speed)
}

; 相对移动（平滑，闭环校正 + 自适应步长）
;   - 步长随剩余距离等比衰减：≤5px→1，否则≤1/3，上限 maxStep
;   - speed: 1~100 越大越快
MC_MoveRSmooth(relX, relY, speed := 0) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&startX, &startY)
    expectX := startX + Integer(relX)
    expectY := startY + Integer(relY)

    if (speed <= 0)
        speed := 1
    useSpeed := Min(100, Max(1, Integer(speed)))

    MC_SmoothStepParams(useSpeed, &maxStep, &stepDelay)

    stepCount := 0
    stuckCount := 0
    oscillationCount := 0
    prevDxSign := 0, prevDySign := 0
    lastCurX := -9999, lastCurY := -9999
    Loop 5000 {
        MouseGetPos(&curX, &curY)
        dx := expectX - curX
        dy := expectY - curY
        len := Sqrt(dx * dx + dy * dy)

        if (len <= 1)
            break

        ; 检测震荡死循环（方向反复反转说明在目标附近来回振荡）
        curDxSign := (dx > 0 ? 1 : (dx < 0 ? -1 : 0))
        curDySign := (dy > 0 ? 1 : (dy < 0 ? -1 : 0))
        if (prevDxSign != 0 && curDxSign != 0 && curDxSign != prevDxSign)
            oscillationCount++
        else if (prevDySign != 0 && curDySign != 0 && curDySign != prevDySign)
            oscillationCount++
        else if (curDxSign != 0 || curDySign != 0)
            oscillationCount := Max(0, oscillationCount - 1)
        prevDxSign := curDxSign, prevDySign := curDySign
        if (oscillationCount >= 5) {
            ; 陷入震荡，最后再发一次精确微调然后退出
            if (Abs(dx) <= 2 && Abs(dy) <= 2) {
                MC_MoveR(dx, dy)
                Sleep(stepDelay)
            }
            break
        }

        ; 检测卡死（光标不再移动但目标未达成，如触屏边缘）
        if (curX = lastCurX && curY = lastCurY) {
            stuckCount++
            if (stuckCount >= 3)
                break
        } else {
            stuckCount := 0
        }
        lastCurX := curX, lastCurY := curY

        stepCount++
        ; 自适应步长：剩余距离 ≤5px 时降为 1，否则每步最多覆盖 1/3
        adaptiveMaxStep := Max(1, Min(maxStep, len <= 5 ? 1 : Round(len / 3)))

        if (len <= adaptiveMaxStep) {
            MC_MoveR(dx, dy)
            Sleep(stepDelay)
            continue
        }
        sx := Round(dx * adaptiveMaxStep / len)
        sy := Round(dy * adaptiveMaxStep / len)
        if (sx = 0 && dx != 0)
            sx := dx > 0 ? 1 : -1
        if (sy = 0 && dy != 0)
            sy := dy > 0 ? 1 : -1
        MC_MoveR(sx, sy)
        Sleep(stepDelay)
    }

    ; 诊断日志
    MouseGetPos(&endX, &endY)
    _MC_Log("MC_RSmooth", Format("req=({},{}) start=({},{}) expect=({},{}) end=({},{}) err=({},{}) steps={} maxStep={} speed={}"
        , Integer(relX), Integer(relY), startX, startY, expectX, expectY, endX, endY
        , expectX - endX, expectY - endY, stepCount, maxStep, useSpeed))
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
