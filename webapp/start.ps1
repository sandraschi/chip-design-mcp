# start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# Fast port helpers (scripts/PortHelpers.ps1)
# start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
_RepoRootForPorts = Split-Path -Parent $PSScriptRoot
# start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
_PortHelpers = Join-Path # start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
_RepoRootForPorts 'scripts\PortHelpers.ps1'
if (Test-Path -LiteralPath # start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
_PortHelpers) { . # start.ps1 - Chip Design MCP + Webapp (SOTA 2026, naked-PC compliant)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
_PortHelpers }

# --- SOTA Headless Standard ---
if ($Headless -and ($Host.UI.RawUI.WindowTitle -notmatch 'Hidden')) {
    $relaunch = @('-NoProfile', '-File', $PSCommandPath, '-Headless')
    if ($BackendOnly) { $relaunch += '-BackendOnly' }
    if ($NoBrowser)  { $relaunch += '-NoBrowser' }
    Start-Process powershell.exe -ArgumentList $relaunch -WindowStyle Hidden
    exit
}
# ------------------------------

# ErrorActionPreference left at default (Continue): winget returns non-zero exit
# codes for "already installed", which would crash the script under Stop mode.
$BackendPort  = 11022
$FrontendPort = 11023
$WebRoot      = $PSScriptRoot
$RepoRoot     = Split-Path -Parent $WebRoot
$env:CHIP_DESIGN_MCP_REPO_ROOT = $RepoRoot
$env:CHIP_DESIGN_MCP_WORK_DIR = "$env:TEMP\chip_design_mcp_work"

Write-Host ""
Write-Host "Chip Design MCP - Setup and Start" -ForegroundColor Cyan
Write-Host "Backend :$BackendPort   Frontend :$FrontendPort" -ForegroundColor DarkGray
Write-Host ""

# ===========================================================================
# FUNCTION: require a command, install via winget if missing
# ===========================================================================
function Require-Command {
    param([string]$Cmd, [string]$WingetId, [string]$Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $Label" -ForegroundColor DarkGreen
        return
    }
    Write-Host "  [--] $Label not found - installing via winget ..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $winget = $found.FullName; break }
        }
    } else {
        $winget = $winget.Source
    }

    if (-not $winget) {
        Write-Host "ERROR: winget not found. Install $Label manually:" -ForegroundColor Red
        Write-Host "  winget install --id $WingetId" -ForegroundColor Yellow
        exit 1
    }

    & $winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $Label installed but '$Cmd' still not in PATH." -ForegroundColor Red
        Write-Host "Close this window, reopen PowerShell, and run start.bat again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [ok] $Label installed" -ForegroundColor Green
}

function Get-BunExePath {
    $bun = Get-Command bun -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bun -and $bun.Source) { return $bun.Source }
    $homeBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $homeBun) { return $homeBun }
    return $null
}

# Resolve npm.cmd next to node.exe (Get-Command npm can return a shim with a bad .Source)
function Get-NpmCmdPath {
    $nodeApp = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodeSrc = if ($nodeApp -and $nodeApp.Source -and ($nodeApp.Source -ne '')) { $nodeApp.Source } else { $null }
    if (-not $nodeSrc) { $nodeSrc = [string](where.exe node 2>$null | Select-Object -First 1) }
    if ($nodeSrc -and ($nodeSrc -ne '')) {
        $nodeDir = Split-Path -Path ([string]$nodeSrc) -Parent
        $cmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $cmd) { return $cmd }
    }
    $npmApp = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($npmApp -and $npmApp.Source -and ($npmApp.Source -ne '')) { return $npmApp.Source }
    $npmWhere = [string](where.exe npm 2>$null | Select-Object -First 1)
    if ($npmWhere) { return $npmWhere }
    return $null
}

# npm creates node_modules/.bin/vite(.cmd); Bun on Windows uses vite.exe / vite.bunx
function Test-ViteBinPresent {
    param([string]$WebRootPath)
    $bin = Join-Path $WebRootPath "node_modules\.bin"
    foreach ($name in @('vite', 'vite.cmd', 'vite.exe', 'vite.bunx')) {
        if (Test-Path -LiteralPath (Join-Path $bin $name)) { return $true }
    }
    $pkg = Join-Path $WebRootPath "node_modules\vite\package.json"
    return (Test-Path -LiteralPath $pkg)
}

