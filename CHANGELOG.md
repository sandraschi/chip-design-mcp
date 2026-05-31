# Changelog

## [Unreleased]

### Fixed
- **start.ps1** / **justfile** `bootstrap`: `uv sync --all-extras` only (`--extra eda` cannot combine with `--all-extras` in current uv).
- **install-eda.ps1**: phased A/B/C progress with timestamps; WSL apt split into probe/update/install/verify (no `-qq`); `wsl -u root` to avoid sudo hang; volare/docker lines streamed.
- **volare sky130**: use full open_pdks hashes (`7519dfb…`, fallback `c6d73a35…`); short id `0bbdd5` was invalid ("not found remotely").
- **volare Windows**: `volare path` (not `which`); WinError 32 temp cleanup treated as success when PDK cached; first download skips SRAM macros to avoid file lock.

### Added
- **Automated EDA bootstrap** (`scripts/install-eda.ps1`, `start.ps1` step 3/6): winget Docker Desktop + OpenLane image pull; WSL Ubuntu + apt yosys/iverilog/magic/netgen; `bin/*.cmd` shims; volare sky130 (full open_pdks hash) + `PDK_ROOT`.
- Python optional extra **`eda`** (`volare`, `cocotb`) via `uv sync --extra eda`.
- **`docs/PRD.md`** product requirements document.
- Git repository + **https://github.com/sandraschi/chip-design-mcp** (private); fleet git safety standard in `mcp-central-docs`.
- `webapp/start.ps1` in `webapp/`; root `start.bat` delegates; MCD `just-starts/chip-design-mcp-start.bat`.
- Per-domain **`docs/tools/*.md`** + Help API slugs; **FABRICATION_AND_FABS.md** + fabrication Help tab.
- Fleet conformance: `manifest.json`, MCPB prompts, CI, pre-commit, `chip_agentic`, skills/prompts/resources, `/.well-known/mcp/manifest.json`, Prefab cards, `GET /api/capabilities`, Bun webapp.
- Webapp: Tools Hub, Apps Hub, LLM Chat, API Docs; backend `/api/v1/tools/detail`, `/api/v1/fleet`, `/api/v1/llm/*`.

### Changed
- **INSTALL.md** rewritten: automated 6-step flow is canonical; manual steps demoted to supplement.
- **README.md** points to INSTALL + PRD; documents GitHub and automated EDA.
- **docs/SETUP.md** leads with Windows automation; manual apt/brew moved to optional section.
- **docs/TROUBLESHOOTING.md**, **DEVELOPMENT.md**, **CONFIGURATION.md** aligned with `SKIP_EDA_INSTALL`, `just install-eda`, launcher guards.
- **llms.txt** / **llms-full.txt**, **docs/tools/**, **AGENTS.md**, **mcp-central-docs/projects/chip-design-mcp/README.md** updated for automated install and PRD.
- **docs/FOSS_EDA_ECOSYSTEM.md** and **docs/FOSS_RTL_SOURCES.md** — research-grade guides (2026 FOSS CAD, PDK macros, FPGA, KiCad boundary, neuromorphic RTL catalog); Help slugs `foss-eda-ecosystem`, `foss-rtl-sources`.
- **docs/DREAMING_IN_SILICON.md** — superyacht-magazine editorial (fantasy repo ethos, warnings, KiCad epilogue, doc map); README humor pass; Help slug `dreaming-in-silicon`.
- `just bootstrap` uses `--extra eda`; diagnostic recipes use `_probe_sync`.

### Fixed
- Source recovery after accidental zero-byte `src/**/*.py` wipe; `server.py` size check in launcher.
- Backend start uses direct `uv` process + `backend.log` / `backend.err.log` (no nested PowerShell redirect).
- `depot_list` crash; `pr_status.docker_available`; yosys stat parse; `verify_timing` sky130 liberty fallback.
- Unicode/em dash removed from `.ps1` per fleet `unicode_safety` checker.

## [0.1.0] — 2026-05-27

### Added
- Initial release with 28+ MCP tools across 6 domains
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
