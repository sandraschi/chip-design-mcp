"""Chip design MCP tool modules — each exposes register_*_tools(mcp, ...)."""

from chip_design_mcp.tools.agentic import register_agentic_chip_tools
from chip_design_mcp.tools.depot import register_depot_tools
from chip_design_mcp.tools.place_route import register_place_route_tools
from chip_design_mcp.tools.prefab import register_prefab_tools
from chip_design_mcp.tools.simulation import register_simulation_tools
from chip_design_mcp.tools.standard_cells import register_standard_cells_tools
from chip_design_mcp.tools.synthesis import register_synthesis_tools
from chip_design_mcp.tools.verification import register_verification_tools

__all__ = [
    "register_agentic_chip_tools",
    "register_depot_tools",
    "register_place_route_tools",
    "register_prefab_tools",
    "register_simulation_tools",
    "register_standard_cells_tools",
    "register_synthesis_tools",
    "register_verification_tools",
]
