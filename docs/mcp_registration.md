# MCP tool registration (chip-design-mcp)

Canonical fleet rules: [mcp_registration.md](https://github.com/sandraschi/mcp-central-docs/blob/master/standards/rules/mcp_registration.md) in **mcp-central-docs**.

## This repo

- Tools register at import time via `@mcp.tool` inside `register_*_tools()` in `src/chip_design_mcp/tools/*.py`.
- `src/chip_design_mcp/tools/__init__.py` re-exports all `register_*` functions; `server.py` calls them after `FastMCP.from_fastapi(app)`.
- REST dispatch uses the merged `_all_tools` dict (`POST /api/v1/control/{tool_name}`).
- Prefab App tools live in `tools/prefab.py` and are MCP-only (not in `_all_tools`).
- Agentic sampling: `chip_agentic` in `tools/agentic.py` (`ctx.sample` / `ctx.sample_step` when the host supports MCP sampling).
