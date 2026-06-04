@echo off
chcp 65001 >nul
setlocal

:: ============================================================
::  AHK-XAML 引擎编译脚本
::  将 XAML_AHK_Bridge.cs 编译为 ahk-xaml.dll
:: ============================================================

set "LIB_DIR=%~dp0Plugins\AHK-XAML\lib"
set "SOURCE=%LIB_DIR%\XAML_AHK_Bridge.cs"
set "OUTPUT=%LIB_DIR%\ahk-xaml.dll"
set "ERR_LOG=%~dp0Plugins\AHK-XAML\Logs\compile_error.log"

:: 检查源文件是否存在
if not exist "%SOURCE%" (
    echo [ERROR] XAML_AHK_Bridge.cs not found: %SOURCE%
    pause
    exit /b 1
)

:: 查找 csc.exe（优先 64 位）
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    echo [ERROR] csc.exe not found. Please install .NET Framework 4.0+
    pause
    exit /b 1
)

echo [INFO] CSC: %CSC%
echo [INFO] Source: %SOURCE%
echo [INFO] Output: %OUTPUT%
echo.

:: 提取 csc.exe 所在目录作为 WPF 引用目录
for %%I in ("%CSC%") do set "CSC_DIR=%%~dpI"
set "WPF_LIB=%CSC_DIR%WPF"

:: 可选引用
set "EXTRA_REFS="
set "EXTRA_DEFS="

:: WpfAnimatedGif.dll
if exist "%LIB_DIR%\WpfAnimatedGif.dll" (
    set "EXTRA_REFS=%EXTRA_REFS% /reference:"%LIB_DIR%\WpfAnimatedGif.dll""
    echo [INFO] Found WpfAnimatedGif.dll
)

:: MaterialDesignThemes.Wpf.dll
if exist "%LIB_DIR%\MaterialDesignThemes.Wpf.dll" (
    set "EXTRA_REFS=%EXTRA_REFS% /reference:"%LIB_DIR%\MaterialDesignThemes.Wpf.dll""
    echo [INFO] Found MaterialDesignThemes.Wpf.dll
)

:: WebView2 (可选，取消注释以启用)
:: if exist "%LIB_DIR%\WebView2\Microsoft.Web.WebView2.Core.dll" (
::     if exist "%LIB_DIR%\WebView2\Microsoft.Web.WebView2.Wpf.dll" (
::         set "EXTRA_REFS=%EXTRA_REFS% /reference:"%LIB_DIR%\WebView2\Microsoft.Web.WebView2.Core.dll" /reference:"%LIB_DIR%\WebView2\Microsoft.Web.WebView2.Wpf.dll""
::         set "EXTRA_DEFS=/define:ENABLE_WEBVIEW"
::         echo [INFO] Found WebView2 DLLs
::     )
:: )

:: 嵌入资源（BAML 或 XAML）
set "RESOURCES="
if exist "%LIB_DIR%\xaml.components.baml" (
    set "RESOURCES=/resource:"%LIB_DIR%\xaml.components.baml""
    echo [INFO] Embedding xaml.components.baml
) else if exist "%LIB_DIR%\xaml.components.xaml" (
    set "RESOURCES=/resource:"%LIB_DIR%\xaml.components.xaml""
    echo [INFO] Embedding xaml.components.xaml
)

:: 创建日志目录
if not exist "%~dp0Plugins\AHK-XAML\Logs" mkdir "%~dp0Plugins\AHK-XAML\Logs"

:: 编译
echo.
echo [INFO] Compiling...
"%CSC%" /nologo /target:winexe /platform:anycpu /out:"%OUTPUT%" /lib:"%WPF_LIB%" /reference:System.dll /reference:System.Core.dll /reference:System.Xml.dll /reference:PresentationFramework.dll /reference:PresentationCore.dll /reference:WindowsBase.dll /reference:System.Xaml.dll /reference:UIAutomationProvider.dll /reference:UIAutomationTypes.dll %EXTRA_REFS% %EXTRA_DEFS% %RESOURCES% "%SOURCE%" > "%ERR_LOG%" 2>&1

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Compilation failed! Error code: %ERRORLEVEL%
    echo.
    echo === Error Log ===
    type "%ERR_LOG%"
    echo.
    echo =================
    pause
    exit /b 1
)

if exist "%OUTPUT%" (
    echo [OK] Compilation successful!
    echo [OK] Output: %OUTPUT%
    for %%F in ("%OUTPUT%") do echo [OK] Size: %%~zF bytes
) else (
    echo [ERROR] Output file not created: %OUTPUT%
    type "%ERR_LOG%"
    pause
    exit /b 1
)

echo.
pause