# ===========================================================================
# STEP 1 - Prerequisites
# ===========================================================================
Write-Host "[1/6] Checking prerequisites ..." -ForegroundColor Cyan
Require-Command "uv"   "Astral.uv"          "uv (Python package manager)"
Require-Command "just" "Casey.Just"         "just (command runner)"
if (-not $BackendOnly) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js LTS (Vite runtime)"
    Require-Command "npm"  "OpenJS.NodeJS.LTS" "npm"
}

# ===========================================================================
# STEP 2 - Python deps + import smoke-test
# ===========================================================================
$uvExe = (Get-Command uv).Source
if ($env:SKIP_SYNC -eq "1") {
    Write-Host "[2/6] Skipping Python deps (SKIP_SYNC=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[2/6] Syncing Python deps (uv sync --all-extras) ..." -ForegroundColor Cyan
    & $uvExe sync --all-extras --project $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: uv sync failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] Python deps ready" -ForegroundColor DarkGreen
}

Write-Host "  Smoke-testing import ..." -ForegroundColor DarkGray
$serverPy = Join-Path $RepoRoot 'src\chip_design_mcp\server.py'
if (-not (Test-Path -LiteralPath $serverPy)) {
    Write-Host "ERROR: missing $serverPy" -ForegroundColor Red
    exit 1
}
$serverLen = (Get-Item -LiteralPath $serverPy).Length
if ($serverLen -lt 1024) {
    Write-Host "ERROR: server.py truncated ($serverLen bytes). Restore from git: git checkout -- src/chip_design_mcp/server.py" -ForegroundColor Red
    exit 1
}
& $uvExe run --project $RepoRoot python -c "import chip_design_mcp.server; print('  [ok] Import OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: import check failed -- see output above." -ForegroundColor Red
    exit 1
}

# ===========================================================================
# STEP 3 - EDA toolchain (yosys, Docker/OpenLane, volare PDK)
# ===========================================================================
$binDir = Join-Path $RepoRoot 'bin'
if (Test-Path -LiteralPath $binDir) {
    $env:PATH = "$binDir;" + $env:PATH
}
if ($env:SKIP_EDA_INSTALL -eq "1") {
    Write-Host "[3/6] Skipping EDA install (SKIP_EDA_INSTALL=1)" -ForegroundColor DarkGray
} else {
    Write-Host "[3/6] EDA toolchain (Docker, WSL yosys, volare sky130) ..." -ForegroundColor Cyan
    $installEda = Join-Path $RepoRoot 'scripts\install-eda.ps1'
    if (-not (Test-Path -LiteralPath $installEda)) {
        Write-Host "ERROR: missing $installEda" -ForegroundColor Red
        exit 1
    }
    & $installEda -RepoRoot $RepoRoot -UvExe $uvExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: EDA bootstrap failed. Fix Docker/WSL/winget, or set SKIP_EDA_INSTALL=1 for MCP-only." -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $binDir) {
        $env:PATH = "$binDir;" + $env:PATH
    }
}

# ===========================================================================
# STEP 4 - Frontend deps + vite guard
# ===========================================================================
if (-not $BackendOnly) {
    $bunExe = Get-BunExePath
    $useBun = [bool]$bunExe
    if ($useBun) {
        Write-Host "[4/6] Syncing frontend deps (bun install) ..." -ForegroundColor Cyan
    } else {
        Write-Host "[4/6] Syncing frontend deps (npm install - Bun not found) ..." -ForegroundColor Cyan
    }
    $npmCmd = Get-NpmCmdPath
    if (-not $useBun -and -not $npmCmd) {
        Write-Host "ERROR: Could not resolve bun or npm." -ForegroundColor Red
        exit 1
    }
    $needFrontendInstall = -not (Test-Path (Join-Path $WebRoot "node_modules"))
    if (-not $needFrontendInstall -and -not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "  [--] node_modules present but vite missing - reinstalling ..." -ForegroundColor Yellow
        $needFrontendInstall = $true
    }
    if ($needFrontendInstall) {
        Push-Location $WebRoot
        if ($useBun) {
            & $bunExe install
        } else {
            & $npmCmd install --prefer-offline
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: frontend install failed." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "  [ok] node_modules installed" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ok] node_modules present (skipping install)" -ForegroundColor DarkGreen
    }
    if (-not (Test-ViteBinPresent -WebRootPath $WebRoot)) {
        Write-Host "ERROR: vite missing after install. Delete '$WebRoot\node_modules' and re-run." -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok] vite present" -ForegroundColor DarkGreen
    $script:FrontendRunner = if ($useBun) { $bunExe } else { $npmCmd }
    $script:FrontendRunArgs = if ($useBun) { @("run", "dev") } else { @("run", "dev") }
} else {
    Write-Host "  [ok] Skipping frontend deps (BackendOnly mode)" -ForegroundColor DarkGray
}

# ===========================================================================
# STEP 4 - Clear ports
# ===========================================================================
Write-Host "[5/6] Clearing ports $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
foreach ($port in @($BackendPort, $FrontendPort)) {
    $procIds = Get-PortListenerPidsFast -Port $port
    foreach ($procId in $procIds) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed PID $($procId) on :$port" -ForegroundColor Yellow
        } catch {}
    }
}
Start-Sleep -Milliseconds 500

