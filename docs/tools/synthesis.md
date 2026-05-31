# Synthesis (Yosys)

RTL → gate-level netlist using **Yosys**. Tools are prefixed `syn_`.

## Prerequisites

- `yosys` on `PATH` (`syn_status` / `chip_status`)
- Verilog in `uploads/` (via `syn_read_verilog` or `POST /api/v1/upload`)
- For mapped netlists: sky130 (or other) `.lib` — use **abc9** on sky130

## Typical flow

1. `syn_status` — confirm Yosys version
2. `syn_read_verilog(file_name="counter.v", top_module="counter")`
3. `syn_run(top_module="counter", liberty="...optional .lib...")`
4. `syn_stats` — cell/wire counts
5. `syn_export_netlist(format="verilog")` — gate-level `.vg`
6. Optional: `syn_show(format="svg")` — schematic from netlist

## Tools

| Tool | Mutating | Description |
|------|----------|-------------|
| `syn_status` | No | Yosys path and version |
| `syn_read_verilog` | No* | Stage RTL path and top (*updates session state) |
| `syn_run` | Yes | Full synth: proc, opt, techmap, abc9/abc |
| `syn_stats` | No | JSON stats from last run |
| `syn_show` | No | DOT/SVG/PDF schematic |
| `syn_export_netlist` | Yes | Write netlist to `output/` |

## Gotchas

- Run `syn_read_verilog` before `syn_run` in a fresh session
- **abc9** is required for complex sky130 `.lib` files; plain `abc` may fail
- Large designs: increase timeout via server subprocess limits (default 120s)

## Example prompts

- "Check if Yosys is installed, then synthesize `counter.v` with top `counter`."
- "After syn_run, show syn_stats and export verilog netlist."

## Related

- [simulation.md](simulation.md) — verify RTL before synthesis
- [place_route.md](place_route.md) — physical design after netlist
