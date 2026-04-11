#Requires AutoHotkey v2.0
#SingleInstance Force

dllPath := A_ScriptDir "\Plugins\OpenCV\RMT_OpenCV.dll"
if !FileExist(dllPath) {
    MsgBox "找不到 DLL: " dllPath
    ExitApp
}

saveDir := A_ScriptDir "\Images\FreePaste"
DirCreate(saveDir)

; ====== GUI ======
MyGui := Gui("+AlwaysOnTop", "captureScreen 测试工具 (DWM)")
MyGui.SetFont("s10")
MyGui.Add("Text",, "窗口句柄:")
edtHwnd := MyGui.Add("Edit", "vEdtHwnd w200 ReadOnly")
MyGui.Add("Text", "xm", "区域 (x,y,w,h):")
edtRegion := MyGui.Add("Edit", "vEdtRegion w200", "0,0,0,0")
btnBind := MyGui.Add("Button", "w100", "绑定窗口 (F1)")
btnCapture := MyGui.Add("Button", "wp Default", "截图 (F2)")
btnOpen := MyGui.Add("Button", "wp", "打开文件夹")
lblStatus := MyGui.Add("Text", "xm h30 w220", "就绪")

btnBind.OnEvent("Click", OnBind)
btnCapture.OnEvent("Click", OnCapture)
btnOpen.OnEvent("Click", (*) => Run('explorer.exe "' saveDir '"'))
MyGui.OnEvent("Close", (*) => ExitApp)
MyGui.Show()

; ====== 快捷键 ======
F1:: OnBind()
F2:: OnCapture()

; ====== 绑定窗口 ======
OnBind(*) {
    MouseGetPos ,, &hwnd
    title := WinGetTitle("ahk_id " hwnd)
    edtHwnd.Value := hwnd
    lblStatus.Value := "已绑定: " title
}

; ====== 截图 ======
OnCapture(*) {
    hwnd := edtHwnd.Value
    if (!hwnd) {
        lblStatus.Value := "请先绑定窗口"
        return
    }
    
    ; 解析区域
    parts := StrSplit(edtRegion.Value, ",")
    x := Integer(parts.Has(1) ? parts[1] : 0)
    y := Integer(parts.Has(2) ? parts[2] : 0)
    w := Integer(parts.Has(3) ? parts[3] : 0)
    h := Integer(parts.Has(4) ? parts[4] : 0)

    ts := FormatTime(, "yyyyMMdd_HHmmss")
    path := saveDir "\Capture_" ts ".png"

    ; CaptureWinMat -> SaveMatToFile -> ReleaseMat
    matPtr := DllCall(dllPath "\CaptureWinMat", "Int", hwnd, "Int", x, "Int", y, "Int", w, "Int", h, "Ptr")
    if (!matPtr) {
        lblStatus.Value := "截图失败: Mat为空"
        return
    }

    ret := DllCall(dllPath "\SaveMatToFile", "Ptr", matPtr, "AStr", path, "Int")
    DllCall(dllPath "\ReleaseMat", "Ptr", matPtr)

    lblStatus.Value := ret ? "已保存: " path : "保存失败"
}
