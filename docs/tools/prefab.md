# Prefab UI (in-chat cards)

Rich MCP App cards for list/status surfaces (fleet SOTA §2.2).

## Registration

Enabled by default. Disable with `CHIP_DESIGN_MCP_PREFAB_APPS=0`.

These tools are **MCP-only** (not on the REST `POST /api/v1/control/{tool}` dispatcher).

## Cards

| Tool | Data source |
|------|-------------|
| `show_chip_status_card` | `chip_status` |
| `show_pdks_card` | `chip_available_pdks` |
| `show_pipeline_card` | `chip_pipeline_stages` |
| `show_depot_card` | `depot_status` |
| `show_cells_stats_card` | `cells_stats` |
| `show_cells_list_card` | `cells_list` |

Hosts without MCP Apps rendering still have plain-text fallbacks on the underlying JSON tools.

## Related

- [system.md](system.md)
