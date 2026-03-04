#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Plugins\RapidOcr\RapidOcr.ahk
#Include Plugins\CLR.ahk
#Include Plugins\IbInputSimulator.ahk
#Include Plugins\ViGEm\AHK-ViGEm-Bus-v2.ahk
#Include Main\JoyMacro.ahk
#Include Main\RecordJoyUtil.ahk
#Include Main\LineOverlay.ahk
#Include Main\AssetUtil.ahk
#Include Main\RMTUtil.ahk
#Include Main\WorkPool.ahk
#Include Main\UIUtil.ahk
#Include Main\TimingUtil.ahk
#Include Main\BindUtil.ahk
#Include Main\VariableUtil.ahk
#Include Main\TriggerKeyData.ahk
#Include Main\FolderPackager.ahk
#Include Main\GlobalUtil.ahk

InitFilePath()          ;初始化文件路径
LoadCurMacroSetting()   ;加载当前配置宏
HandleOpenArg()         ;处理打开软件的参数
EditListen()        ;右键编辑数据监听
InitData()          ;初始化软件数据
InitUI()            ;初始化UI
SetEditData()      ;缓存编辑器数据

;放后面初始化，因为这初始化时间比较长
PluginInit()
TimingCheck()       ;轮询检测触发
BindKey()           ;绑定快捷键

9:: {
    x := 0
    y := 0
    res := FindWinImage(A_ScriptDir "\111.png", 395728, 90, &x, &y)
    ; ; res := FindImage(A_ScriptDir "\111.png", 0, 0, 1920, 1080, 90, &x, &y)
    MsgBox (Format("res:{}x:{} y:{}", res, x, y))

}

FindWinImage(targetPath, hwnd, matchThreshold, x, y) {
    return DllCall("RMT_OpenCV.dll\FindWinImage", "AStr", targetPath,
        "Int", hwnd, "Int", matchThreshold, "Int*", x, "Int*", y, "Cdecl Int")
}
