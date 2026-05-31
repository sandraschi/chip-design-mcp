# Troubleshooting

## Server starts but all EDA tools show "missing"

The server is designed to start without Yosys or OpenLane. Install tools on `PATH` (Windows: prefer WSL or Docker for OpenLane).

```powershell
just yosys-check
just openlane-check
just cocotb-check
chip_status   # via MCP or GET /api/v1/status
```

## OpenLane fails immediately

- Confirm Docker: `docker pull ghcr.io/the-openroad-project/openlane:latest`
- Or install native OpenLane and ensure `openlane` is on `PATH`
- `pr_status` reports `docker_available` vs native

## PDK / liberty not found

```powershell
pip install volare
volare enable --pdk sky130 0bbdd5
```

Verify `PDK_ROOT` is set in the same shell/session as the server. `chip_available_pdks` lists install state.

## syn_run returns 0 cells

Ensure `syn_read_verilog` ran first and `top_module` matches the RTL. For sky130 use **abc9** with a valid `.lib` from the PDK.

## verify_timing fails

Provide `top_module`. Server falls back to sky130 HD liberty under `PDK_ROOT` when available.

## DRC/LVS counts look wrong

Violation counts are **heuristics** parsed from tool stdout, not structured report databases. Treat as directional only.

## Backend health timeout (start.ps1)

Read `backend.log` in the repo root. Common causes: port 11022 in use, uv sync not run, import error.

```powershell
Get-NetTCPConnection -LocalPort 11022
just serve
```

## Webapp cannot reach API

Start backend first (`just serve` or `start.bat`). Vite proxies `/api` to 11022 — backend must be listening.

## Prefab cards missing in Claude

Set `CHIP_DESIGN_MCP_PREFAB_APPS=1` (default). Host must support MCP Apps / `prefab-ui`.

## chip_agentic returns "Context required"

Host must support MCP sampling (`ctx.sample`). Use `chip_status` and domain tools directly otherwise.

## iverilog / SystemVerilog

iverilog has limited SV support. Stick to Verilog-2001 style RTL or use Verilator externally.

## More help

- Webapp: **Help** page (per-domain tabs)
- [docs/tools/](tools/README.md) — tool-by-tool guides
