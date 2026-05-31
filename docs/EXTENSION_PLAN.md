# Chip Design MCP — Extension Plan

Status as of 2026-05-27 release (v0.1.0) + 2026-05-30 alignment pass.
Timelines are AI-assisted-with-review (days, not weeks). Effort is calendar
days for one operator driving an agent, including test + review.

## Where it stands

v0.1.0 is a real RTL-to-GDSII orchestrator: 31 tools wrapping yosys, cocotb/
iverilog, OpenLane, magic, netgen, OpenSTA over honest subprocess calls, with a
React dashboard and accurate domain docs. It is genuinely usable today for the
synth → sim → flow → export loop, given the EDA toolchain + a PDK installed.

It is "far out" in two senses: (1) the domain is unusual for the fleet, and (2)
it is not yet at fleet parity (Prefab, capabilities endpoint, naked-PC install,
webapp SOTA pages) and several capabilities are shallow (waveform parsing, GDS
has no visual, violation counts are heuristic). This plan closes both gaps.

## Phase 0 — Correctness & honesty (≈1 day) — partially done

| Item | State | Effort |
|------|-------|--------|
| `depot_list` `NameError` (`outputs_dir`→`output_dir`) | **fixed 05-30** | — |
| SETUP.md docker org typo (`the-open-road-project`) | **fixed 05-30** | — |
| Tool-count drift (28/31) in TOOLS.md, API.md, README | **fixed 05-30** | — |
| `pr_status.docker_available` always False — add `docker` to `_EdaDefaults` discovery | **fixed 05-30** | — |
| Robust yosys `stat -json` parse (write to file, not `stdout.rfind("{")`) | **fixed 05-30** (tee to file + correct nested-`modules` aggregation; old code returned 0 cells always) | — |
| Remove/implement dead `justfile` recipes (`flow-test`, `build-native`) | **removed 05-30** | — |
| `verify_timing` — take real top module + sky130 liberty, drop Nangate default | **fixed 05-30** (`top_module` param + PDK_ROOT sky130 liberty fallback) | — |

## Phase 1 — Fleet parity (≈3–4 days) — partially done

| Item | State | Effort |
|------|-------|--------|
| `glama.json` | **added 05-30** | — |
| `llms-full.txt` (required pair with `llms.txt`) | **added 05-30** | — |
| `AGENTS.md` (proper agent context, not stub) | **added 05-30** | — |
| Register in `FLEET_INDEX.md` (ports already reserved in WEBAPP_PORTS.md) | open — needs your OK | 0.25 d |
| **Prefab UI** for list/status/stats tools — the fleet mandate. 6 `show_*_card` App tools in `tools/prefab.py` wrapping `chip_status`, `pr_status`(via status), depot/cells stats + lists, pipeline, pdks. | **added 05-30** | — |
| `GET /api/capabilities` introspection endpoint (AGENT_PROTOCOLS mandate) | **added 05-30** | — |
| Naked-PC `start.ps1` — `Require-Command` winget bootstrap, vite guard, import smoke-test, health-timeout error (reference: `aiwatcher-mcp`) | **added 05-30** | — |
| `mcpb pack` validation (`mcpb validate`, `mcpb pack`) — confirm packaging | open | 0.5 d |

## Phase 2 — Webapp to SOTA (≈3–4 days) — mostly done

| Item | State |
|------|-------|
| Theme pass → `#09090b` background, Zinc palette, Amber/Blue accents, JetBrains Mono for logs | open (kept existing slate/emerald theme for cohesion) |
| **API Docs page** (§IX): `/api-docs` route + vite proxy for `/docs`,`/openapi.json`,`/redoc`, Swagger/ReDoc toggle, open-in-browser | **added 05-30** (dark-CSS iframe injection deferred — white panel + browser fallback) |
| **Tools Hub** — dynamic from `/api/v1/tools/detail` + `/api/capabilities`, grouped by domain, docstring drill-down, capability badges | **added 05-30** |
| **Apps Hub** — live fleet discovery (`/api/v1/fleet` bounded port scan 10700–11100) | **added 05-30** |
| **LLM Chat** — Glom-On auto-detect Ollama 11434 / LM Studio 1234 via backend proxy (`/api/v1/llm/status`, `/api/v1/llm/chat`), GPU-opportunity fallback | **added 05-30** |
| Global logger modal + help modal + toasts | open |

## Phase 3 — Functional depth (≈5–7 days)

Make the existing tools authoritative instead of approximate, and add the
visual outputs that make a chip-design tool actually pleasant to use.

| Item | Why | Effort |
|------|-----|--------|
| Real VCD parsing (`vcdvcd`) + signal transitions, not header-only; waveform → SVG/Prefab render | `sim_read_waveform` currently only lists signal names | 1.5 d |
| **GDS → PNG render** via KLayout headless (`klayout -z -rd`) → Prefab image card | No visual verification today; biggest UX win | 1.5 d |
| RTL lint tool — `verilator --lint-only` / Verible, surfaced as `syn_lint` before synthesis | Catch errors pre-flow | 1 d |
| Parse OpenLane signoff metrics into structured JSON (area µm², util, WNS/TNS, DRC count) instead of `f.read(2000)` text blobs | Reports are currently raw text slices | 1 d |
| Multi-corner STA (tt/ff/ss) + structured WNS/TNS per corner | Single-corner today | 1 d |
| SymbiYosys (`sby`) formal property checking, beyond equivalence | `verify_formal` only does equiv | 1.5 d |

## Phase 4 — Reach / ecosystem (≈4–6 days)

| Item | Why | Effort |
|------|-----|--------|
| **TinyTapeout submission packer** — `depot_tapeout_pack`: generate `info.yaml`, `config.json`, the TT project layout + GitHub Actions for a design, ready to fork-and-submit | Closes the loop to real silicon (PRODUCTION_PATHS) | 2 d |
| ChipFoundry chipIgnite template scaffold (user_project_wrapper) | Startup path | 1.5 d |
| Local-LLM RTL scaffolding (`depot_init` template = "describe it") — Ollama on the 4090 turns a prompt into starter Verilog + cocotb | Ties to WEBAPP §VI local intelligence; cheap on local GPU | 1.5 d |
| A2A registration (per A2A_FLEET_ROLLOUT order) once parity is reached | Fleet interop | 1 d |
| FastMCP skill (`SKILL.md` resource) so IDEs auto-learn the flow; webapp Skill page | Discoverability | 1 d |

## Suggested order

P0 + P1 first (parity + honesty — ~1 week) so it's a clean fleet citizen, then
P2 (webapp) and P3 (depth) in parallel as appetite allows, then P4 (the
TinyTapeout packer is the headline feature — it turns this from "interesting
orchestrator" into "I taped out a chip from my desk").

## One open decision

`server.py` uses `FastMCP.from_fastapi(app)` **and** manual `@mcp.tool`
registration on the same instance. Worth a deliberate check that this doesn't
double-expose the REST routes as MCP tools (api_control_tool etc.) alongside the
real domain tools. If it does, either drop `from_fastapi` (keep MCP and REST as
separate hand-written surfaces, which is the rest of the fleet's pattern) or
scope `from_fastapi` to exclude the dispatcher routes. ~0.5 d to verify + decide.
