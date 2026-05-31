# chip-design-mcp — Agent Context

FastMCP 3.2 server orchestrating the open-source RTL-to-GDSII ASIC flow
(yosys / cocotb+iverilog / OpenLane / magic / netgen / OpenSTA). It implements
**no EDA algorithms** — it shells out to industry-standard open-source tools as
subprocesses and exposes them as MCP tools + a REST surface.

- **Backend:** FastAPI + FastMCP, port **11022** (`/mcp`, `/sse`, `/api/v1/*`)
- **Frontend:** Vite/React dashboard, port **11023**
- **Work dir:** `%TEMP%\chip_design_mcp_work` (override: `CHIP_DESIGN_MCP_WORK_DIR`)
- **Tools:** 28 domain (synthesis/simulation/place_route/verification/standard_cells/depot) + 3 system + **chip_agentic** + 6 Prefab
- **Fleet:** `manifest.json`, MCPB prompts (`assets/prompts/`), `llms.txt`/`llms-full.txt`, `glama.json`, `justfile`, `uv.lock`, `bun.lock`, `.pre-commit-config.yaml`, CI, `install-mcp.ps1`, `--agentic` CodeMode
- **MCD:** [`mcp-central-docs/projects/chip-design-mcp/README.md`](../mcp-central-docs/projects/chip-design-mcp/README.md), `skill://chip-design-expert`

## Run / test

```powershell
just bootstrap          # uv sync --all-extras + npm install
just serve              # backend on 11022
just web                # webapp on 11023
.\start.bat             # both + browser
uv run pytest tests/ -q # smoke + unit tests (no EDA tools required)
```

`uv run python` always — never naked `python` (PATH resolution on Windows).

## Architecture notes for agents

- Each domain module exposes `register_*_tools(mcp, state, run_eda, ...)` and
  returns a `{name: fn}` dict. `server.py` calls all six, merges into
  `_all_tools`, and the REST dispatcher `POST /api/v1/control/{tool}` invokes
  by name. Tool functions are plain async callables — directly unit-testable.
- EDA execution goes through `_run_eda` (subprocess + timeout) or `_run_openlane`
  (Docker `ghcr.io/the-openroad-project/openlane:latest`, native fallback).
- Tool discovery (`_discover_tools`) probes PATH at startup via `where`; results
  land in `_state["tools"]`. Servers start fine with **no** EDA tools present —
  each tool returns a truthful "not found / install X" error.

## Known issues / gotchas (read before editing)

- DRC/LVS/formal violation counts are string-match heuristics over tool stdout,
  not parsed report structures — approximate, not authoritative.
- API Docs page shows Swagger in a plain (white) iframe panel; dark-CSS injection
  is deferred (the "Open in browser" link is the fallback). Theme is still
  slate/emerald, not the Zinc/Amber tokens.
- Prefab cards are read-only (no interactive forms yet).

### Resolved in the 2026-05-31 fleet conformance pass
- MCPB **manifest.json**, **assets/icon.png**, **assets/prompts/** (system/user/examples.json)
- **SkillsDirectoryProvider** (`skills/chip-design-expert/SKILL.md`), **prompts/resources**, **chip_agentic** sampling tool
- **GET /.well-known/mcp/manifest.json**, CI workflow, pre-commit + `just ty` / `just mcpb-pack`
- Enriched **glama.json**; repo **docs/mcp_registration.md** + **docs/docstrings_sota.md** (pointers to MCD)

### Resolved in the 2026-05-30 alignment pass
- Prefab UI implemented — 6 `show_*_card` App tools (`tools/prefab.py`); toggle `CHIP_DESIGN_MCP_PREFAB_APPS=0`.
- `pr_status.docker_available` truthful; `docker` + `opensta` (`sta`) added to discovery.
- `GET /api/capabilities` + webapp-support endpoints (`/api/v1/tools/detail`, `/api/v1/fleet`, `/api/v1/llm/status`, `/api/v1/llm/chat`).
- Webapp SOTA pages added: Tools Hub, Apps Hub (live fleet scan), LLM Chat (Glom-On Ollama/LM Studio), API Docs (Swagger/ReDoc).
- `syn_run` stat parse fixed (was returning 0 cells always); `verify_timing` takes a real top module + sky130 Liberty fallback.
- `start.ps1` naked-PC compliant; `depot_list` crash fixed; dead `justfile` recipes removed.
- Registered in fleet `FLEET_INDEX.md` (ports 11022/11023).

## Tool routing (fleet rule — applies here too)

- **git / GitHub:** always `gitops` (`git_core`, `github_ops`). Never fileops/winops for git.
- **Windows file I/O:** `fileops:file_ops` / `dir_ops`. Never `bash_tool` for `C:\`/`D:\`.
- This repo's GitHub: `github.com/sandraschi/chip-design-mcp` (user `sandraschi`).

## Key files

| Path | Purpose |
|------|---------|
| `src/chip_design_mcp/server.py` | FastMCP+FastAPI gateway, discovery, REST, system tools |
| `src/chip_design_mcp/tools/*.py` | Six domain modules (register_* closures) |
| `docs/` | ARCHITECTURE, TOOLS, CONFIGURATION, DEVELOPMENT, TROUBLESHOOTING, PDK_GUIDE, … |
| `docs/tools/*.md` | Per-domain tool guides (served at `/api/v1/help/{slug}`) |
| `webapp/src/pages/HelpPage.tsx` | Central Help tabs; domain pages use Overview + Help |
| `webapp/` | React 19 + Vite 6 + Tailwind dashboard |
| `webapp/start.ps1` + `start.bat` | Canonical naked-PC launcher (11022/11023); root `start.bat` delegates |
| Git | https://github.com/sandraschi/chip-design-mcp — checkpoint before batch edits ([GIT_REPOSITORY_SAFETY.md](../mcp-central-docs/standards/GIT_REPOSITORY_SAFETY.md)) |
| `justfile` | Lifecycle recipes |
| `llms.txt` / `llms-full.txt` | LLM context (short / full) |
