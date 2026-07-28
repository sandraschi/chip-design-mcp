#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build the PyInstaller sidecar binary for the Tauri native wrapper.
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "=== chip-design-mcp sidecar build ===" -ForegroundColor Cyan

Push-Location $Root
try {
    $pi = uv run pyinstaller --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "-> Installing PyInstaller..." -ForegroundColor Yellow
        uv pip install pyinstaller
    } else {
        Write-Host "-> PyInstaller: $pi" -ForegroundColor Gray
    }

    Remove-Item -Recurse -Force "$Root\build\chip-design-mcp-backend" -ErrorAction SilentlyContinue
    Remove-Item -Force "$Root\dist\chip-design-mcp-backend.exe" -ErrorAction SilentlyContinue

    Write-Host "-> Running PyInstaller..." -ForegroundColor Yellow
    uv run pyinstaller chip-design-mcp-backend.spec --clean --noconfirm
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller failed (exit $LASTEXITCODE)" }

    $triple = "x86_64-pc-windows-msvc"
    $src = "$Root\dist\chip-design-mcp-backend.exe"

    if (-not (Test-Path $src)) { throw "Build output not found: $src" }

    # Release bundle (embedded in Tauri resources)
    $resDir = "$Root\native\resources"
    New-Item -ItemType Directory -Path $resDir -Force | Out-Null
    Copy-Item $src "$resDir\chip-design-mcp-backend.exe" -Force

    # Dev fallback (binaries/ with triple suffix for tauri dev)
    $devDir = "$Root\native\binaries"
    New-Item -ItemType Directory -Path $devDir -Force | Out-Null
    $devDst = "$devDir\chip-design-mcp-backend-$triple.exe"
    Copy-Item $src $devDst -Force

    $sizeMB = [math]::Round((Get-Item $src).Length / 1MB, 1)
    Write-Host "=== Sidecar ready ===" -ForegroundColor Green
    Write-Host "  $resDir\chip-design-mcp-backend.exe ($sizeMB MB)" -ForegroundColor Cyan
} finally {
    Pop-Location
}
