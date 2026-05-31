# System tools

Cross-cutting MCP tools and agentic assist.

## Tools

| Tool | Description |
|------|-------------|
| `chip_status` | EDA binary discovery, PDK flag, work dirs, uptime |
| `chip_pipeline_stages` | 11-stage RTL-to-GDSII catalog |
| `chip_available_pdks` | sky130 / gf180 / IHP install state |
| `chip_agentic` | Sampling: `status_summary`, `flow_plan`, `natural_query` |

## When to call first

Always start sessions with `chip_status` before long OpenLane or synthesis runs.

## chip_agentic operations

| Operation | Needs `prompt` | Needs sampling host |
|-----------|----------------|---------------------|
| `status_summary` | No | No |
| `flow_plan` | Yes | Yes |
| `natural_query` | Yes | Yes |

Without sampling, use domain tools directly and `chip_pipeline_stages` for ordering.

## REST mirrors

- `GET /api/v1/status`
- `GET /api/capabilities`
- `GET /.well-known/mcp/manifest.json`

## Related

- [prefab.md](prefab.md) — in-chat cards
- [CONFIGURATION.md](../CONFIGURATION.md)
