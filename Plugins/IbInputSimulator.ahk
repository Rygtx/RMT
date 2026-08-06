; IbInputSimulator
; Description: Enable AHK to send keystrokes by drivers.
; Authors: Chaoses-Ib, Pennywise007
; Version: 0.4.1
; Homepage: https://github.com/Chaoses-Ib/IbInputSimulator

#Requires AutoHotkey v2.0

#DllLoad "*i IbInputSimulator.dll"  ;DllCall("LoadLibrary") cannot locate DLL correctly

IbSendInit(send_type := "AnyDriver", mode := 1, args*) {
    workding_dir := A_WorkingDir
    SetWorkingDir(A_ScriptDir)

    static hModule := DllCall("GetModuleHandle", "Str", "IbInputSimulator.dll", "Ptr")
    if (hModule == 0) {
        if (A_PtrSize == 4)
            throw "SendLibLoadFailed: Please use AutoHotkey x64"
        else
            throw "SendLibLoadFailed: " A_LastError
    }

    if (send_type == "AnyDriver")
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 0, "Int", 0, "Ptr", 0, "Int")
    else if (send_type == "SendInput")
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 1, "Int", 0, "Ptr", 0, "Int")
    else if (send_type == "Logitech")
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 2, "Int", 0, "Ptr", 0, "Int")
    else if (send_type == "LogitechGHubNew") {
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 6, "Int", 0, "Ptr", 0, "Int")
    }
    else if (send_type == "Razer")
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 3, "Int", 0, "Ptr", 0, "Int")
    else if (send_type == "DD") {
        if (args.Length == 1)
            result := DllCall("IbInputSimulator\IbSendInit", "Int", 4, "Int", 0, "WStr", args[1], "Int")
        else
            result := DllCall("IbInputSimulator\IbSendInit", "Int", 4, "Int", 0, "Ptr", 0, "Int")
    } else if (send_type == "MouClassInputInjection") {
        if (args.Length != 1)
            throw "MouClassInputInjection: Please specify the process ID of the target process"
        result := DllCall("IbInputSimulator\IbSendInit", "Int", 5, "Int", 0, "UInt64", args[1], "Int")
    } else
        throw "Invalid send type"

    SetWorkingDir(workding_dir)

    ; Error 枚举：0=Success … 6=DeviceNotFound（未找到 G HUB 虚拟设备）
    ; 提示仅在最终失败时由 InitLogitechGHubNew 弹出（避免先试 Logitech 失败就误弹）
    if (result != 0)
        return false

    if (mode !== 0) {
        IbSendMode(mode)
    }
    return true
}

; 罗技 G HUB 未就绪提示
; needRun=true：进程未运行；若本机有 lghub.exe 则左按钮为「运行」，否则「去下载」
; needRun=false：设备初始化失败，左按钮「去下载」
ShowLogitechGHubTip(needRun := false) {
    gHubUrl := "https://www.logitechg.com/innovation/g-hub.html"
    gHubExe := "C:\Program Files\LGHUB\lghub.exe"
    canRunLocal := needRun && FileExist(gHubExe)
    chosen := ""
    tipText := needRun
        ? GetLang("请先运行 G HUB（2022.2.1154 及以前版本）")
        : GetLang("未找到可用的罗技驱动，请安装并运行 G HUB（2022.2.1154 及以前版本）")

    g := Gui("+AlwaysOnTop -MinimizeBox", GetLang("提示"))
    try
        g.SetFont("S10 W550 Q2", MainSoftData.FontType)
    catch
        g.SetFont("S10")
    g.Add("Text", "x20 y18 w340 h48", tipText)
    leftBtnText := canRunLocal ? GetLang("运行") : GetLang("去下载")
    btnLeft := g.Add("Button", "x20 y78 w150 h30 Default", leftBtnText)
    btnCancel := g.Add("Button", "x190 y78 w150 h30", GetLang("取消"))
    btnLeft.OnEvent("Click", (*) => (chosen := canRunLocal ? "run" : "download", g.Destroy()))
    btnCancel.OnEvent("Click", (*) => (chosen := "cancel", g.Destroy()))
    g.OnEvent("Close", (*) => (chosen := "cancel", g.Destroy()))
    g.Show("w380 h125 Center")
    hwnd := g.Hwnd
    WinWaitClose("ahk_id " hwnd)
    if (chosen == "run")
        Run(gHubExe)
    else if (chosen == "download")
        Run(gHubUrl)
}

IbSendMode(mode) {
    static ahk_mode := ""
    if (mode == 1) {
        DllCall("IbInputSimulator\IbSendInputHook", "Int", 1)
        ahk_mode := A_SendMode
        SendMode("Input")
    } else if (mode == 0) {
        SendMode(ahk_mode)
        DllCall("IbInputSimulator\IbSendInputHook", "Int", 0)
    } else {
        throw "Invalid send mode"
    }
}

IbSendDestroy() {
    try {
        DllCall("IbInputSimulator\IbSendDestroy")
    }
    ;DllCall("FreeLibrary", "Ptr", hModule)
}

IbSyncKeyStates() {
    DllCall("IbInputSimulator\IbSendSyncKeyStates")
}

IbSend(keys) {
    DllCall("IbInputSimulator\IbSendInputHook", "Int", 1)  ;or IbSendMode(1)
    SendInput(keys)
    DllCall("IbInputSimulator\IbSendInputHook", "Int", 0)  ;or IbSendMode(0)
}

IbClick(args*) {
    IbSendMode(1)
    Click(args*)
    IbSendMode(0)
}

IbMouseMove(args*) {
    IbSendMode(1)
    MouseMove(args*)
    IbSendMode(0)
}

IbMouseClick(args*) {
    IbSendMode(1)
    MouseClick(args*)
    IbSendMode(0)
}

IbMouseClickDrag(args*) {
    IbSendMode(1)
    MouseClickDrag(args*)
    IbSendMode(0)
}
