# Chip Design MCP — REST API Reference

Base URL: `http://127.0.0.1:11022`

## Status

```
GET /api/v1/status
```

Response:
```json
{
  "server": "chip-design-mcp",
  "version": "0.1.0",
  "tools": {"yosys": true, "openlane": false, ...},
  "pdk_installed": true,
  "uptime_s": 3600
}
```

## Tool Discovery

```
GET /api/v1/tools
```

Response:
```json
{
  "tools": ["cells_info", "cells_list", "cells_search", ...],
  "count": 31
}
```

> All 28 domain tools plus 3 system tools (`chip_status`, `chip_pipeline_stages`, `chip_available_pdks`) are dispatchable here.

## Tool Invocation

```
POST /api/v1/control/{tool_name}
Content-Type: application/json

{ "param1": "value1", "param2": 42 }
```

Example:
```bash
curl -X POST http://127.0.0.1:11022/api/v1/control/chip_status
curl -X POST http://127.0.0.1:11022/api/v1/control/cells_search \
  -H "Content-Type: application/json" \
  -d '{"function": "nand", "limit": 5}'
```

## File Upload

```
POST /api/v1/upload
Content-Type: multipart/form-data

file=@counter.v
```

## File Listing

```
GET /api/v1/list?dir=uploads|outputs|designs
```

## File Download

```
GET /api/v1/download/{file_name}?dir=outputs|uploads|designs
```
