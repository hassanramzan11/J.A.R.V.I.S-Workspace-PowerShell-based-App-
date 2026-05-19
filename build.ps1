# Compiles the Inno Setup installer.
# Requires Inno Setup 6: https://jrsoftware.org/isdl.php
$ErrorActionPreference = 'Stop'

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    Write-Host "ISCC.exe not found. Install Inno Setup 6 from https://jrsoftware.org/isdl.php" -ForegroundColor Red
    exit 1
}

$iss = Join-Path $PSScriptRoot 'installer\setup.iss'
Write-Host "Compiling $iss ..." -ForegroundColor Cyan
& $iscc $iss
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$out = Join-Path $PSScriptRoot 'dist'
Write-Host ""
Write-Host "Built installer is in: $out" -ForegroundColor Green
Get-ChildItem $out -Filter '*.exe' | ForEach-Object { Write-Host "  -> $($_.FullName)" }
