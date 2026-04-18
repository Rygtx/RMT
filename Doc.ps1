# RMT 帮助文档 - 一键打包（单文件 HTML）
# 用法: 右键 → 使用 PowerShell 运行

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "RMT 文档打包工具"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RMT 帮助文档  打包工具" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebDir = Join-Path $ScriptDir "Web"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[错误] 未找到 Node.js，请先安装: https://nodejs.org/" -ForegroundColor Red
    exit 1
}
Write-Host "[1/1] Node.js $(node -v)  正在打包 ..." -ForegroundColor Green

Push-Location $WebDir
node SingleHtml.js
Pop-Location

$OutputFile = Join-Path $ScriptDir "RMT帮助文档.html"
if (Test-Path $OutputFile) {
    $size = [math]::Round((Get-Item $OutputFile).Length / 1024, 1)
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  ✓ 打包成功!" -ForegroundColor Green
    Write-Host "  输出文件: $OutputFile" -ForegroundColor White
    Write-Host "  文件大小: ${size} KB" -ForegroundColor White
    Write-Host "  双击即可用浏览器打开查看" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Green
}
