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
# Full open_pdks commit hash (volare rejects short ids like "0bbdd5"). See: volare ls-remote --pdk sky130
$Sky130VolarePreferred = '7519dfb04400f224f140749cda44ee7de6f5e095'
$Sky130VolareFallback = 'c6d73a35f524070e85faff4a6a9eef49553ebc2b'
# Digital RTL2GDS (skip sky130_sram_macros on Windows — avoids WinError 32 temp-file lock)
$Sky130VolareLibraries = @(
    'sky130_fd_io',
    'sky130_fd_pr',
    'sky130_fd_sc_hd',
    'sky130_fd_sc_hvl'
)
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

function Write-EdaProgress {
    param([string]$Message)
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "  [$ts] $Message" -ForegroundColor DarkCyan
}

function Invoke-WslRootScript {
    param(
        [string]$StepLabel,
        [string]$BashScript
    )
    Write-EdaProgress $StepLabel
    $started = Get-Date
    # Run as root so apt does not block on sudo password prompts.
    & wsl.exe -u root -e bash -lc $BashScript 2>&1 | ForEach-Object {
        $line = $_.ToString()
        if ($line.Trim().Length -gt 0) {
            Write-Host "      $line" -ForegroundColor DarkGray
        }
    }
    $sec = [int]((Get-Date) - $started).TotalSeconds
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!!] Failed: $StepLabel (exit $LASTEXITCODE, ${sec}s)" -ForegroundColor Red
        return $false
    }
    Write-Host "  [ok] $StepLabel (${sec}s)" -ForegroundColor DarkGreen
    return $true
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

    Write-Host ''
    Write-Host '  WSL EDA install (sub-steps; first apt update can take 5-15 min)' -ForegroundColor Cyan
    Write-Host '  If nothing prints for 10+ min, open "Ubuntu" from Start once, finish setup, re-run start.bat.' -ForegroundColor DarkYellow
    Write-Host ''

    if (-not (Invoke-WslRootScript -StepLabel 'WSL probe (root shell)' -BashScript 'echo WSL_OK; uname -a')) {
        Write-Host '  [!!] WSL did not respond. Install Ubuntu app, reboot if needed.' -ForegroundColor Red
        return $false
    }

    if (-not (Invoke-WslRootScript -StepLabel 'apt-get update' -BashScript 'export DEBIAN_FRONTEND=noninteractive; apt-get update')) {
        return $false
    }

    $packages = 'yosys iverilog magic netgen'
    if (-not (Invoke-WslRootScript -StepLabel "apt-get install -y $packages" -BashScript "export DEBIAN_FRONTEND=noninteractive; apt-get install -y $packages")) {
        return $false
    }

    if (-not (Invoke-WslRootScript -StepLabel 'Verify yosys + iverilog' -BashScript 'command -v yosys; yosys -V; command -v iverilog; iverilog -V')) {
        return $false
    }

    Write-EdaProgress 'Creating Windows shims in bin/'
    foreach ($tool in @('yosys', 'iverilog', 'magic', 'netgen')) {
        New-WslShim -Name $tool
        Write-Host "      bin\$tool.cmd" -ForegroundColor DarkGray
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
    Write-EdaProgress "docker pull $OpenLaneImage (large image; several minutes)"
    docker pull $OpenLaneImage 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] docker pull failed. Ensure Docker Desktop is running.' -ForegroundColor Red
        return $false
    }
    Write-Host '  [ok] OpenLane Docker image ready' -ForegroundColor DarkGreen
    return $true
}

function Get-VolareInstalledSky130Hashes {
    $raw = & $UvExe run --project $RepoRoot volare ls --pdk sky130 2>$null
    if (-not $raw) { return @() }
    try {
        return @($raw | ConvertFrom-Json)
    } catch {
        return @()
    }
}

function Test-Sky130PdkTree {
    param([string]$PdkRoot)
    if (-not $PdkRoot) { return $false }
    return Test-Path -LiteralPath (Join-Path $PdkRoot 'sky130A\libs.ref\sky130_fd_sc_hd\verilog')
}

function Resolve-VolarePdkRoot {
    $pathLine = (& $UvExe run --project $RepoRoot volare path 2>$null | Select-Object -First 1)
    if ($pathLine) {
        $root = $pathLine.ToString().Trim()
        if (Test-Sky130PdkTree -PdkRoot $root) { return $root }
    }
    $default = Join-Path $env:USERPROFILE '.volare'
    if (Test-Sky130PdkTree -PdkRoot $default) { return $default }
    return $null
}

