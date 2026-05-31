# Configuration

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHIP_DESIGN_MCP_WORK_DIR` | `%TEMP%\chip_design_mcp_work` | Uploads, outputs, and OpenLane design trees |
| `PDK_ROOT` | (unset) | Set by **volare** after `volare enable`; required for sky130 liberty paths |
| `CHIP_DESIGN_MCP_PREFAB_APPS` | `1` | `0` disables Prefab in-chat card registration |
| `MCP_AGENTIC` | (unset) | `1` / `true` enables CodeMode BM25 discovery at startup |
| `TEMP` | OS default | Used when work dir env is unset |

## Work directory layout

```
chip_design_mcp_work/
  uploads/     # Verilog, SDC, constraints uploaded via API or tools
  output/      # Synthesis netlists, logs, exported artifacts
  designs/     # OpenLane project directories (config.json, runs/)
```

## MCP client config

See root `manifest.json` and `install-mcp.ps1`. Stdio entry:

```json
"command": "uv",
"args": ["run", "python", "-m", "chip_design_mcp.server", "--mode", "stdio"]
```

HTTP/SSE (dashboard stack): `just serve` on port **11022**, MCP at `/mcp`.

## OpenLane / Docker

No extra env vars required when using the default image `ghcr.io/the-openroad-project/openlane:latest`. Native OpenLane must be on `PATH` as `openlane`.

## Related docs

- [PDK guide](PDK_GUIDE.md)
- [Tool domain guides](tools/README.md)
- [Troubleshooting](TROUBLESHOOTING.md)
