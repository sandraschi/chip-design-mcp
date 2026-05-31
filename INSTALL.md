# Chip Design MCP — Installation

## Quick start (naked PC, fully automated)

Only **git** and **winget** are assumed. `start.bat` installs everything else:

| Step | What gets installed |
|------|---------------------|
| 1 | **uv**, **just**, **Node.js**, **npm** (winget) |
| 2 | Python deps + **volare**, **cocotb** (`uv sync --extra eda`) |
| 3 | **EDA**: Docker Desktop + OpenLane image, **WSL Ubuntu** + `apt` yosys/iverilog/magic/netgen, **sky130 PDK** via volare |
| 4 | Frontend (bun or npm) |
| 5–6 | Backend :11022 + webapp :11023 |

```powershell
git clone https://github.com/sandraschi/chip-design-mcp.git
cd chip-design-mcp
.\start.bat
```

First run may take a long time (Docker image ~3 GB, PDK ~500 MB, WSL apt). **Reboot once** if winget installs WSL or Docker for the first time, then run `.\start.bat` again.

### Skip flags

| Env / flag | Effect |
|------------|--------|
| `SKIP_SYNC=1` | Skip `uv sync` |
| `SKIP_EDA_INSTALL=1` | Skip step 3 (MCP + webapp only; tools report "not found") |
| `-BackendOnly` | No frontend |
| `-NoBrowser` | Do not open browser |

Manual EDA only: `just install-eda` or `.\scripts\install-eda.ps1 -RepoRoot . -UvExe (Get-Command uv).Source`

## Launchers

| File | Role |
|------|------|
| `start.bat` (repo root) | Delegates to `webapp\start.ps1` |
| `webapp/start.ps1` | Canonical naked-PC script |

## How tools are invoked (not fake)

At startup the server **probes PATH** for yosys, iverilog, docker, magic, netgen, opensta, volare. Tools call real subprocesses via `_run_eda()` or Docker OpenLane (`ghcr.io/the-openroad-project/openlane:latest`). Missing binaries return **`success: false`** with an install hint — not simulated results.

On Windows, step 3 adds **`bin/*.cmd` shims** that forward to WSL for native EDA CLIs so `where yosys` works from PowerShell.

## MCP client

```powershell
.\install-mcp.ps1 print
.\install-mcp.ps1 cursor
```

## Diagnostics

```powershell
just yosys-check
just docker-check
just pdk-check
```

Or `chip_status` / webapp **Status** page after start.

## Without full EDA (dev / docs only)

Set `SKIP_EDA_INSTALL=1`. Server and depot/help tools still work; synthesis/sim/P&R return truthful "not found" errors.
