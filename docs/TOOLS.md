# Chip Design MCP — Tool Catalog

Per-domain guides (recommended for agents): **[docs/tools/README.md](tools/README.md)**

## Synthesis (Yosys)

| Tool | Type | Description |
|------|------|-------------|
| `syn_status` | READ_ONLY | Check Yosys availability and version |
| `syn_read_verilog` | READ_ONLY | Load Verilog source files |
| `syn_run` | MUTATING | Run synthesis (elaborate → synth → techmap → opt) |
| `syn_stats` | READ_ONLY | Get synthesis statistics |
| `syn_show` | READ_ONLY | Generate schematic diagram (dot/svg/pdf) |
| `syn_export_netlist` | MUTATING | Export gate-level netlist (verilog/json/spice) |

## Simulation (cocotb + iverilog)

| Tool | Type | Description |
|------|------|-------------|
| `sim_list_tests` | READ_ONLY | List available cocotb testbenches |
| `sim_run_testbench` | MUTATING | Run a cocotb testbench against a DUT |
| `sim_read_waveform` | READ_ONLY | Parse VCD waveform data |
| `sim_check_coverage` | READ_ONLY | Scan test files for coverage metrics |

## Place & Route (OpenLane)

| Tool | Type | Description |
|------|------|-------------|
| `pr_status` | READ_ONLY | Check OpenLane/Docker availability |
| `pr_create_design` | MUTATING | Create a new OpenLane design project |
| `pr_configure` | MUTATING | Configure flow parameters (clock, density, etc.) |
| `pr_run_flow` | MUTATING | Run RTL-to-GDSII flow |
| `pr_read_reports` | READ_ONLY | Read timing/power/area/DRC reports |
| `pr_export_gds` | MUTATING | Export final GDSII layout |
| `pr_export_lef` | MUTATING | Export LEF macro view |

## Verification

| Tool | Type | Description |
|------|------|-------------|
| `verify_drc` | READ_ONLY | Design rule check via Magic |
| `verify_lvs` | READ_ONLY | Layout vs schematic via netgen |
| `verify_timing` | READ_ONLY | Static timing analysis via OpenSTA |
| `verify_formal` | READ_ONLY | Formal equivalence check via Yosys |

## Standard Cells

| Tool | Type | Description |
|------|------|-------------|
| `cells_list` | READ_ONLY | List standard cells in a PDK |
| `cells_info` | READ_ONLY | Get detailed cell info (pins, function, drive) |
| `cells_search` | READ_ONLY | Search cells by logic function |
| `cells_stats` | READ_ONLY | Library statistics by function |

## Depot

| Tool | Type | Description |
|------|------|-------------|
| `depot_init` | MUTATING | Create new project from template (counter/alu/fsm) |
| `depot_list` | READ_ONLY | List files in depot directories |
| `depot_status` | READ_ONLY | Depot storage statistics |

## System

| Tool | Type | Description |
|------|------|-------------|
| `chip_status` | READ_ONLY | Server health and tool availability |
| `chip_pipeline_stages` | READ_ONLY | List ASIC pipeline stages |
| `chip_available_pdks` | READ_ONLY | List available PDKs and status |

## Prefab UI (MCP App cards — in-chat rich UI)

In-chat status/stats/list cards (FastMCP 3.2 `app=True` + `prefab-ui`). MCP-only
(not on the REST dispatcher). Disable registration with `CHIP_DESIGN_MCP_PREFAB_APPS=0`.

| Tool | Type | Description |
|------|------|-------------|
| `show_chip_status_card` | APP | EDA toolchain availability + PDK + uptime card |
| `show_pdks_card` | APP | Supported PDKs and install status |
| `show_pipeline_card` | APP | 11-stage RTL-to-GDSII pipeline |
| `show_depot_card` | APP | Depot storage stats card |
| `show_cells_stats_card` | APP | Standard-cell counts by function |
| `show_cells_list_card` | APP | Standard-cell list card |

Total: **31 JSON tools** — 28 domain + 3 system (9 mutating, 22 read-only) — plus **6 Prefab App tools**.
