# Verification (DRC, LVS, STA, formal)

Signoff helpers using **Magic**, **netgen**, **OpenSTA**, and **Yosys** formal flows.

## Prerequisites

| Check | Tool | Binary |
|-------|------|--------|
| DRC | Magic | `magic` |
| LVS | netgen | `netgen` |
| STA | OpenSTA | `sta` / `opensta` |
| Formal | Yosys | `yosys` |

PDK tech files under `PDK_ROOT` for Magic DRC.

## Tools

| Tool | Description |
|------|-------------|
| `verify_drc` | Magic DRC on GDS/layout |
| `verify_lvs` | netgen LVS (layout vs SPICE/netlist) |
| `verify_timing` | OpenSTA timing report (needs top, liberty, optional SDC) |
| `verify_formal` | Yosys-based equivalence smoke |

## Typical flow

After `pr_export_gds`:

1. `verify_drc(gds_file="...", tech_file="...")`
2. `verify_lvs(...)`
3. `verify_timing(top_module="...", ...)` with sky130 liberty fallback when `PDK_ROOT` set

## Gotchas

- **Violation counts** are parsed from stdout heuristics — not a signoff database
- Magic needs absolute tech file paths; server resolves from `PDK_ROOT` when possible
- `verify_timing` requires a valid top module name

## Example prompts

- "Run DRC on the latest GDS in outputs and summarize violations."
- "Run STA on top counter with sky130 liberty."

## Related

- [place_route.md](place_route.md)
- [synthesis.md](synthesis.md)
