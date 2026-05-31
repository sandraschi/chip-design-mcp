"""
Prefab UI MCP tools - in-chat rich cards for status / stats / list surfaces.

Fleet mandate (SOTA section 2.2): list / status / stats tools must have a Prefab
surface. These companion show_* App tools call the existing JSON tools via the
shared all_tools registry and render the result as a PrefabApp.

Registered via register_prefab_tools(mcp, all_tools) - called from server.py
after the full tool registry is assembled. Disable registration with
CHIP_DESIGN_MCP_PREFAB_APPS=0.
"""

from __future__ import annotations

import logging
import os

from prefab_ui.app import PrefabApp
from prefab_ui.components import Badge, Card, CardContent, CardHeader, CardTitle, Muted, Text

logger = logging.getLogger(__name__)


def _fmt_bytes(n: int) -> str:
    if n >= 1024**4:
        return f"{n / 1024**4:.1f} TB"
    if n >= 1024**3:
        return f"{n / 1024**3:.1f} GB"
    if n >= 1024**2:
        return f"{n / 1024**2:.1f} MB"
    if n >= 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n} B"


def register_prefab_tools(mcp, all_tools: dict) -> dict:
    """Register Prefab App tools. `all_tools` is the assembled {name: async fn} registry."""
    if os.environ.get("CHIP_DESIGN_MCP_PREFAB_APPS", "1").lower() in ("0", "false", "no"):
        logger.info("CHIP_DESIGN_MCP_PREFAB_APPS=0 - skipping Prefab tool registration")
        return {}

    registered: dict = {}

    @mcp.tool(app=True, version="0.1.0")
    async def show_chip_status_card() -> PrefabApp:
        """Show EDA toolchain availability, PDK status, and server uptime as a status card.

        ## Examples
        await show_chip_status_card()
        """
        fn = all_tools.get("chip_status")
        data = await fn() if fn else {"success": False}
        tools = data.get("tools") or {}
        ready = sum(1 for v in tools.values() if v)
        total = len(tools)
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle("Chip Design MCP - Status")
            with CardContent():
                Text(f"{ready}/{total} EDA tools available", className="text-sm text-muted-foreground")
                Text("EDA tools", className="text-sm font-semibold mb-1")
                for name, ok in sorted(tools.items()):
                    Text(f"{name}: {'OK' if ok else 'missing'}")
                Badge(f"PDK installed: {'yes' if data.get('pdk_installed') else 'no'}", variant="secondary")
                Text(f"PDK_ROOT: {data.get('pdk_root') or '?'}", className="text-sm mt-2")
                Text(f"Work dir: {data.get('work_dir') or '?'}", className="text-sm")
                Text(f"Uptime: {data.get('uptime_s', 0)}s", className="text-sm")
        return PrefabApp(view=Card, title="Chip Design MCP - Status")

    @mcp.tool(app=True, version="0.1.0")
    async def show_pdks_card() -> PrefabApp:
        """Show the supported PDKs (sky130 / gf180mcu / ihp-sg13g2) and install status.

        ## Examples
        await show_pdks_card()
        """
        fn = all_tools.get("chip_available_pdks")
        data = await fn() if fn else {"pdks": []}
        pdks = data.get("pdks") or []
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle("Available PDKs")
            with CardContent():
                Text(f"PDK_ROOT: {data.get('pdk_root') or 'not set'}", className="text-sm text-muted-foreground")
                for pdk in pdks:
                    status = "installed" if pdk.get("available") else "not installed"
                    Text(f"{pdk.get('name')} - {pdk.get('node')} ({pdk.get('vendor')})", className="text-sm font-semibold mt-1")
                    Badge(status, variant="secondary" if pdk.get("available") else "outline")
                Muted("Install: pip install volare && volare enable --pdk sky130 0bbdd5", className="text-sm mt-2")
        return PrefabApp(view=Card, title="Available PDKs")

    @mcp.tool(app=True, version="0.1.0")
    async def show_pipeline_card() -> PrefabApp:
        """Show the 11-stage RTL-to-GDSII ASIC pipeline with tool assignments.

        ## Examples
        await show_pipeline_card()
        """
        fn = all_tools.get("chip_pipeline_stages")
        data = await fn() if fn else {"stages": []}
        stages = data.get("stages") or []
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle("ASIC Pipeline - RTL to GDSII")
            with CardContent():
                Text(f"{len(stages)} stages", className="text-sm text-muted-foreground")
                for stage in stages:
                    Text(
                        f"{stage.get('stage')} - {stage.get('tool')}: {stage.get('input')} -> {stage.get('output')}",
                        className="text-sm font-semibold mt-1",
                    )
        return PrefabApp(view=Card, title="ASIC Pipeline")

    @mcp.tool(app=True, version="0.1.0")
    async def show_depot_card() -> PrefabApp:
        """Show depot storage stats: project / upload / output file counts and sizes.

        ## Examples
        await show_depot_card()
        """
        fn = all_tools.get("depot_status")
        data = (await fn() if fn else {}).get("data") or {}
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle("Depot - Storage")
            with CardContent():
                Text(
                    f"{data.get('total_files', 0)} files - {_fmt_bytes(data.get('total_size_bytes', 0))}",
                    className="text-sm text-muted-foreground",
                )
                for area in ("designs", "uploads", "outputs"):
                    info = data.get(area) or {}
                    Text(f"{area}: {info.get('files', 0)} files, {_fmt_bytes(info.get('size_bytes', 0))}", className="text-sm")
        return PrefabApp(view=Card, title="Depot - Storage")

    @mcp.tool(app=True, version="0.1.0")
    async def show_cells_stats_card(pdk: str = "sky130") -> PrefabApp:
        """Show standard-cell library statistics (counts by logic function) for a PDK.

        ## Examples
        await show_cells_stats_card(pdk="sky130")
        """
        fn = all_tools.get("cells_stats")
        result = await fn(pdk=pdk) if fn else {"success": False}
        data = result.get("data") or {}
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle(f"Standard Cells - {pdk}")
            with CardContent():
                if not data.get("total_cells"):
                    Text("No cells found. Set PDK_ROOT or install via volare.", className="text-sm")
                    Muted("volare enable --pdk sky130 0bbdd5", className="text-sm mt-1")
                else:
                    Text(f"{data.get('total_cells')} cells", className="text-sm text-muted-foreground")
                    for fn_name, count in sorted((data.get("by_function") or {}).items()):
                        Text(f"{fn_name}: {count}", className="text-sm")
        return PrefabApp(view=Card, title=f"Standard Cells - {pdk}")

    @mcp.tool(app=True, version="0.1.0")
    async def show_cells_list_card(pdk: str = "sky130", limit: int = 30) -> PrefabApp:
        """List standard cells in a PDK as a card (name + classified function).

        ## Examples
        await show_cells_list_card(pdk="sky130", limit=20)
        """
        fn = all_tools.get("cells_list")
        result = await fn(pdk=pdk, limit=limit) if fn else {"success": False}
        cells = (result.get("data") or {}).get("cells") or []
        with Card(className="max-w-lg"):
            with CardHeader():
                CardTitle(f"Cells - {pdk}")
            with CardContent():
                if not cells:
                    Text("No cells found. Set PDK_ROOT or install via volare.", className="text-sm")
                else:
                    Text(f"showing {len(cells)}", className="text-sm text-muted-foreground")
                    for cell in cells:
                        Text(f"{cell.get('name')} ({cell.get('function')})", className="text-sm font-mono")
        return PrefabApp(view=Card, title=f"Cells - {pdk}")

    registered = {
        "show_chip_status_card": show_chip_status_card,
        "show_pdks_card": show_pdks_card,
        "show_pipeline_card": show_pipeline_card,
        "show_depot_card": show_depot_card,
        "show_cells_stats_card": show_cells_stats_card,
        "show_cells_list_card": show_cells_list_card,
    }
    logger.info("Registered %d Prefab App tools", len(registered))
    return registered