# ===========================================================================
# STEP 5 - Start services
# ===========================================================================
Write-Host "[6/6] Starting services ..." -ForegroundColor Cyan

$backendLog = Join-Path $RepoRoot "backend.log"
$backendErr = Join-Path $RepoRoot "backend.err.log"
foreach ($logPath in @($backendLog, $backendErr)) {
    if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
}
$backendProc = Start-Process -FilePath $uvExe `
    -ArgumentList @(
        'run', '--project', $RepoRoot,
        'python', '-m', 'chip_design_mcp.server',
        '--mode', 'dual', '--port', "$BackendPort"
    ) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $backendLog `
    -RedirectStandardError $backendErr `
    -PassThru `
    -WindowStyle Hidden
Write-Host "  Backend PID $($backendProc.Id) on :$BackendPort  (log: $backendLog)"

$maxWait = 90; $waited = 0; $ready = $false
Write-Host "  Waiting for backend health (max ${maxWait}s) ..." -ForegroundColor DarkCyan
while ($waited -lt $maxWait) {
    if ($backendProc.HasExited) {
        Write-Host "ERROR: backend process exited (code $($backendProc.ExitCode))." -ForegroundColor Red
        break
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/v1/status" `
            -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $waited++
    if (($waited % 15) -eq 0) { Write-Host "    ... $waited s" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "ERROR: backend did not start after ${maxWait}s." -ForegroundColor Red
    Write-Host "Last lines from backend.log:" -ForegroundColor Yellow
    if (Test-Path $backendLog) { Get-Content $backendLog -Tail 30 }
    if (Test-Path $backendErr) {
        Write-Host "stderr:" -ForegroundColor Yellow
        Get-Content $backendErr -Tail 20
    }
    Write-Host "Run directly to see the full error:" -ForegroundColor Yellow
    Write-Host "  cd $RepoRoot; $uvExe run python -m chip_design_mcp.server" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [ok] Backend healthy after ${waited}s" -ForegroundColor Green

if ($BackendOnly) {
    Write-Host ""
    Write-Host "Backend-only mode active. Press Ctrl+C to stop." -ForegroundColor Cyan
    try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}
    exit
}

if (-not $script:FrontendRunner) {
    $script:FrontendRunner = if (Get-BunExePath) { Get-BunExePath } else { Get-NpmCmdPath }
    $script:FrontendRunArgs = @("run", "dev")
}
$frontendProc = Start-Process -FilePath $script:FrontendRunner `
    -ArgumentList $script:FrontendRunArgs `
    -WorkingDirectory $WebRoot `
    -PassThru
Write-Host "  Frontend PID $($frontendProc.Id) on :$FrontendPort" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    $url = "http://localhost:$FrontendPort"
    $poll = "for (`$i=0;`$i -lt 60;`$i++) { try { `$null=Invoke-WebRequest -Uri '$url' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; Start-Process '$url'; exit } catch { Start-Sleep 1 } }"
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$poll
    Write-Host "  Browser will open when Vite is ready" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running:" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$BackendPort/api/v1/status"
Write-Host "  Frontend  http://localhost:$FrontendPort"
Write-Host "  MCP SSE   http://localhost:$BackendPort/sse"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

try { Wait-Process -Id $backendProc.Id -ErrorAction SilentlyContinue } catch {}