function Enable-VolareSky130 {
    param([string]$OpenPdksHash)

    $installed = Get-VolareInstalledSky130Hashes
    $needsDownload = $installed -notcontains $OpenPdksHash
    if ($needsDownload) {
        Write-EdaProgress "volare enable --pdk sky130 $OpenPdksHash (first download; digital libs only, no SRAM macros)"
    } else {
        Write-EdaProgress "volare enable --pdk sky130 $OpenPdksHash (already cached; activating)"
    }

    $volareArgs = @('volare', 'enable', '--pdk', 'sky130', $OpenPdksHash)
    if ($needsDownload) {
        foreach ($lib in $Sky130VolareLibraries) {
            $volareArgs += '-l'
            $volareArgs += $lib
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    & $UvExe run --project $RepoRoot @volareArgs 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $lines.Add($line) | Out-Null
        Write-Host "      $line" -ForegroundColor DarkGray
    }
    $text = $lines -join "`n"

    if ($LASTEXITCODE -eq 0) { return $true }
    if ($text -match 'enabled for the sky130 PDK') { return $true }

    # Windows: volare sometimes hits WinError 32 cleaning temp tarballs after a successful download.
    if ($text -match 'WinError 32') {
        Write-Host '      [warn] Windows temp cleanup (WinError 32). Checking if PDK actually installed ...' -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        if ((Get-VolareInstalledSky130Hashes) -contains $OpenPdksHash) {
            Write-Host '      [ok] PDK version is in volare store; treating as success.' -ForegroundColor DarkGreen
            & $UvExe run --project $RepoRoot volare enable --pdk sky130 $OpenPdksHash 2>&1 | Out-Null
            return $true
        }
        Write-EdaProgress 'Retry volare enable once after temp lock ...'
        Start-Sleep -Seconds 5
        & $UvExe run --project $RepoRoot volare enable --pdk sky130 $OpenPdksHash 2>&1 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor DarkGray
        }
        if ($LASTEXITCODE -eq 0) { return $true }
        if (Test-Sky130PdkTree -PdkRoot (Resolve-VolarePdkRoot)) { return $true }
    }

    return $false
}

function Ensure-VolarePdk {
    Write-EdaProgress 'volare pip install (uv)'
    & $UvExe pip install --project $RepoRoot volare 2>&1 | ForEach-Object {
        Write-Host "      $_" -ForegroundColor DarkGray
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!!] volare pip install failed' -ForegroundColor Red
        return $false
    }

    if ($env:SKY130_VOLARE_HASH) {
        $candidates = @($env:SKY130_VOLARE_HASH.Trim())
    } else {
        $candidates = @($Sky130VolarePreferred, $Sky130VolareFallback)
    }
    $enabled = $false
    foreach ($hash in $candidates) {
        if (Enable-VolareSky130 -OpenPdksHash $hash) {
            $enabled = $true
            break
        }
        Write-Host "  [--] Retry with alternate open_pdks hash ..." -ForegroundColor Yellow
    }
    if (-not $enabled) {
        Write-Host '  [!!] volare enable failed for all pinned hashes.' -ForegroundColor Red
        Write-Host '      List remotes: uv run volare ls-remote --pdk sky130' -ForegroundColor DarkYellow
        Write-Host '      Then: uv run volare enable --pdk sky130 <full-40-char-hash>' -ForegroundColor DarkYellow
        return $false
    }
    $pdkRoot = Resolve-VolarePdkRoot
    if ($pdkRoot) {
        $env:PDK_ROOT = $pdkRoot
        [System.Environment]::SetEnvironmentVariable('PDK_ROOT', $pdkRoot, 'User')
        Write-Host "  [ok] PDK_ROOT=$pdkRoot" -ForegroundColor DarkGreen
        return $true
    }
    Write-Host '  [!!] sky130A not found under volare path. Run: uv run volare path' -ForegroundColor Red
    return $false
}

Write-Host ''
Write-Host 'EDA toolchain bootstrap (automated)' -ForegroundColor Cyan
Write-Host '  Phases: (A) WSL apt tools  (B) Docker OpenLane  (C) volare sky130 PDK' -ForegroundColor DarkGray
Write-Host ''

$env:PATH = "$BinDir;" + $env:PATH
$ok = $true

if (-not (Test-ToolAvailable 'yosys')) {
    Write-Host '--- Phase A: WSL EDA (yosys, iverilog, magic, netgen) ---' -ForegroundColor Cyan
    if (-not (Ensure-WslEdaBinaries)) { $ok = $false }
} else {
    Write-Host '--- Phase A: WSL EDA ---' -ForegroundColor Cyan
    Write-Host '  [ok] yosys on PATH (skip apt)' -ForegroundColor DarkGreen
}

Write-Host ''
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host '--- Phase B: Docker + OpenLane image ---' -ForegroundColor Cyan
    if (-not (Ensure-DockerOpenLane)) { $ok = $false }
} else {
    Write-Host '--- Phase B: Docker + OpenLane image ---' -ForegroundColor Cyan
    $img = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -SimpleMatch $OpenLaneImage
    if (-not $img) {
        if (-not (Ensure-DockerOpenLane)) { $ok = $false }
    } else {
        Write-Host '  [ok] OpenLane Docker image present' -ForegroundColor DarkGreen
    }
}

Write-Host ''
if (-not $env:PDK_ROOT -or -not (Test-Path -LiteralPath $env:PDK_ROOT)) {
    Write-Host '--- Phase C: volare sky130 PDK ---' -ForegroundColor Cyan
    if (-not (Ensure-VolarePdk)) { $ok = $false }
} else {
    Write-Host '--- Phase C: volare sky130 PDK ---' -ForegroundColor Cyan
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
