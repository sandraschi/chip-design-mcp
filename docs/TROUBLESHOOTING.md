# Troubleshooting

Install reference: [INSTALL.md](../INSTALL.md). Configuration: [CONFIGURATION.md](CONFIGURATION.md).

## Help tabs show 404 or empty content

1. Backend must be on **11022** (`GET http://127.0.0.1:11022/api/v1/help/install` should return JSON with `markdown` and `content`).
2. Use the **webapp** at **11023** (`start.bat`), not the backend port — `/help` is a Vite/React route, not FastAPI.
3. If you see `404 Not Found` on every slug, set `CHIP_DESIGN_MCP_REPO_ROOT` to your clone root and restart the backend:

```powershell
$env:CHIP_DESIGN_MCP_REPO_ROOT = 'D:\Dev\repos\chip-design-mcp'
uv run python -m chip_design_mcp.server --mode dual --port 11022
```

4. Empty panels (no error) usually meant an older API field mismatch — update the repo and hard-refresh the browser.

## volare: WinError 32 on sky130_sram_macros.tar.zst

Downloads can reach 100% then fail with **WinError 32** while deleting a temp tarball. On Windows this is a known volare/tempfile race; the PDK may still be installed.

1. Check cache:

```powershell
uv run volare ls --pdk sky130
uv run volare path
Test-Path "$env:USERPROFILE\.volare\sky130A"
```

2. If `sky130A` exists, activate and set PDK:

```powershell
uv run volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095
$env:PDK_ROOT = (uv run volare path).Trim()
```

3. Re-run `scripts/install-eda.ps1` (updated script skips **SRAM macros** on first download and treats WinError 32 as success when `volare ls` shows the hash).

4. Or skip EDA install if PDK is already there:

```powershell
$env:PDK_ROOT = 'C:\Users\sandr\.volare'
$env:SKIP_EDA_INSTALL = '1'
.\start.bat
```

## volare: "Version … not found remotely"

Volare needs a **full 40-character open_pdks commit hash**, not a short prefix.

```powershell
uv run volare ls-remote --pdk sky130
uv run volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095
```

`install-eda.ps1` tries `7519dfb…` then `c6d73a35…` automatically. Re-run `.\start.bat` or step 3 only:

```powershell
powershell.exe -NoProfile -File scripts\install-eda.ps1 -RepoRoot (Get-Location) -UvExe (Get-Command uv).Source
```

## Step 3 appears stuck (WSL apt)

Step 3 runs `scripts/install-eda.ps1` in **phases A/B/C** with timestamps:

- Phase A: WSL probe → `apt-get update` → `apt-get install` (shows apt lines; first update can take **5–15 minutes**)
- Phase B: `docker pull` OpenLane image
- Phase C: `volare enable` sky130 download

If **no output for 10+ minutes** on the first WSL step:

1. Open **Ubuntu** from the Start menu and complete first-time user setup.
2. Re-run `.\start.bat`.

If apt fails with sudo/password issues, the script uses `wsl -u root` for apt; ensure WSL2 default distro is Ubuntu 22.04.

## EDA tools still missing after start.bat

Step 3 should run `scripts/install-eda.ps1`. If you used `SKIP_EDA_INSTALL=1`, re-run without it or:

```powershell
just install-eda
```

Check discovery:

```powershell
just yosys-check
just docker-check
just pdk-check
```

Or `chip_status` / webapp **Status**.

**WSL/Docker first install:** winget may require a **reboot** before `wsl` or `docker` work. Run `.\start.bat` again after reboot.

## OpenLane fails immediately

- Start **Docker Desktop** and wait until it is running.
- Confirm image: `docker pull ghcr.io/the-openroad-project/openlane:latest`
- `pr_status` / `chip_status` shows `docker: true`

## PDK / liberty not found

Step 3 should set `PDK_ROOT` via volare. Manual fix:

```powershell
uv run volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095
$env:PDK_ROOT = (uv run volare path).Trim()
```

Restart backend after setting `PDK_ROOT`. `chip_available_pdks` lists install state.

## server.py truncated / Import OK but health hang

Launcher aborts if `src/chip_design_mcp/server.py` is under 1 KB. Restore from git:

```powershell
git checkout -- src/chip_design_mcp/server.py
```

If no history: re-clone https://github.com/sandraschi/chip-design-mcp

## syn_run returns 0 cells

Run `syn_read_verilog` first; `top_module` must match RTL. For sky130 use **abc9** with a valid `.lib` from `PDK_ROOT`.

## verify_timing fails

Provide `top_module`. Server falls back to sky130 HD liberty under `PDK_ROOT` when available.

## DRC/LVS counts look wrong

Counts are **heuristics** from tool stdout, not signoff databases. Treat as directional only.

## Backend health timeout (start.ps1)

Read `backend.log` and `backend.err.log` in the repo root.

```powershell
Get-NetTCPConnection -LocalPort 11022
uv run python -m chip_design_mcp.server --mode dual --port 11022
```

Common causes: port in use, `uv sync` not run, truncated sources.

## Webapp cannot reach API

Start full stack with `.\start.bat` or `just serve` then `just web`. Vite proxies `/api` to **11022**.

## Prefab cards missing in Claude

`CHIP_DESIGN_MCP_PREFAB_APPS=1` (default). Host must support MCP Apps / `prefab-ui`.

## chip_agentic returns "Context required"

Host must support MCP sampling. Use `chip_status` and domain tools directly otherwise.

## Unicode / start.ps1 parse errors

Fleet forbids em dash in `.ps1`. Run:

```powershell
powershell.exe -NoProfile -File D:\Dev\repos\mcp-central-docs\scripts\check-unicode-safe.ps1 -RepoPath .
```
