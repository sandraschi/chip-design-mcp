# Standard cells (PDK libraries)

Browse **sky130**, **gf180mcu**, and **ihp-sg13g2** standard-cell metadata when `PDK_ROOT` is installed.

## Prerequisites

```powershell
volare enable --pdk sky130 0bbdd5
```

`chip_available_pdks` lists what is present on disk.

## Tools

| Tool | Description |
|------|-------------|
| `cells_list` | Paginated cell names for a PDK |
| `cells_info` | Pin list and function for one cell |
| `cells_search` | Find cells by logic function (nand, dff, …) |
| `cells_stats` | Count cells by classified function |

## Naming (sky130 HD)

Cells follow `sky130_fd_sc_hd__<function>_<drive>` e.g. `sky130_fd_sc_hd__nand2_1`.

## Example prompts

- "List sky130 nand cells and show stats by function."
- "Get pin details for sky130_fd_sc_hd__dffxtp_1."

## Related

- [PDK_GUIDE.md](../PDK_GUIDE.md)
- [synthesis.md](synthesis.md) — liberty for mapping
