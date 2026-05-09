#Requires AutoHotkey v2.0
#Include "..\Main\AssetUtil.ahk"
#Include "..\Gui\CustomInputGui.ahk"
#Include "..\Gui\InputBtnGui.ahk"
#Include "..\Plugins\RapidOcr\RapidOcr.ahk"
#Include "..\Plugins\IbInputSimulator.ahk"
#Include "..\Main\Util\SharedMemory.ahk"
#Include "..\Main\Util\RingBuffer.ahk"
#Include WorkUtil.ahk
#SingleInstance Force
DetectHiddenWindows true
Persistent
#NoTrayIcon

global parentHwnd := A_Args[1]
global workIndex := A_Args[2]
global parentPID := A_Args[3]
global txName := A_Args[4]
global rxName := A_Args[5]
global evtName := A_Args[6]

global ReceiveInfoMap := Map()
global MySoftData := SoftData()
global ToolCheckInfo := ToolCheck()
global MyMouseInfo := MouseWinData()
global IniFile := A_WorkingDir "\..\Setting\MainSettings.ini"
global LangDir := A_WorkingDir "\..\Lang"
LoadMainSetting()   ;加载配置
InitWorkFilePath()  ;初始化文件路径
LoadCurMacroSetting()   ;加载当前配置宏
InitData()
InitWork()

global MyChineseOcr := 0  ; 懒加载：首次使用时才初始化
global MyEnglishOcr := 0   ; 懒加载：首次使用时才初始化
global MyPToken := Gdip_Startup()
global MyInputGui := CustomInputGui()
global MyInputBtnGui := InputBtnGui()
global MySubMacroStopAction := WorkSubMacroStopAction
global MyTriggerSubMacro := WorkTriggerSubMacro
global MySetGlobalVariable := WorkSetGlobalVariable
global MyDelGlobalVariable := WorkDelGlobalVariable
global MyCMDReportAciton := WorkCMDReport
global MyExcuteRMTCMDAction := WorkExcuteRMTCMDAction
global MySetTableItemState := WorkSetTableItemState
global MySetItemPauseState := WorkSetItemPauseState
global MyMsgBoxContent := WorkMsgBoxContent
global MyToolTipContent := WorkToolTipContent
global MyMacroCount := WorkMacroCount
global MyViGJoySetState := WorkViGJoySetState
;数组相关
global MySetGlobalArray := WorkSetGlobalArray
global MyCloneGlobalArray := WorkCloneGlobalArray
global MyDeleteGlobalArray := WorkDeleteGlobalArray
global MyModifyGlobalArray := WorkModifyGlobalArray
global MyInsertGlobalArray := WorkInsertGlobalArray
global MyRemoveAtGlobalArray := WorkRemoveAtGlobalArray
WorkOpenCVLoadDll()
SetTimer(CheckOcrIdle, 60000)

global shmTx := SharedMemory(txName, 1048576)
global shmRx := SharedMemory(rxName, 1048576)
global tx := RingBuffer(shmTx.ptr, 1048576)
global rx := RingBuffer(shmRx.ptr, 1048576)
global hEvent := OpenEvent(evtName)

SetTimer(ProcessQueue, 1)
ProcessQueue() {
    global tx, rx, hEvent
    if (DllCall("WaitForSingleObject", "ptr", hEvent, "uint", 0) == 0) {
        while (tx.Pop(&id, &cmd)) {
            if (id > 0) {
                result := ExecTask(cmd)
                rx.Push(id, result)
            } else {
                ; Legacy string command (id == 0)
                OnWorkGetCmdStrRingBuffer(cmd)
            }
        }
        ResetEvent(hEvent)
    }
}

ExecTask(cmd) {
    ; Execute task via existing logic or expand
    if (IsSet(MyExcuteRMTCMDAction)) {
        try return MyExcuteRMTCMDAction(cmd)
    }
    return 1
}

; 注册消息
OnMessage(WM_TR_MACRO, OnWorkTriggerMacro)
OnMessage(WM_STOP_MACRO, OnWorkStopMacro)
OnMessage(WM_CLEAR_WORK, OnExit)
OnMessage(WM_COPYDATA, OnWorkGetCmdStr)
OnMessage(WM_RECEIVE_INFO, OnMainReceiveInfo)

myTitle := "RMTWork" workIndex
mygui := Gui("+ToolWindow")          ; 创建 GUI，无标题栏
mygui.Title := myTitle               ; 设置窗口标题（这才是 WinGetTitle 能读到的）
mygui.Show("Hide")                   ; 隐藏窗口
global myHwnd := mygui.Hwnd
MsgPostHandler(WM_LOAD_WORK, workIndex, A_ScriptHwnd)