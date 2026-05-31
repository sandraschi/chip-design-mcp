# Chip Design MCP — Architecture

## Overview

Chip Design MCP orchestrates the open-source RTL-to-GDSII ASIC flow through
MCP tools. It does **not** implement any EDA algorithms — it coordinates
industry-standard open-source tools as subprocesses and exposes their
capabilities through a FastMCP 3.2 interface.

## Execution Model

```
                    ┌─────────────────────────────┐
                    │   FastMCP 3.2 + FastAPI      │
                    │   (port 11022)               │
                    └──────────┬──────────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
     ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
     │   yosys     │   │  iverilog   │   │   Docker    │
     │  (synthesis)│   │  + cocotb   │   │  (OpenLane) │
     └─────────────┘   └─────────────┘   └─────────────┘
```

All execution is via `asyncio.create_subprocess_exec`. No persistent
daemons required (Docker for OpenLane is the exception).

## Tool Registration Pattern

Each domain module defines a `register_*_tools(mcp, **deps)` function:

```python
def register_synthesis_tools(mcp, state, run_eda, work_dir, output_dir, upload_dir):
    @mcp.tool(annotations={"readonly": True}, version="0.1.0")
    async def syn_run(top_module: Annotated[str, Field(...)]) -> dict:
        ...
    return {"syn_run": syn_run, ...}
```

The server calls all registration functions after creating the FastMCP instance.
Dependencies (state dict, subprocess runner, directories) are passed through
the registration functions — no global state in tool modules.

## REST API

All MCP tools are also exposed via REST for webapp consumption:

- `GET  /api/v1/status` — server health
- `GET  /api/v1/tools` — list registered tools
- `POST /api/v1/control/{tool_name}` — invoke any tool via JSON body
- `POST /api/v1/upload` — upload a design file
- `GET  /api/v1/list?dir=uploads|outputs|designs` — list files
- `GET  /api/v1/download/{file_name}?dir=outputs` — download artifact

## Pipeline Stages

| # | Stage | Tool | Input | Output |
|---|-------|------|-------|--------|
| 1 | RTL Design | Editor | Spec | Verilog (.v) |
| 2 | Simulation | cocotb + iverilog | RTL + testbench | Waveform (.vcd) |
| 3 | Synthesis | Yosys | RTL + .lib | Gate netlist (.vg) |
| 4 | Floorplan | OpenLane/OpenROAD | Netlist + .lef | Floorplan (.def) |
| 5 | Placement | OpenLane/OpenROAD | Floorplan + .sdc | Placed (.def) |
| 6 | CTS | OpenLane/OpenROAD | Placed + .sdc | CTS (.def) |
| 7 | Routing | OpenLane/OpenROAD | CTS + .sdc | Routed (.def) |
| 8 | STA | OpenSTA | Routed + SPEF | Timing report |
| 9 | DRC | Magic | GDSII + tech file | DRC report |
| 10 | LVS | netgen | GDSII + SPICE | LVS report |
| 11 | Signoff | Magic/KLayout | Clean GDS | Final GDSII |

## PDK Support

PDKs are installed via volare into `$PDK_ROOT`:

| PDK | Node | Library |
|-----|------|---------|
| sky130 | 130nm | sky130_fd_sc_hd |
| gf180mcu | 180nm | gf180mcu_fd_sc_mcu7t5v0 |
| ihp-sg13g2 | 130nm BiCMOS | sg13g2_stdcell |
