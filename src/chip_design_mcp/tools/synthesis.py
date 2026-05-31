"""
Synthesis MCP tools - Yosys RTL synthesis.

Provides Verilog loading, elaboration, synthesis passes, statistics,
schematic generation, and netlist export.

Registered via register_synthesis_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import json
import os
from typing import Annotated, Literal

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}
_MUTATING = {"readOnlyHint": False}


def register_synthesis_tools(mcp, state: dict, run_eda, work_dir: str, output_dir: str, upload_dir: str):
    """Register all Synthesis MCP tools on the FastMCP instance."""

    syn_state = state.setdefault("synthesis", {})

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def syn_status() -> dict:
        """Check Yosys availability and version.

        ## Return Format
        {"success": bool, "yosys_available": bool, "version": str, "path": str | None}

        ## Examples
        await syn_status()
        """
        available = state.get("tools", {}).get("yosys", False)
        if not available:
            return {"success": True, "yosys_available": False, "version": None, "path": None}
        result = await run_eda(["yosys", "-V"], timeout=30)
        version = (result.get("stdout") or result.get("stderr") or "").strip() or "unknown"
        return {"success": True, "yosys_available": True, "version": version, "path": "yosys"}

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def syn_read_verilog(
        file_name: Annotated[str, Field(description="Verilog filename in uploads directory (e.g. 'counter.v').")],
        top_module: Annotated[str, Field(description="Top-level module name to synthesize.")] = "",
        liberty: Annotated[str, Field(description="Liberty (.lib) cell library path (optional).")] = "",
    ) -> dict:
        """Load Verilog source files and optionally set the top module.

        ## Return Format
        {"success": bool, "message": str, "data": {"file": str, "top_module": str, "liberty": str | None}}

        ## Examples
        await syn_read_verilog(file_name="counter.v", top_module="counter")
        await syn_read_verilog(file_name="alu.v", top_module="alu", liberty="sky130_fd_sc_hd__tt_025C_1v80.lib")
        """
        path = os.path.join(upload_dir, file_name)
        if not os.path.isfile(path):
            return {"success": False, "message": f"File not found: {file_name}", "data": None}
        top = top_module or os.path.splitext(file_name)[0]
        syn_state["verilog_file"] = path
        syn_state["top_module"] = top
        syn_state["liberty"] = liberty or None
        return {
            "success": True,
            "message": f"Loaded {file_name} (top: {top})",
            "data": {"file": file_name, "top_module": top, "liberty": liberty or None},
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def syn_run(
        top_module: Annotated[str, Field(description="Top module to synthesize (uses last loaded if empty).")] = "",
        flatten: Annotated[bool, Field(description="Flatten hierarchy during synthesis.")] = False,
        abc9: Annotated[bool, Field(description="Use ABC9 for technology mapping (recommended).")] = True,
        script_extra: Annotated[str, Field(description="Extra Yosys commands to append to synthesis script.")] = "",
    ) -> dict:
        """Run Yosys synthesis: elaborate -> synth -> techmap -> opt -> stat.

        ## Return Format
        {"success": bool, "message": str, "data": {"cells": int, "area": float | None, "stdout": str, "stderr": str}}

        ## Examples
        await syn_run(top_module="counter")
        await syn_run(top_module="alu", flatten=True)
        """
        if not state.get("tools", {}).get("yosys"):
            return {"success": False, "message": "Yosys not found. Install yosys.", "data": None}
        top = top_module or syn_state.get("top_module", "")
        if not top:
            return {"success": False, "message": "No top module specified. Use top_module parameter.", "data": None}
        vfile = syn_state.get("verilog_file")
        if not vfile:
            return {"success": False, "message": "No Verilog file loaded. Use syn_read_verilog first.", "data": None}
        liberty = syn_state.get("liberty")
        out_v = os.path.join(output_dir, f"{top}_synth.v")
        stat_json = os.path.join(output_dir, f"_stat_{top}.json")
        script_lines = [
            f"read_verilog {vfile}",
            f"hierarchy -top {top}",
        ]
        if flatten:
            script_lines.append("flatten")
        script_lines.extend(
            [
                "proc; opt",
                "fsm; opt",
                "memory; opt",
                "techmap; opt",
            ]
        )
        if liberty:
            if abc9:
                script_lines.append(f"dfflibmap -liberty {liberty}")
                script_lines.append(f"abc9 -liberty {liberty}")
            else:
                script_lines.append(f"abc -liberty {liberty}")
        else:
            script_lines.append("abc; opt_clean")
        if script_extra:
            script_lines.append(script_extra)
        script_lines.append(f"tee -o {stat_json} stat -json")
        script_lines.append(f"write_verilog -noattr {out_v}")
        script_path = os.path.join(output_dir, f"_syn_{top}.ys")
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(";\n".join(script_lines) + ";\n")
        result = await run_eda(["yosys", "-s", script_path], timeout=300, cwd=work_dir)
        cells = 0
        wires = 0
        area = None
        if os.path.isfile(stat_json):
            try:
                with open(stat_json, encoding="utf-8") as f:
                    stat_data = json.load(f)
                for mod in (stat_data.get("modules") or {}).values():
                    cells += int(mod.get("num_cells", 0))
                    wires += int(mod.get("num_wires", 0))
                    if mod.get("area") is not None:
                        area = float(mod["area"])
            except (json.JSONDecodeError, OSError, TypeError, ValueError):
                pass
        syn_state["last_synth"] = {
            "top_module": top,
            "verilog_file": vfile,
            "liberty": liberty,
            "output_file": out_v,
            "cells": cells,
            "wires": wires,
            "area": area,
        }
        ok = result.get("success", False)
        msg = f"Synthesis of '{top}' {'completed' if ok else 'failed'}"
        return {
            "success": ok,
            "message": msg,
            "data": {
                "cells": cells,
                "area": area,
                "stdout": result.get("stdout", ""),
                "stderr": result.get("stderr", ""),
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def syn_stats() -> dict:
        """Get synthesis statistics from the last syn_run (cell count, area, wires).

        ## Return Format
        {"success": bool, "data": {"cells": int, "wires": int, "area": float | None, "state": dict}}

        ## Examples
        await syn_stats()
        """
        last = syn_state.get("last_synth") or {}
        return {
            "success": bool(last),
            "data": {
                "cells": last.get("cells", 0),
                "wires": last.get("wires", 0),
                "area": last.get("area"),
                "state": {
                    "verilog_file": syn_state.get("verilog_file"),
                    "top_module": syn_state.get("top_module"),
                    "liberty": syn_state.get("liberty"),
                },
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def syn_show(
        top_module: Annotated[str, Field(description="Module to generate schematic for.")] = "",
        format: Annotated[
            Literal["dot", "svg", "pdf"],
            Field(description="Output format: dot, svg, or pdf."),
        ] = "svg",
    ) -> dict:
        """Generate a schematic diagram of the synthesized design using Yosys 'show'.

        ## Return Format
        {"success": bool, "message": str, "data": {"output_file": str, "format": str}}

        ## Examples
        await syn_show(top_module="counter", format="svg")
        """
        if not state.get("tools", {}).get("yosys"):
            return {"success": False, "message": "Yosys not found.", "data": None}
        top = top_module or syn_state.get("top_module", "")
        vfile = syn_state.get("verilog_file")
        if not top or not vfile:
            return {"success": False, "message": "No Verilog loaded. Use syn_read_verilog first.", "data": None}
        prefix = os.path.join(output_dir, f"{top}_show")
        script_path = os.path.join(output_dir, f"{top}_show.ys")
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(f"read_verilog {vfile}; hierarchy -top {top}; proc; show -format dot -prefix {prefix};\n")
        result = await run_eda(["yosys", "-s", script_path], timeout=120, cwd=work_dir)
        if not result.get("success"):
            return {"success": False, "message": f"Yosys show failed: {result.get('stderr', '')}", "data": None}
        dot_file = f"{prefix}.dot"
        if format == "dot" or not os.path.isfile(dot_file):
            if os.path.isfile(dot_file):
                return {
                    "success": True,
                    "message": "Schematic generated (DOT format)",
                    "data": {"output_file": dot_file, "format": "dot"},
                }
            return {"success": False, "message": "DOT file not produced", "data": None}
        out_file = os.path.join(output_dir, f"{top}_show.{format}")
        dot_cmd = os.environ.get("GRAPHVIZ_DOT", "dot")
        conv = await run_eda([dot_cmd, f"-T{format}", dot_file, "-o", out_file], timeout=60)
        if conv.get("success") and os.path.isfile(out_file):
            return {
                "success": True,
                "message": f"Schematic generated ({format})",
                "data": {"output_file": out_file, "format": format},
            }
        return {
            "success": True,
            "message": "Schematic generated (DOT format)",
            "data": {"output_file": dot_file, "format": "dot"},
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def syn_export_netlist(
        format: Annotated[
            Literal["verilog", "json", "spice"],
            Field(description="Netlist format: verilog, json, or spice."),
        ] = "verilog",
    ) -> dict:
        """Export the synthesized gate-level netlist.

        ## Return Format
        {"success": bool, "message": str, "data": {"output_file": str, "format": str, "size_bytes": int}}

        ## Examples
        await syn_export_netlist(format="verilog")
        await syn_export_netlist(format="json")
        """
        if not state.get("tools", {}).get("yosys"):
            return {"success": False, "message": "Run syn_read_verilog first.", "data": None}
        top = syn_state.get("top_module", "top")
        vfile = syn_state.get("verilog_file")
        if not vfile:
            return {"success": False, "message": "Run syn_read_verilog first.", "data": None}
        ext = {"verilog": "v", "json": "json", "spice": "spice"}[format]
        out_file = os.path.join(output_dir, f"{top}_netlist.{ext}")
        write_cmd = {
            "verilog": f"write_verilog -noattr {out_file}",
            "json": f"write_json {out_file}",
            "spice": f"write_spice {out_file}",
        }[format]
        script_path = os.path.join(output_dir, f"{top}_export.ys")
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(f"read_verilog {vfile}; hierarchy -top {top}; proc; techmap; opt; {write_cmd};\n")
        result = await run_eda(["yosys", "-s", script_path], timeout=120, cwd=work_dir)
        if not result.get("success") or not os.path.isfile(out_file):
            return {"success": False, "message": result.get("stderr", "Export failed"), "data": None}
        return {
            "success": True,
            "message": f"Netlist exported as {format}",
            "data": {"output_file": out_file, "format": format, "size_bytes": os.path.getsize(out_file)},
        }

    return {
        "syn_status": syn_status,
        "syn_read_verilog": syn_read_verilog,
        "syn_run": syn_run,
        "syn_stats": syn_stats,
        "syn_show": syn_show,
        "syn_export_netlist": syn_export_netlist,
    }
