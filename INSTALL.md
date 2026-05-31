# Chip Design MCP — Installation

## Quick start (naked PC)

Only **git** and **winget** (Windows 10 1809+ / Windows 11) are assumed. Everything else is installed by the launcher.

```powershell
git clone https://github.com/sandraschi/chip-design-mcp.git
cd chip-design-mcp
.\start.bat
```

Launchers (repo root):

| File | Role |
|------|------|
| `start.bat` (repo root) | Delegates to `webapp\start.ps1` (double-click from clone root) |
| `webapp/start.bat` | Same launcher, run from `webapp/` |
| `webapp/start.ps1` | Canonical naked-PC script: winget bootstrap, `uv sync`, frontend install, health poll, browser |

Flags: `.\start.bat -BackendOnly` · `.\start.bat -NoBrowser` · `.\start.bat -Headless`

## Global vs local tools

| Tool | Where it lives | How you get it |
|------|----------------|----------------|
| Python | uv cache / `.venv` | `uv sync` (no separate Python install) |
| vite, tsc | `webapp/node_modules/.bin/` | `bun install` or `npm install` via `start.ps1` |
| ruff, pytest | `.venv/Scripts/` | `uv sync --all-extras` |
| Bun (optional) | PATH if already installed | Used when present; otherwise npm |
| yosys, OpenLane, … | OS / Docker / WSL | Optional — server runs without them |

## Manual setup (when `start.bat` fails)

1. Install via winget: `Astral.uv`, `OpenJS.NodeJS.LTS`, `Casey.Just`
2. `uv sync --all-extras` from repo root
3. `cd webapp` → `bun install` or `npm install`
4. Backend: `uv run python -m chip_design_mcp.server --mode dual --port 11022`
5. Frontend: `cd webapp` → `bun run dev` or `npm run dev` (port **11023**)

MCP client: `.\install-mcp.ps1 print` then `.\install-mcp.ps1 cursor` (or your client).

## Optional prerequisites

- Git (clone)
- Docker (OpenLane flows)
- EDA binaries: yosys, iverilog, gtkwave, magic, netgen (Linux/macOS/WSL)
- PDK: `pip install volare` then `volare enable --pdk sky130 0bbdd5`

## Tool Discovery

The server auto-discovers EDA tools from PATH at startup. Check with:

```powershell
just yosys-check
just openlane-check
just cocotb-check
```

## Without EDA Tools

The server runs without any EDA tools installed — discovery simply reports
"not found" and simulation/synthesis tools return appropriate error messages.
All non-EDA tools (depot, cells info, status) work regardless.
