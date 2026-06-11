#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Full release build: webapp + PyInstaller sidecar + Tauri NSIS installer → repo dist/
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Version = "0.1.0"

Write-Host "=== chip-design-mcp Tauri Release Build ===" -ForegroundColor Cyan

Write-Host "-> [1/5] Tauri icons..." -ForegroundColor Yellow
pwsh -NoLogo -File "$Root\scripts\generate-tauri-icon.ps1"

Write-Host "-> [2/5] Building webapp..." -ForegroundColor Yellow
Push-Location "$Root\webapp"
try {
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        bun install
        if ($LASTEXITCODE -ne 0) { throw "bun install failed" }
        bun run build
    } else {
        npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        npm run build
    }
    if ($LASTEXITCODE -ne 0) { throw "webapp build failed" }
} finally {
    Pop-Location
}

Write-Host "-> [3/5] PyInstaller sidecar..." -ForegroundColor Yellow
pwsh -NoLogo -File "$PSScriptRoot\build-sidecar.ps1"

Write-Host "-> [4/5] Tauri bundle..." -ForegroundColor Yellow
Push-Location $PSScriptRoot
try {
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install in native/ failed" }
    npx @tauri-apps/cli build
    if ($LASTEXITCODE -ne 0) { throw "tauri build failed" }
} finally {
    Pop-Location
}

Write-Host "-> [5/5] Copy installer to dist/..." -ForegroundColor Yellow
$nsis = Get-ChildItem "$PSScriptRoot\target\release\bundle\nsis\*-setup.exe" -ErrorAction Stop | Select-Object -First 1
$distDir = "$Root\dist"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
$releaseName = "chip-design-mcp-v$Version-x64-setup.exe"
$releasePath = Join-Path $distDir $releaseName
Copy-Item $nsis.FullName $releasePath -Force

$sizeMB = [math]::Round((Get-Item $releasePath).Length / 1MB, 1)
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "Installer: $releasePath ($sizeMB MB)" -ForegroundColor Cyan
Write-Host "NSIS source: $($nsis.FullName)" -ForegroundColor Gray
