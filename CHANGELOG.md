# Changelog

## [Unreleased]

### Added
- Fleet conformance pass: `manifest.json`, MCPB assets (system 3k+ / user 4k+ / 115 examples), CI, pre-commit, enriched `glama.json`, `chip_agentic`, skills/prompts/resources, `/.well-known/mcp/manifest.json`, `docs/mcp_registration.md`, `docs/docstrings_sota.md`, `install-mcp.ps1`, `--agentic` CodeMode, Bun webapp (`bun.lock`), MCD `projects/chip-design-mcp/README.md`.
- Removed 28 stray `*.bak` files; `.gitignore` excludes `*.bak` and `package-lock.json`.
- Prefab UI App tools (`tools/prefab.py`): `show_chip_status_card`, `show_pdks_card`, `show_pipeline_card`, `show_depot_card`, `show_cells_stats_card`, `show_cells_list_card`. Registration toggle `CHIP_DESIGN_MCP_PREFAB_APPS=0`.
- `GET /api/capabilities` introspection endpoint (tools, EDA availability, PDK, feature flags).
- `opensta` (`sta`) and `docker` added to EDA tool discovery.
- Naked-PC `start.ps1`: `Require-Command` winget bootstrap (uv/Node), vite guard, import smoke-test, health-timeout error.
- `glama.json`, `llms-full.txt`, proper `AGENTS.md`, `docs/EXTENSION_PLAN.md`.
- Webapp SOTA pages: Tools Hub (`/tools`), Apps Hub (`/apps`, live fleet scan), LLM Chat (`/chat`, Glom-On Ollama/LM Studio), API Docs (`/api-docs`, Swagger/ReDoc).
- Backend endpoints: `/api/v1/tools/detail`, `/api/v1/fleet`, `/api/v1/llm/status`, `/api/v1/llm/chat`. Vite proxy for `/docs`, `/openapi.json`, `/redoc`.
- Registered in fleet `FLEET_INDEX.md`.

### Fixed
- `depot_list` crashed on every call (`outputs_dir` → `output_dir`).
- `pr_status.docker_available` now reports correctly (docker in discovery).
- SETUP.md docker org typo (`the-open-road-project` → `the-openroad-project`).
- Tool-count drift across README/TOOLS/API; README quick-start (`just serve` is backend-only).
- Removed dead `justfile` recipes (`flow-test`, `build-native`); fixed `web` recipe (`npx --prefix` → `npm run dev`).
- `syn_run` stat parsing: write `stat -json` to a file via `tee` and aggregate the nested `modules` counts (old code read a non-existent top-level `num_cells`, returning 0 cells/wires every run).
- `verify_timing`: added `top_module` param and a sky130 Liberty fallback from `PDK_ROOT`; replaced hardcoded `link_design top` / Nangate default.

## [0.1.0] — 2026-05-27

### Added
- Initial release with 28 MCP tools across 6 domains
- Yosys synthesis: status, read_verilog, run, stats, show, export_netlist
- cocotb simulation: list_tests, run_testbench, read_waveform, check_coverage
- OpenLane place & route: status, create_design, configure, run_flow, read_reports, export_gds, export_lef
- Verification: drc (Magic), lvs (netgen), timing (OpenSTA), formal (Yosys)
- Standard cells: list, info, search, stats (SkyWater 130nm, GF180, IHP)
- Depot: init (counter/alu/fsm/empty templates), list, status
- System: chip_status, chip_pipeline_stages, chip_available_pdks
- React 19 + Vite 6 + Tailwind dashboard
- Fleet-standard start.ps1 + start.bat
- Playwright E2E tests
