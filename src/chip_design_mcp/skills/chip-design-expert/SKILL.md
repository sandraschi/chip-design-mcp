---
name: chip-design-expert
description: Open-source RTL-to-GDSII ASIC flow via chip-design-mcp (Yosys, cocotb, OpenLane, Magic, sky130/gf180 PDKs).
---

# Chip design expert

Use **chip-design-mcp** to orchestrate the open-source ASIC pipeline — never reimplement EDA inside the agent.

## Startup

1. `chip_status` — confirm yosys, iverilog, OpenLane/Docker, PDK (`PDK_ROOT`).
2. `chip_available_pdks` — sky130 / gf180mcu / ihp-sg13g2 via volare.
3. `depot_init` — scaffold RTL + cocotb testbench under the work dir.

## Typical flow

| Step | Tool |
|------|------|
| Simulate | `sim_run_testbench` |
| Synthesize | `syn_read_verilog` → `syn_run` → `syn_stats` |
| P&R | `pr_create_design` → `pr_configure` → `pr_run_flow` |
| Signoff | `verify_drc`, `verify_lvs`, `verify_timing` |
| GDS | `pr_export_gds` |

## PDK install (host)

```powershell
pip install volare
volare enable --pdk sky130 0bbdd5
```

## Ports

- Backend **11022** (`/mcp`, `/api/capabilities`)
- Webapp **11023**

## Agentic

`chip_agentic(operation="flow_plan", prompt="...")` when the MCP host supports sampling.

## Fleet rules

- Git/GitHub: **git-github-mcp**, not fileops.
- Windows paths: **fileops**, not bash.
- Standards: `mcp-central-docs/standards/rules/chip_design_cad_sota.md`.
