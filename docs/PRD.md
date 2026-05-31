# Product Requirements Document — Chip Design MCP

**Version:** 0.1.0 (in development)  
**Last updated:** 2026-05-31  
**Repo:** https://github.com/sandraschi/chip-design-mcp  
**Fleet standard:** [chip_design_cad_sota.md](https://github.com/sandraschi/mcp-central-docs/blob/master/standards/rules/chip_design_cad_sota.md)

---

## Positioning (read first)

**Editorial framing:** [DREAMING_IN_SILICON.md](DREAMING_IN_SILICON.md) — this repo is a **superyacht magazine** for silicon: educate and inspire about what is **possible** with FOSS (sky130 shuttles, open EDA, KiCad boards for packages), with humor and explicit **“do not do this at home”** warnings. The MCP server is **real**; tapeout success is **not guaranteed**.

**Product truth:** Orchestration + documentation + webapp Help — not a foundry product.

## Overview

Chip Design MCP is a **FastMCP 3.2** server plus React dashboard that lets AI agents and humans run an **honest open-source RTL-to-GDSII flow** (Yosys, cocotb/iverilog, OpenLane, Magic, netgen, OpenSTA) without reimplementing EDA in Python. It targets fleet operators, hobbyists, and students moving from Verilog toward tapeout-aware workflows — and **dreamers** who may never run OpenLane but need accurate maps of the ecosystem.

## Problem statement

- EDA toolchains are fragmented, OS-specific, and hard to install; agents hallucinate results if not given real subprocess boundaries.
- Existing MCP servers rarely cover **ASIC** end-to-end with truthful failure modes and PDK-aware helpers.
- Naked-PC users need **one double-click** to get Python stack, webapp, Docker/OpenLane, WSL binaries, and sky130 PDK — not a wiki of manual `apt` steps.

## Target audience

| Persona | Need |
|---------|------|
| Agent / IDE user | Callable tools with clear JSON contracts, Help docs, Prefab status cards |
| Naked-PC Windows user | `start.bat` installs runtime + EDA automatically |
| Developer | uv/just, smoke tests without EDA, extension plan |
| Tapeout-curious maker | Fabrication guide, depot templates, OpenLane when Docker works |
| Magazine reader | DREAMING_IN_SILICON, FOSS_RTL_SOURCES, FABRICATION — no install required |
| PCB designer | KiCad/kicad-mcp for board; this repo for wafer story only |

## Success metrics

| Metric | Target |
|--------|--------|
| Cold start (Windows, winget) | `start.bat` reaches healthy backend + webapp without manual EDA steps |
| Honesty | Zero tools return fake success when binary missing |
| Discovery | `chip_status` reflects PATH + Docker + PDK within 5s of start |
| Docs parity | Every domain tool has `docs/tools/*.md` + Help slug |
| Recovery | Git history on every release; no mass edit without checkpoint |

## Functional requirements

### Installation and bootstrap

| ID | Requirement | Status |
|----|-------------|--------|
| REQ-INST-01 | `start.bat` winget-installs uv, just, Node, npm | Done |
| REQ-INST-02 | `uv sync --extra eda` installs volare + cocotb | Done |
| REQ-INST-03 | `scripts/install-eda.ps1`: Docker Desktop + OpenLane image pull | Done |
| REQ-INST-04 | WSL Ubuntu + apt yosys/iverilog/magic/netgen + `bin/*.cmd` shims | Done |
| REQ-INST-05 | volare enable sky130 `7519dfb04400f224f140749cda44ee7de6f5e095` + user `PDK_ROOT` | Done |
| REQ-INST-06 | `SKIP_EDA_INSTALL=1` for MCP-only dev | Done |
| REQ-INST-07 | `server.py` size guard in launcher (no hollow import) | Done |
| REQ-INST-08 | GitHub repo + initial commit mandatory for fleet work | Done |

### MCP and REST

| ID | Requirement | Status |
|----|-------------|--------|
| REQ-MCP-01 | 32+ tools across synthesis, sim, P&R, verification, cells, depot, system | Done |
| REQ-MCP-02 | Dual transport stdio + HTTP/SSE on :11022 | Done |
| REQ-MCP-03 | `GET /api/v1/help/{slug}` serves fleet doc stack | Done |
| REQ-MCP-04 | `chip_agentic` sampling (optional host) | Done |
| REQ-MCP-05 | Prefab cards for list/status surfaces | Done |
| REQ-MCP-06 | `GET /api/capabilities`, `/.well-known/mcp/manifest.json` | Done |

### EDA execution

| ID | Requirement | Status |
|----|-------------|--------|
| REQ-EDA-01 | Subprocess via `_run_eda`; OpenLane via Docker image | Done |
| REQ-EDA-02 | Truthful errors when tool not on PATH | Done |
| REQ-EDA-03 | DRC/LVS documented as stdout heuristics, not signoff | Done |
| REQ-EDA-04 | Real VCD parse + GDS preview | Planned (EXTENSION_PLAN Phase 3) |
| REQ-EDA-05 | Tiny Tapeout submission packer | Planned (Phase 4) |

### Webapp

| ID | Requirement | Status |
|----|-------------|--------|
| REQ-WEB-01 | Dashboard, domain pages, Help tabs | Done |
| REQ-WEB-02 | Tools Hub, Apps Hub, API docs, LLM chat | Done |
| REQ-WEB-03 | Vite proxy to backend :11022 | Done |

## Non-functional requirements

| Area | Requirement |
|------|-------------|
| Performance | Tool calls bounded by subprocess timeouts; OpenLane up to 3600s |
| Security | No fake success; external stdout treated as untrusted in agent prompts |
| Portability | Windows naked-PC first; Linux/macOS via manual SETUP or future `install-eda.sh` |
| Maintainability | Fleet docs in `mcp-central-docs`; per-repo INSTALL + PRD + CHANGELOG |

## Technical architecture

See [ARCHITECTURE.md](ARCHITECTURE.md). Summary:

- **Backend:** `server.py` + `tools/*.py` register on FastMCP
- **Frontend:** React 19, Vite 6, ports 11023 → 11022
- **Work dir:** `%TEMP%\chip_design_mcp_work`
- **EDA on Windows:** WSL shims in `bin/` + Docker for OpenLane

## Out of scope (v0.1)

- Commercial PDK NDA flows inside the server
- Replacing Magic/OpenROAD with Python implementations
- Guaranteed DRC-clean tapeout from MCP heuristics alone

## Implementation plan (summary)

Detailed roadmap: [EXTENSION_PLAN.md](EXTENSION_PLAN.md).

| Phase | Focus |
|-------|--------|
| 0 | Correctness / honesty | Mostly done |
| 1 | Fleet parity + naked-PC + **automated EDA** | Done |
| 2 | Webapp SOTA pages | Mostly done |
| 3 | Deeper tool output (VCD, GDS PNG, signoff JSON) | Open |
| 4 | Tapeout packs, A2A, local RTL gen | Open |

## Related documents

| Doc | Role |
|-----|------|
| [DREAMING_IN_SILICON.md](DREAMING_IN_SILICON.md) | Editorial — fantasy repo ethos, warnings, reading order |
| [INSTALL.md](../INSTALL.md) | Operator install (canonical) |
| [README.md](../README.md) | Short entry + links |
| [CHANGELOG.md](../CHANGELOG.md) | Release history |
| [TOOLS.md](TOOLS.md) | Tool catalog |
| [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md) | FOSS tools to create RTL and implement (2026) |
| [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md) | Curated external RTL IP |
