# Chip Design MCP

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.12+](https://img.shields.io/badge/Python-3.12+-blue.svg)](pyproject.toml)
[![Fleet SOTA](https://img.shields.io/badge/Fleet-SOTA%202026-green.svg)](https://github.com/sandraschi/mcp-central-docs/tree/master/standards/SOTA_REQUIREMENTS.md)
[![Read the magazine](https://img.shields.io/badge/Read-Dreaming%20in%20Silicon-purple.svg)](docs/DREAMING_IN_SILICON.md)

**A superyacht magazine for custom silicon** — browse the open RTL→GDSII world, run real tools if you insist, and maybe one day solder a package onto a **KiCad** board you also designed. The fascinating bit: much of this is **actually possible** without a nine-figure NRE line item. It is still hard, hot, slow, and easy to get wrong.

**Repository:** https://github.com/sandraschi/chip-design-mcp

---

## Do not do this at home

Ok, you have been warned.

- **Docker + PDK + OpenLane** will consume hours, gigabytes, and fan noise.
- This server **orchestrates** Yosys, sim, and OpenLane; it does **not** replace foundry signoff or common sense.
- DRC/LVS counts from MCP tools are **heuristics** — not “ship it to the fab” authority.
- Checkpoint **git** before letting an agent touch `src/`. Seriously.

If you only want to **read and dream**, start with **[docs/DREAMING_IN_SILICON.md](docs/DREAMING_IN_SILICON.md)** and **[docs/FOSS_RTL_SOURCES.md](docs/FOSS_RTL_SOURCES.md)** — no `start.bat` required. That is a valid subscription.

---

## What this is

| Layer | Reality |
|-------|---------|
| **Fantasy** | “I could design my own chip and put it on a board.” |
| **Magazine** | Docs + webapp Help that explain *how people actually do that* in 2026 with FOSS. |
| **Mechanics** | FastMCP 3.2 server that runs **real** subprocesses and returns **honest** JSON when tools are missing. |
| **Epilogue** | Your PCB is **[KiCad](https://www.kicad.org/)** + fleet **kicad-mcp** — wafers and Gerbers are different religions. |

Open-source **RTL-to-GDSII** orchestration for AI agents and humans: Yosys, cocotb, OpenLane (Docker), Magic, netgen, OpenSTA, sky130/gf180 PDKs via volare.

---

## Features (for when you stop dreaming and start clicking)

- 32+ MCP tools across six EDA domains plus system and Prefab cards
- **Automated install** on Windows: Docker/OpenLane, WSL yosys/iverilog, volare sky130 (`start.bat` step 3)
- Honest subprocess orchestration (no fake EDA when binaries are missing)
- React dashboard with per-domain **Help** tabs — full doc stack including FOSS catalogs
- Dual transport: stdio + HTTP/SSE on **11022**; webapp **11023**

---

## Quick start (Windows, naked PC)

Only **git** and **winget** required. Everything else is installed by the launcher. *You were warned.*

```powershell
git clone https://github.com/sandraschi/chip-design-mcp.git
cd chip-design-mcp
.\start.bat
```

| Step | What happens |
|------|----------------|
| 1 | winget: uv, just, Node, npm |
| 2 | `uv sync --extra eda` (volare, cocotb) |
| 3 | Docker + OpenLane image, WSL EDA packages, sky130 PDK |
| 4–6 | Webapp + backend + browser |

First run can take a long time (Docker + PDK). Reboot once if winget installs WSL or Docker, then run `.\start.bat` again.

MCP client: `.\install-mcp.ps1 print` then `.\install-mcp.ps1 cursor`.

Monorepo shortcut: `mcp-central-docs/just-starts/chip-design-mcp-start.bat`.

Open http://localhost:11023 — **Help** mirrors the full magazine (install, pipeline, FOSS RTL, fabrication, …).

---

## Story prompts (for agents and dreamers)

- "Walk me through the RTL→GDSII pipeline like a magazine article." → `chip_pipeline_stages` + [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- "What open spiking-neural-net RTL exists for sky130?" → [FOSS_RTL_SOURCES.md](docs/FOSS_RTL_SOURCES.md) (neuraedge, OpenSpike, Tiny Tapeout)
- "Run `chip_status` and tell me what EDA tools are missing."
- "Use `depot_init` with the counter template, simulate, then synthesize with Yosys."
- "How would I put the chip on a PCB?" → KiCad / kicad-mcp + [DREAMING_IN_SILICON.md](docs/DREAMING_IN_SILICON.md) §4

---

## Documentation (the full issue)

| Doc | Contents |
|-----|----------|
| **[docs/DREAMING_IN_SILICON.md](docs/DREAMING_IN_SILICON.md)** | **Start here** — superyacht magazine ethos, warnings, reading order |
| **[INSTALL.md](INSTALL.md)** | Operator manual — 6-step launcher, skip flags |
| [docs/FOSS_EDA_ECOSYSTEM.md](docs/FOSS_EDA_ECOSYSTEM.md) | FOSS CAD to **create** RTL (Chisel, LiteX, FPGA, PDK macros, KiCad vs ASIC) |
| [docs/FOSS_RTL_SOURCES.md](docs/FOSS_RTL_SOURCES.md) | FOSS RTL catalog — SNN, CPUs, tapeouts, benchmarks |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Server + complete RTL→GDSII pipeline |
| [docs/FABRICATION_AND_FABS.md](docs/FABRICATION_AND_FABS.md) | Tiles, shuttles, fabs, money (the fantasy gets real) |
| [docs/PRD.md](docs/PRD.md) | Product requirements (builders) |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Environment variables |
| [docs/TOOLS.md](docs/TOOLS.md) | MCP tool catalog |
| [docs/tools/](docs/tools/README.md) | Per-domain guides |
| [docs/PDK_GUIDE.md](docs/PDK_GUIDE.md) | PDKs and volare |
| [docs/SETUP.md](docs/SETUP.md) | Manual Linux/macOS supplement |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Contributing |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | When Docker lies |
| [docs/EXTENSION_PLAN.md](docs/EXTENSION_PLAN.md) | Roadmap |
| [docs/MINI_FAB.md](docs/MINI_FAB.md) | Backyard fab (extra fantasy) |

Webapp: `GET /api/v1/help/{slug}` — same markdown as Help tabs.

---

## Requirements

| Layer | Windows (`start.bat`) | Dev-only |
|-------|------------------------|----------|
| Runtime | winget → uv, just, Node, npm | Same |
| Python | `uv sync --extra eda` | `SKIP_EDA_INSTALL=1` optional |
| EDA | Automated step 3 (or `just install-eda`) | Manual SETUP on Linux/macOS |
| Git | Clone from GitHub | Local `git` for contributions |
| Patience | Recommended | Mandatory |

---

## License

MIT — see [LICENSE](LICENSE).  
No warranty express or implied; especially not “your tile will yield.”
