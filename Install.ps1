# ============================================
#   JARVIS Workspace - Auto Installer
# ============================================
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE "AppData\Local\JarvisTools"
$VdUrl      = "https://github.com/MScholtes/VirtualDesktop/releases/download/v1.16/VirtualDesktop11-24H2.zip"
$VdExePath  = Join-Path $InstallDir "VirtualDesktop.exe"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "  Install location: $InstallDir" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "  [1/5] Created install folder." -ForegroundColor Green
} else {
    Write-Host "  [1/5] Install folder exists." -ForegroundColor Green
}

$files = @("Jarvis_Builder.ps1","Jarvis_Builder.bat","README.md")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (Test-Path $src) { Copy-Item $src -Destination $InstallDir -Force }
}
Write-Host "  [2/5] Copied scripts." -ForegroundColor Green

if (-not (Test-Path $VdExePath)) {
    Write-Host "  [3/5] Downloading VirtualDesktop.exe ..." -ForegroundColor Yellow
    try {
        $tmpZip = Join-Path $env:TEMP "VirtualDesktop_tmp.zip"
        $tmpDir = Join-Path $env:TEMP "VirtualDesktop_tmp"
        if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $VdUrl -OutFile $tmpZip -UseBasicParsing
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
        $foundExe = Get-ChildItem -Path $tmpDir -Filter *.exe -Recurse | Select-Object -First 1
        if ($foundExe) {
            Copy-Item $foundExe.FullName -Destination $VdExePath -Force
            Write-Host "        Downloaded and installed." -ForegroundColor Green
        } else { throw "No .exe found in downloaded archive." }
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "        [WARN] Auto-download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "        Download manually from:" -ForegroundColor Yellow
        Write-Host "        https://github.com/MScholtes/VirtualDesktop/releases" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [3/5] VirtualDesktop.exe already present." -ForegroundColor Green
}

function New-Shortcut($targetBat, $linkPath, $description = "") {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($linkPath)
    $sc.TargetPath       = $targetBat
    $sc.WorkingDirectory = Split-Path $targetBat -Parent
    $sc.Description      = $description
    $sc.Save()
}

$desktop      = [Environment]::GetFolderPath("Desktop")
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\JARVIS Workspace"
if (-not (Test-Path $startMenuDir)) { New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null }

New-Shortcut (Join-Path $InstallDir "Jarvis_Builder.bat") (Join-Path $desktop "JARVIS Workspace.lnk") "Build, edit, and launch your workspaces"
New-Shortcut (Join-Path $InstallDir "Jarvis_Builder.bat") (Join-Path $startMenuDir "JARVIS Workspace.lnk")
Write-Host "  [4/5] Created Desktop + Start Menu shortcuts." -ForegroundColor Green

$uninstall = @"
@echo off
title JARVIS Workspace - Uninstall
echo.
echo   Removing JARVIS Workspace...
rmdir /s /q "$InstallDir" 2>nul
del "$desktop\JARVIS Workspace.lnk" 2>nul
rmdir /s /q "$startMenuDir" 2>nul
echo   Done. Profiles in %%APPDATA%%\JarvisWorkspace are preserved.
pause
"@
Set-Content -Path (Join-Path $InstallDir "Uninstall.bat") -Value $uninstall -Encoding ASCII
Write-Host "  [5/5] Uninstaller created." -ForegroundColor Green

Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkGreen
Write-Host "    INSTALL COMPLETE" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "  Open 'JARVIS Workspace' on your Desktop to begin." -ForegroundColor White
Write-Host ""
