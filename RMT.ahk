#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Joy\SuperCvJoyInterface.ahk
#Include Joy\JoyMacro.ahk
#Include Plugins\RapidOcr\RapidOcr.ahk
#Include Plugins\CLR.ahk
#Include Plugins\IbInputSimulator.ahk
#Include Gui\TriggerKeyGui.ahk
#Include Gui\TriggerStrGui.ahk
#Include Gui\TimingGui.ahk
#Include Gui\MacroSettingGui.ahk
#Include Gui\VerticalSlider.ahk
#Include Gui\SettingMgrGui.ahk
#Include Gui\EditHotkeyGui.ahk
#Include Gui\FreePasteGui.ahk
#Include Gui\MacroEditGui.ahk
#Include Gui\MenuWheelGui.ahk
#Include Gui\ReplaceKeyGui.ahk
#Include Gui\UseExplainGui.ahk
#Include Gui\LoopGui.ahk
#Include Gui\TargetGui.ahk
#Include Gui\ColorPanelGui.ahk
#Include Gui\ToolRecordSettingGui.ahk
#Include Gui\VarListenGui.ahk
#Include Gui\CMDTipGui.ahk
#Include Gui\FrontInfoGui.ahk
#Include Gui\CMDTipSettingGui.ahk
#Include Gui\CustomMsgBoxGui.ahk
#Include Gui\CustomInputGui.ahk
#Include Gui\InputBtnGui.ahk
#Include Main\Gdip_All.ahk
;#Include Main\LineDrawer.ahk
#Include Main\LineOverlay.ahk
#Include Main\DataClass.ahk
#Include Main\AssetUtil.ahk
#Include Main\RecordJoyUtil.ahk
#Include Main\ThankUIUtil.ahk
#Include Main\HotkeyUtil.ahk
#Include Main\RMTUtil.ahk
#Include Main\WorkPool.ahk
#Include Main\TabItemUIUtil.ahk
#Include Main\UIUtil.ahk
#Include Main\JsonUtil.ahk
#Include Main\CompareUtil.ahk
#Include Main\TimingUtil.ahk
#Include Main\BindUtil.ahk
#Include Main\TextOpsUtil.ahk
#Include Main\InputUtil.ahk
#Include Main\VariableUtil.ahk
#Include Main\FixCompatUtil.ahk
#Include Main\LangUtil.ahk
#Include Main\TriggerKeyData.ahk
#Include Main\FolderPackager.ahk
SetWorkingDir A_ScriptDir
DetectHiddenWindows true
Persistent
A_MaxHotkeysPerInterval := 400

global MyvJoy := SuperCvJoyInterface().GetMyvJoy()
global MyJoyMacro := JoyMacro()
global MyMouseInfo := MouseWinData()
global MySoftData := SoftData()
global ToolCheckInfo := ToolCheck()
global IniFile := A_WorkingDir "\Setting\MainSettings.ini"
global LangDir := A_WorkingDir "\Lang"
LoadMainSetting()       ;加载配置

global MyTriggerKeyGui := TriggerKeyGui()
global MyTriggerStrGui := TriggerStrGui()
global MyEditHotkeyGui := EditHotkeyGui()
global MyMacroSettingGui := MacroSettingGui()
global MyVarListenGui := VarListenGui()
global MyMacroGui := MacroEditGui()
global MyMenuWheel := MenuWheelGui()
global MyReplaceKeyGui := ReplaceKeyGui()
global MyFreePasteGui := FreePasteGui()
global MySettingMgrGui := SettingMgrGui()
global MyFrontInfoGui := FrontInfoGui()
global MyCMDTipGui := CMDTipGui()
global MyTimingGui := TimingGui()
global MySlider := VerticalSlider()
global MyTargetGui := TargetGui()
global MyColorPanel := ColorPanelGui()
global MyMsgboxGui := CustomMsgBoxGui()
global MyInputGui := CustomInputGui()
global MyInputBtnGui := InputBtnGui()
global MyCMDTipSettingGui := CMDTipSettingGui()
global MyToolRecordSettingGui := ToolRecordSettingGui()
global MyUseExplainGui := UseExplainGui()
global MySubMacroStopAction := SubMacroStopAction
global MyTriggerSubMacro := TriggerMacroHandler
global MySetGlobalVariable := SetGlobalVariable
global MyDelGlobalVariable := DelGlobalVariable
global MyCMDReportAciton := CMDReport
global MyExcuteRMTCMDAction := ExcuteRMTCMDAction
global MySetTableItemState := SetTableItemState
global MySetItemPauseState := SetItemPauseState
global MyMsgBoxContent := MsgBoxContent
global MyToolTipContent := ToolTipContent
global MyMacroCount := MacroCount
;数组相关
global MySetGlobalArray := SetGlobalArray
global MyCloneGlobalArray := CloneGlobalArray
global MyDeleteGlobalArray := DeleteGlobalArray
global MyModifyGlobalArray := ModifyGlobalArray
global MyInsertGlobalArray := InsertGlobalArray
global MyRemoveAtGlobalArray := RemoveAtGlobalArray

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


