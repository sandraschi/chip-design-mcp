"""
Standard Cells MCP tools - PDK library browsing and cell information.

Provides standard cell listing, detail lookup, search by function,
and library statistics.

Registered via register_standard_cells_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import os
import re
from typing import Annotated, Literal

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}

_PDK_VERILOG = {
    "sky130": "sky130A/libs.ref/sky130_fd_sc_hd/verilog",
    "gf180mcu": "gf180mcuA/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog",
    "ihp-sg13g2": "ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog",
}


def _classify_cell(name: str) -> str:
    n = name.lower()
    if "buf" in n and "inv" not in n:
        return "buffer"
    if "inv" in n or "not" in n:
        return "inverter"
    if "nand" in n:
        return "nand"
    if "nor" in n:
        return "nor"
    if "xnor" in n:
        return "xnor"
    if "xor" in n:
        return "xor"
    if "and" in n:
        return "and"
    if "or" in n:
        return "or"
    if "mux" in n:
        return "mux"
    if "dff" in n or "dfxtp" in n:
        return "dff"
    if "latch" in n or "dlat" in n:
        return "latch"
    if "half" in n or "ha" in n:
        return "adder"
    if "full" in n or "fa" in n or "add" in n:
        return "adder"
    if "tie" in n or "conb" in n:
        return "constant"
    if "fill" in n or "filler" in n:
        return "filler"
    if "tap" in n or "diode" in n:
        return "tap"
    return "combinational"


def _drive_strength(name: str) -> str:
    parts = name.rsplit("_", 1)
    if (len(parts) == 2 and parts[1].replace("X", "x").replace("1", "").isdigit()) or parts[1] in ("1", "2", "4", "8"):
        return parts[1]
    m = re.search(r"_(\d+|X\d+)$", name)
    return m.group(1) if m else "?"


def register_standard_cells_tools(mcp, state: dict):
    """Register all Standard Cells MCP tools on the FastMCP instance."""

    def _verilog_dir(pdk: str) -> str | None:
        pdk_root = os.environ.get("PDK_ROOT", "")
        if not pdk_root:
            return None
        rel = _PDK_VERILOG.get(pdk)
        if not rel:
            return None
        path = os.path.join(pdk_root, rel.replace("/", os.sep))
        return path if os.path.isdir(path) else None

    def _list_cell_files(pdk: str) -> list[str]:
        vdir = _verilog_dir(pdk)
        if not vdir:
            return []
        return sorted(f for f in os.listdir(vdir) if f.endswith(".v"))

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def cells_list(
        pdk: Annotated[str, Field(description="PDK name: sky130, gf180mcu, or ihp-sg13g2.")] = "sky130",
        limit: Annotated[int, Field(description="Max cells to return.")] = 50,
    ) -> dict:
        """List standard cells available in a PDK.

        ## Return Format
        {"success": bool, "data": {"pdk": str, "cells": [{"name": str, "function": str}, ...], "total": int}}

        ## Examples
        await cells_list(pdk="sky130")
        await cells_list(pdk="gf180mcu", limit=100)
        """
        if not os.environ.get("PDK_ROOT"):
            return {
                "success": False,
                "message": "PDK_ROOT not set. Set PDK_ROOT to ~/.volare or install via volare.\nInstall PDKs: pip install volare && volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095",
                "data": None,
            }
        files = _list_cell_files(pdk)
        cells = [{"name": f[:-2], "function": _classify_cell(f)} for f in files[:limit]]
        return {"success": True, "data": {"pdk": pdk, "cells": cells, "total": len(files)}}

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def cells_info(
        cell_name: Annotated[str, Field(description="Standard cell name (e.g. 'sky130_fd_sc_hd__and2_1').")],
        pdk: Annotated[str, Field(description="PDK name.")] = "sky130",
    ) -> dict:
        """Get detailed information about a specific standard cell.

        ## Return Format
        {"success": bool, "data": {"name": str, "function": str, "drive_strength": str, "pins": [str, ...]}}

        ## Examples
        await cells_info(cell_name="sky130_fd_sc_hd__and2_1")
        await cells_info(cell_name="sky130_fd_sc_hd__nand2_2")
        """
        vdir = _verilog_dir(pdk)
        if not vdir:
            return {"success": False, "message": "PDK verilog directory not found.", "data": None}
        vfile = os.path.join(vdir, f"{cell_name}.v")
        if not os.path.isfile(vfile):
            return {"success": False, "message": f"Cell not found: {cell_name}", "data": None}
        text = open(vfile, encoding="utf-8", errors="replace").read()
        pins = re.findall(r"\b(input|output|inout)\s+(?:\[\d+:\d+\]\s+)?(\w+)", text)
        pin_names = [p[1] for p in pins]
        return {
            "success": True,
            "data": {
                "name": cell_name,
                "function": _classify_cell(cell_name),
                "drive_strength": _drive_strength(cell_name),
                "pins": pin_names,
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def cells_search(
        function: Annotated[
            Literal["buffer", "inverter", "and", "or", "nand", "nor", "xor", "mux", "dff", "latch", "adder", "all"],
            Field(
                description="Function to search: buffer, inverter, and, or, nand, nor, xor, mux, dff, latch, adder, all."
            ),
        ] = "all",
        pdk: Annotated[str, Field(description="PDK name.")] = "sky130",
        limit: Annotated[int, Field(description="Max results.")] = 30,
    ) -> dict:
        """Search standard cells by logic function.

        ## Return Format
        {"success": bool, "data": {"function": str, "cells": [{"name": str, "drive": str}, ...], "count": int}}

        ## Examples
        await cells_search(function="nand")
        await cells_search(function="dff", pdk="sky130", limit=20)
        """
        files = _list_cell_files(pdk)
        matches = []
        for fname in files:
            name = fname[:-2]
            fn = _classify_cell(name)
            if function == "all" or fn == function:
                matches.append({"name": name, "drive": _drive_strength(name)})
            if len(matches) >= limit:
                break
        return {"success": True, "data": {"function": function, "cells": matches, "count": len(matches)}}

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def cells_stats(
        pdk: Annotated[str, Field(description="PDK name.")] = "sky130",
    ) -> dict:
        """Get aggregate statistics about a standard cell library.

        ## Return Format
        {"success": bool, "data": {"total_cells": int, "by_function": dict, "pdk": str}}

        ## Examples
        await cells_stats(pdk="sky130")
        """
        files = _list_cell_files(pdk)
        by_fn: dict[str, int] = {}
        for fname in files:
            fn = _classify_cell(fname)
            by_fn[fn] = by_fn.get(fn, 0) + 1
        return {"success": True, "data": {"total_cells": len(files), "by_function": by_fn, "pdk": pdk}}

    return {
        "cells_list": cells_list,
        "cells_info": cells_info,
        "cells_search": cells_search,
        "cells_stats": cells_stats,
    }
