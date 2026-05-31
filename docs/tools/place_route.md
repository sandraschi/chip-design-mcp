# Place & route (OpenLane)

RTL-to-GDSII via **OpenLane** (Docker image or native CLI).

## Prerequisites

- Docker **or** native `openlane` (`pr_status`)
- `PDK_ROOT` with enabled PDK (volare)
- Verilog RTL (uploads or depot project)

## Typical flow

1. `pr_status` — Docker vs native OpenLane
2. `pr_create_design(design_name="my_chip", verilog_file="my_chip.v")`
3. `pr_configure(design_name="my_chip", clock_period_ns=10, ...)` — optional SDC/density
4. `pr_run_flow(design_name="my_chip")` — long-running (10–30+ min)
5. `pr_read_reports(design_name="my_chip")` — timing/area/DRC summaries
6. `pr_export_gds(design_name="my_chip")` / `pr_export_lef(...)`

## Tools

| Tool | Mutating | Description |
|------|----------|-------------|
| `pr_status` | No | OpenLane/Docker availability |
| `pr_create_design` | Yes | Scaffold OpenLane tree under `designs/` |
| `pr_configure` | Yes | Edit `config.json` parameters |
| `pr_run_flow` | Yes | Full RTL2GDS flow |
| `pr_read_reports` | No | Signoff report excerpts |
| `pr_export_gds` | Yes | Copy GDSII to `output/` |
| `pr_export_lef` | Yes | Export LEF macro |

## Gotchas

- First Docker pull is **~3 GB** — plan time and disk
- `pr_run_flow` uses extended timeout (20 min default)
- Designs live under `designs/<name>/` in the work dir

## Example prompts

- "Check OpenLane status, create design my_counter from counter.v, configure 50 MHz clock, run flow."
- "After P&R, read timing reports and export GDS."

## Related

- [verification.md](verification.md) — signoff after layout
- [PDK_GUIDE.md](../PDK_GUIDE.md)
