# Development

## Prerequisites

- Python 3.12+, **uv**
- Bun 1.1+ (webapp; npm fallback)
- Optional: Yosys, iverilog, Docker, volare PDK for integration testing

## Setup

```powershell
cd chip-design-mcp
just bootstrap    # uv sync --all-extras + bun install
just check        # ruff + pytest + tsc
```

## Run locally

| Command | Purpose |
|---------|---------|
| `just serve` | Backend :11022 |
| `just web` | Frontend :11023 |
| `just dev` | Uvicorn reload |
| `just stdio` | MCP stdio transport |
| `uv run python -m chip_design_mcp.server --mode stdio --agentic` | CodeMode discovery |

## Project layout

```
src/chip_design_mcp/
  server.py           # FastAPI + FastMCP gateway
  tools/              # register_*_tools per domain
  prompts_resources.py
  skills/chip-design-expert/
webapp/               # React 19 + Vite 6
docs/                 # User + tool documentation
tests/                # Smoke tests (no EDA required)
```

## Adding a tool

1. Implement in `src/chip_design_mcp/tools/<domain>.py` inside `register_*_tools`.
2. Re-export from `tools/__init__.py`.
3. Register in `server.py` and merge into `_all_tools` for REST.
4. Document in `docs/tools/<domain>.md` and `docs/TOOLS.md`.
5. Add smoke test if logic is pure Python.

Follow [docstrings_sota.md](docstrings_sota.md) and [mcp_registration.md](mcp_registration.md).

## Quality

```powershell
just lint
just fix
just test
just ty          # optional Astral ty
just precommit
```

## MCPB pack

```powershell
just mcpb-pack
```

## Fleet standards

Normative docs: `mcp-central-docs` — `SOTA_REQUIREMENTS.md`, `README_STRUCTURE.md`, `chip_design_cad_sota.md`.
