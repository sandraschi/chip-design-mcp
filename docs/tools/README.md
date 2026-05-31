# Tool domain documentation

Each ASIC flow domain has a dedicated guide for agents and humans.

| Domain | Guide | MCP prefix |
|--------|-------|------------|
| Synthesis | [synthesis.md](synthesis.md) | `syn_*` |
| Simulation | [simulation.md](simulation.md) | `sim_*` |
| Place & route | [place_route.md](place_route.md) | `pr_*` |
| Verification | [verification.md](verification.md) | `verify_*` |
| Standard cells | [standard_cells.md](standard_cells.md) | `cells_*` |
| Depot | [depot.md](depot.md) | `depot_*` |
| System | [system.md](system.md) | `chip_*`, `chip_agentic` |
| Prefab UI | [prefab.md](prefab.md) | `show_*` |
| Fabrication / fabs | [fabrication.md](fabrication.md) | (workflow — see [FABRICATION_AND_FABS.md](../FABRICATION_AND_FABS.md)) |

Full catalog: [TOOLS.md](../TOOLS.md).

**Silicon:** [FABRICATION_AND_FABS.md](../FABRICATION_AND_FABS.md) — where and how to tape out (Tiny Tapeout, ChipFoundry, academic & commercial MPW).

Webapp: open **Help** in the dashboard for the same content in tabbed form (`GET /api/v1/help/{slug}`).
