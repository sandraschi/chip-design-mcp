# Chip Design MCP

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.12+](https://img.shields.io/badge/Python-3.12+-blue.svg)](pyproject.toml)
[![Fleet SOTA](https://img.shields.io/badge/Fleet-SOTA%202026-green.svg)](https://github.com/sandraschi/mcp-central-docs/tree/master/standards/SOTA_REQUIREMENTS.md)

Open-source **RTL-to-GDSII** orchestration for AI agents — Yosys, cocotb, OpenLane, Magic, and sky130/gf180 PDKs via **FastMCP 3.2**.

## Features

- 37+ MCP tools across six EDA domains plus system and Prefab cards
- Honest subprocess orchestration (no fake EDA when binaries are missing)
- React dashboard with **per-domain Help tabs** and central **Help** page
- Dual transport: stdio + HTTP/SSE on port **11022**; webapp **11023**

## Quick install

Launchers: root **`start.bat`** delegates to **`webapp/start.ps1`** (ports **11022** / **11023**). MCD shortcut: `mcp-central-docs/just-starts/chip-design-mcp-start.bat`.

```powershell
just bootstrap
.\start.bat
just install-mcp print
```

Open http://localhost:11023 → **Help** for install guides and each tool domain.

## What you can do

- "Run `chip_status` and tell me what EDA tools are missing."
- "Use `depot_init` with the counter template, simulate, then synthesize with Yosys."
- "Create an OpenLane design and run the RTL-to-GDS flow when Docker is available."

## Documentation

| Doc | Contents |
|-----|----------|
| [INSTALL.md](INSTALL.md) | Naked-PC install, prerequisites, MCP clients |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Environment variables, work dirs |
| [docs/TOOLS.md](docs/TOOLS.md) | Full MCP tool catalog |
| [docs/tools/](docs/tools/README.md) | **Per-domain guides** (synthesis, sim, P&R, …) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Server design |
| [docs/FABRICATION_AND_FABS.md](docs/FABRICATION_AND_FABS.md) | **Tiles, shuttles, fabs** — free vs commercial, complexity & density |
| [docs/PDK_GUIDE.md](docs/PDK_GUIDE.md) | PDKs and volare |
| [docs/PRODUCTION_PATHS.md](docs/PRODUCTION_PATHS.md) | Short comparison table |
| [docs/MINI_FAB.md](docs/MINI_FAB.md) | Mini fab vs MPW vs desktop myths |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Contributing, `just` recipes |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common errors |

Webapp loads the same markdown via `GET /api/v1/help/{slug}`.

## Requirements

- Windows 10+ or Linux/WSL for EDA binaries
- Python 3.12+, uv, Bun (or npm), Node.js for Vite
- Optional: Docker (OpenLane), volare (PDK)

## License

MIT — see [LICENSE](LICENSE).
