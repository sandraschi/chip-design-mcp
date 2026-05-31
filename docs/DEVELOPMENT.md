# Development

Product context: [PRD.md](PRD.md). Install for operators: [INSTALL.md](../INSTALL.md).

## Prerequisites

- Python 3.12+, **uv**, **git**
- Bun 1.1+ (webapp; npm fallback)
- Full EDA: run `just install-eda` or complete Windows `start.bat` step 3

## Setup

```powershell
git clone https://github.com/sandraschi/chip-design-mcp.git
cd chip-design-mcp
just bootstrap          # uv sync --all-extras (includes eda + dev) + webapp install
just install-eda        # Docker + WSL EDA + volare (Windows)
just check              # ruff + biome + pytest + tsc + ty
```

MCP-only (no EDA download):

```powershell
$env:SKIP_EDA_INSTALL = '1'
just bootstrap
just serve
```

## Run locally

| Command | Purpose |
|---------|---------|
| `just serve` | Backend :11022 |
| `just web` | Frontend :11023 |
| `just dev` | Uvicorn reload |
| `just stdio` | MCP stdio transport |
| `just install-eda` | EDA bootstrap script only |
| `just yosys-check` | Probe yosys on PATH |
| `just docker-check` | Probe docker |
| `just pdk-check` | Print PDK_ROOT |

CodeMode: `uv run python -m chip_design_mcp.server --mode stdio --agentic`

## Project layout

```
src/chip_design_mcp/
  server.py              # FastAPI + FastMCP gateway
  tools/                 # register_*_tools per domain
  prompts_resources.py
  skills/chip-design-expert/
scripts/
  install-eda.ps1        # Windows EDA automation
webapp/                  # React 19 + Vite 6
docs/
  PRD.md                 # Product requirements
  tools/                 # Per-domain Help sources
tests/                   # Smoke tests (no EDA required)
```

## Adding a tool

1. Implement in `src/chip_design_mcp/tools/<domain>.py`
2. Register in `server.py` via `register_*_tools`
3. Document in `docs/tools/<domain>.md` and `docs/TOOLS.md`
4. Add slug to `_HELP_SLUGS` in `server.py` if new Help tab
5. Extend `tests/test_smoke.py` if REST surface changes

## Git workflow

Checkpoint commit before batch edits under `src/` (fleet [GIT_REPOSITORY_SAFETY](https://github.com/sandraschi/mcp-central-docs/blob/master/standards/GIT_REPOSITORY_SAFETY.md)).

## Quality

Python: **Ruff** + **ty** (`src/`, `tests/`). Webapp: **Biome** + **tsc** (`webapp/src/`). Fleet standard: [BIOME_STANDARDS](https://github.com/sandraschi/mcp-central-docs/blob/master/standards/BIOME_STANDARDS.md).

```powershell
just lint         # ruff + biome check + tsc
just fix          # ruff format + biome --write
just test
just e2e          # needs backend + frontend running
just precommit
```

Webapp only:

```powershell
cd webapp
bun run lint
bun run format
```

## Related

- [EXTENSION_PLAN.md](EXTENSION_PLAN.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
