# Automated EDA + PDK bootstrap (Windows naked-PC). No manual apt/brew steps for the user.
# Called from webapp/start.ps1 unless SKIP_EDA_INSTALL=1.
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$UvExe
)

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$BinDir = Join-Path $RepoRoot 'bin'
$Sky130VolareId = '0bbdd5'
$OpenLaneImage = 'ghcr.io/the-openroad-project/openlane:latest'

function Get-WingetExe {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget -and $winget.Source) { return $winget.Source }
    foreach ($c in @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )) {
        $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Install-WingetPackage {
    param([string]$WingetId, [string]$Label)
    $winget = Get-WingetExe
    if (-not $winget) {
        Write-Host "  [!!] winget missing; cannot auto-install $Label" -ForegroundColor Red
        return $false
    }
    Write-Host "  [--] Installing $Label via winget ($WingetId) ..." -ForegroundColor Yellow
    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    return $true
}

function Test-ToolAvailable {
    param([string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return $true }
    $shim = Join-Path $BinDir "$Name.cmd"
    return (Test-Path -LiteralPath $shim)
}

function New-WslShim {
    param([string]$Name)
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $shim = Join-Path $BinDir "$Name.cmd"
    $content = "@echo off`r`nwsl -e bash -lc `"$Name %*`"`r`n"
    [System.IO.File]::WriteAllText($shim, $content)
}

function Ensure-WslEdaBinaries {
    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Host '  [--] WSL not found - installing Ubuntu (may require reboot) ...' -ForegroundColor Yellow
        if (-not (Install-WingetPackage -WingetId 'Canonical.Ubuntu.2204' -Label 'Ubuntu 22.04 (WSL)')) {
            return $false
        }
        $wsl = Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wsl) {
            Write-Host '  [!!] WSL still unavailable. Reboot, then re-run start.bat.' -ForegroundColor Red
            return $false
        }
    }

    Write-Host '  [..] Installing yosys, iverilog, magic, netgen inside WSL (apt) ...' -ForegroundColor DarkCyan
    $aptCmd = 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get update -qq; sudo apt-get install -y yosys iverilog magic netgen; command -v yosys; command -v iverilog'
    wsl -e bash -lc $aptCmd 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] WSL apt install failed. Open Ubuntu once, then re-run start.bat.' -ForegroundColor Red
        return $false
    }

    foreach ($tool in @('yosys', 'iverilog', 'magic', 'netgen')) {
        New-WslShim -Name $tool
    }
    Write-Host '  [ok] WSL EDA binaries + Windows shims in bin/' -ForegroundColor DarkGreen
    return $true
}

function Ensure-DockerOpenLane {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host '  [--] Docker not found - installing Docker Desktop ...' -ForegroundColor Yellow
        if (-not (Install-WingetPackage -WingetId 'Docker.DockerDesktop' -Label 'Docker Desktop')) {
            return $false
        }
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Write-Host '  [!!] Docker installed but not on PATH. Start Docker Desktop, then re-run start.bat.' -ForegroundColor Red
            return $false
        }
    }
    Write-Host "  [..] Pulling OpenLane image ($OpenLaneImage) ..." -ForegroundColor DarkCyan
    docker pull $OpenLaneImage 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] docker pull failed. Ensure Docker Desktop is running.' -ForegroundColor Red
        return $false
    }
    Write-Host '  [ok] OpenLane Docker image ready' -ForegroundColor DarkGreen
    return $true
}

function Ensure-VolarePdk {
    Write-Host '  [..] Installing volare + sky130 PDK (uv) ...' -ForegroundColor DarkCyan
    & $UvExe pip install --project $RepoRoot volare 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] volare pip install failed' -ForegroundColor Red
        return $false
    }
    & $UvExe run --project $RepoRoot volare enable --pdk sky130 $Sky130VolareId 2>&1 | ForEach-Object {
        Write-Host "    $_" -ForegroundColor DarkGray
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] volare enable failed' -ForegroundColor Red
        return $false
    }
    $pdkRoot = (& $UvExe run --project $RepoRoot volare which 2>$null | Select-Object -Last 1).ToString().Trim()
    if ($pdkRoot) {
        $env:PDK_ROOT = $pdkRoot
        [System.Environment]::SetEnvironmentVariable('PDK_ROOT', $pdkRoot, 'User')
        Write-Host "  [ok] PDK_ROOT=$pdkRoot" -ForegroundColor DarkGreen
    }
    return [bool]$pdkRoot
}

Write-Host ''
Write-Host 'EDA toolchain bootstrap (automated)' -ForegroundColor Cyan

$env:PATH = "$BinDir;" + $env:PATH
$ok = $true

if (-not (Test-ToolAvailable 'yosys')) {
    if (-not (Ensure-WslEdaBinaries)) { $ok = $false }
} else {
    Write-Host '  [ok] yosys on PATH' -ForegroundColor DarkGreen
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    if (-not (Ensure-DockerOpenLane)) { $ok = $false }
} else {
    $img = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -SimpleMatch $OpenLaneImage
    if (-not $img) {
        if (-not (Ensure-DockerOpenLane)) { $ok = $false }
    } else {
        Write-Host '  [ok] OpenLane Docker image present' -ForegroundColor DarkGreen
    }
}

if (-not $env:PDK_ROOT -or -not (Test-Path -LiteralPath $env:PDK_ROOT)) {
    if (-not (Ensure-VolarePdk)) { $ok = $false }
} else {
    Write-Host "  [ok] PDK_ROOT=$($env:PDK_ROOT)" -ForegroundColor DarkGreen
}

$env:PATH = "$BinDir;" + $env:PATH
if (-not $ok) {
    Write-Host ''
    Write-Host 'EDA bootstrap incomplete. Server will start but synthesis/sim/P&R may fail until tools are ready.' -ForegroundColor Yellow
    exit 1
}
Write-Host '  [ok] EDA bootstrap complete' -ForegroundColor Green
exit 0
