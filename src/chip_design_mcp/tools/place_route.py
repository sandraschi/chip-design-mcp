"""
Place & Route MCP tools - OpenLane automated RTL-to-GDSII flow.

Provides OpenLane configuration, flow execution, report reading,
and GDSII/LEF/DEF export.

Registered via register_place_route_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import json
import os
import shutil
from typing import Annotated, Literal

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}
_MUTATING = {"readOnlyHint": False}

_PDK_MAP = {
    "sky130": "sky130A",
    "gf180mcu": "gf180mcuA",
    "ihp-sg13g2": "ihp-sg13g2",
}


def register_place_route_tools(
    mcp,
    state: dict,
    run_eda,
    run_openlane,
    work_dir: str,
    output_dir: str,
    designs_dir: str,
    upload_dir: str,
):
    """Register all Place & Route MCP tools on the FastMCP instance."""

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def pr_status() -> dict:
        """Check OpenLane availability, Docker status, and PDK setup.

        ## Return Format
        {"success": bool, "openlane_available": bool, "docker_available": bool, "pdk_root": str | None}

        ## Examples
        await pr_status()
        """
        tools = state.get("tools", {})
        pdk_root = os.environ.get("PDK_ROOT")
        return {
            "success": True,
            "openlane_available": bool(tools.get("openlane")),
            "docker_available": bool(tools.get("docker")),
            "native_openlane": bool(tools.get("openlane")),
            "pdk_root": pdk_root,
            "pdk_installed": bool(pdk_root and os.path.isdir(pdk_root)),
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def pr_create_design(
        design_name: Annotated[str, Field(description="Name of the chip design project.")],
        verilog_file: Annotated[str, Field(description="Verilog RTL filename in uploads directory.")],
        pdk: Annotated[str, Field(description="PDK to use: sky130, gf180mcu, or ihp-sg13g2.")] = "sky130",
    ) -> dict:
        """Create a new OpenLane design directory from a Verilog source file.

        ## Return Format
        {"success": bool, "message": str, "data": {"design_dir": str, "verilog": str, "pdk": str}}

        ## Examples
        await pr_create_design(design_name="my_counter", verilog_file="counter.v")
        """
        src = os.path.join(upload_dir, verilog_file)
        if not os.path.isfile(src):
            return {"success": False, "message": f"Verilog file not found: {verilog_file}", "data": None}
        design_dir = os.path.join(designs_dir, design_name)
        src_dir = os.path.join(design_dir, "src")
        os.makedirs(src_dir, exist_ok=True)
        dest_v = os.path.join(src_dir, verilog_file)
        shutil.copy2(src, dest_v)
        pdk_name = _PDK_MAP.get(pdk, pdk)
        top = os.path.splitext(verilog_file)[0]
        config = {
            "DESIGN_NAME": top,
            "VERILOG_FILES": f"dir::src/{verilog_file}",
            "CLOCK_PORT": "clk",
            "CLOCK_PERIOD": 10,
            "FP_CORE_UTIL": 40,
            "PL_TARGET_DENSITY": 0.55,
            "PDK": pdk_name,
        }
        config_path = os.path.join(design_dir, "config.json")
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        return {
            "success": True,
            "message": f"Design '{design_name}' created with {pdk_name} PDK",
            "data": {"design_dir": design_dir, "verilog": verilog_file, "pdk": pdk_name},
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def pr_configure(
        design_name: Annotated[str, Field(description="Design name to configure.")],
        clock_period: Annotated[float, Field(description="Clock period in ns.")] = 10,
        core_util: Annotated[int, Field(description="Core utilization percentage (1-90).")] = 40,
        target_density: Annotated[float, Field(description="Placement target density (0.1-0.99).")] = 0.55,
        die_area: Annotated[str, Field(description="Die area as 'x0 y0 x1 y1' in microns (empty = auto).")] = "",
        macros: Annotated[str, Field(description="Comma-separated macro module names.")] = "",
    ) -> dict:
        """Configure OpenLane flow parameters for a design.

        ## Return Format
        {"success": bool, "data": {"config_path": str, "params": dict}}

        ## Examples
        await pr_configure(design_name="my_counter", clock_period=20)
        await pr_configure(design_name="my_alu", clock_period=5, core_util=60)
        """
        design_dir = os.path.join(designs_dir, design_name)
        config_path = os.path.join(design_dir, "config.json")
        if not os.path.isfile(config_path):
            return {"success": False, "message": f"Design not found: {design_name}. Use pr_create_design first.", "data": None}
        with open(config_path, encoding="utf-8") as f:
            config = json.load(f)
        config["CLOCK_PERIOD"] = clock_period
        config["FP_CORE_UTIL"] = core_util
        config["PL_TARGET_DENSITY"] = target_density
        if die_area:
            config["DIE_AREA"] = die_area
        if macros:
            config["MACROS"] = [m.strip() for m in macros.split(",") if m.strip()]
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        return {
            "success": True,
            "message": f"Configuration updated for '{design_name}'",
            "data": {"config_path": config_path, "params": config},
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def pr_run_flow(
        design_name: Annotated[str, Field(description="Design name to run.")],
        from_stage: Annotated[
            Literal["synthesis", "floorplan", "placement", "cts", "routing", "signoff"],
            Field(description="Start from stage: synthesis, floorplan, placement, cts, routing, signoff."),
        ] = "synthesis",
        to_stage: Annotated[str, Field(description="Stop after stage (empty = run to end).")] = "",
        tag: Annotated[str, Field(description="Run tag for outputs (e.g. 'v1', 'experiment').")] = "",
    ) -> dict:
        """Run the OpenLane flow (RTL-to-GDSII) for a design.

        Stages: synthesis -> floorplan -> placement -> cts -> routing -> signoff

        ## Return Format
        {"success": bool, "message": str, "data": {"run_dir": str, "stage": str, "stdout": str, "stderr": str}}

        ## Examples
        await pr_run_flow(design_name="my_counter")
        await pr_run_flow(design_name="my_alu", from_stage="floorplan", tag="v2")
        """
        design_dir = os.path.join(designs_dir, design_name)
        config_path = os.path.join(design_dir, "config.json")
        if not os.path.isfile(config_path):
            return {"success": False, "message": f"Design not found: {design_name}. Use pr_create_design first.", "data": None}
        if not state.get("tools", {}).get("openlane") and not state.get("tools", {}).get("docker"):
            return {
                "success": False,
                "message": "OpenLane not available. Install openlane or Docker.",
                "data": None,
            }
        args = [f"--design={design_name}", f"--from={from_stage}"]
        if to_stage:
            args.append(f"--to={to_stage}")
        if tag:
            args.append(f"--tag={tag}")
        result = await run_openlane(design_dir, designs_dir, args, timeout=3600)
        run_dir = os.path.join(design_dir, "runs", tag or "RUN_LATEST")
        ok = result.get("success", False)
        return {
            "success": ok,
            "message": f"OpenLane flow {'completed' if ok else 'failed'} for '{design_name}'",
            "data": {
                "run_dir": run_dir,
                "stage": to_stage or "signoff",
                "stdout": result.get("stdout", ""),
                "stderr": result.get("stderr", ""),
            },
        }

    def _latest_run_dir(design_dir: str, tag: str) -> str | None:
        runs = os.path.join(design_dir, "runs")
        if not os.path.isdir(runs):
            return None
        if tag:
            candidate = os.path.join(runs, tag)
            return candidate if os.path.isdir(candidate) else None
        subdirs = [os.path.join(runs, d) for d in os.listdir(runs) if os.path.isdir(os.path.join(runs, d))]
        if not subdirs:
            return None
        return max(subdirs, key=os.path.getmtime)

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def pr_read_reports(
        design_name: Annotated[str, Field(description="Design name.")],
        report_type: Annotated[
            Literal["timing", "power", "area", "drc", "all"],
            Field(description="Report type: timing, power, area, drc, all."),
        ] = "all",
        tag: Annotated[str, Field(description="Run tag (default: latest).")] = "",
    ) -> dict:
        """Read OpenLane flow reports (timing, power, area, DRC).

        ## Return Format
        {"success": bool, "data": {"timing": dict | None, "power": dict | None, "area": dict | None, "drc": dict | None}}

        ## Examples
        await pr_read_reports(design_name="my_counter")
        await pr_read_reports(design_name="my_alu", report_type="timing")
        """
        design_dir = os.path.join(designs_dir, design_name)
        run_dir = _latest_run_dir(design_dir, tag)
        if not run_dir:
            return {"success": False, "message": "No run found. Run pr_run_flow first.", "data": None}

        def read_rpt(suffix: str) -> str | None:
            for root, _dirs, files in os.walk(run_dir):
                for fname in files:
                    if fname.endswith(suffix):
                        try:
                            return open(os.path.join(root, fname), encoding="utf-8", errors="replace").read()
                        except OSError:
                            return None
            return None

        data: dict = {}
        if report_type in ("timing", "all"):
            data["timing"] = read_rpt(".sta.rpt")
        if report_type in ("area", "all"):
            data["area"] = read_rpt(".area.rpt")
        if report_type in ("power", "all"):
            data["power"] = read_rpt(".power.rpt")
        if report_type in ("drc", "all"):
            data["drc"] = read_rpt(".drc.rpt")
        return {
            "success": True,
            "message": f"Reports for '{design_name}' (run: {os.path.basename(run_dir)})",
            "data": data,
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def pr_export_gds(
        design_name: Annotated[str, Field(description="Design name.")],
        tag: Annotated[str, Field(description="Run tag (default: latest).")] = "",
    ) -> dict:
        """Export the final GDSII layout file from an OpenLane run.

        ## Return Format
        {"success": bool, "data": {"gds_file": str, "size_bytes": int}}

        ## Examples
        await pr_export_gds(design_name="my_counter")
        """
        design_dir = os.path.join(designs_dir, design_name)
        run_dir = _latest_run_dir(design_dir, tag)
        if not run_dir:
            return {"success": False, "message": "No run found.", "data": None}
        gds_src = None
        for root, _dirs, files in os.walk(run_dir):
            if "results" in root.replace("\\", "/").split("/"):
                for fname in files:
                    if fname.endswith(".gds") and "final" in root:
                        gds_src = os.path.join(root, fname)
                        break
            if gds_src:
                break
        if not gds_src:
            for root, _dirs, files in os.walk(run_dir):
                for fname in files:
                    if fname.endswith(".gds"):
                        gds_src = os.path.join(root, fname)
                        break
                if gds_src:
                    break
        if not gds_src:
            return {"success": False, "message": "GDS file not found. Flow may not have completed to signoff.", "data": None}
        dest = os.path.join(output_dir, f"{design_name}.gds")
        shutil.copy2(gds_src, dest)
        return {
            "success": True,
            "message": f"GDSII for '{design_name}' exported",
            "data": {"gds_file": dest, "size_bytes": os.path.getsize(dest)},
        }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def pr_export_lef(
        design_name: Annotated[str, Field(description="Design name.")],
        tag: Annotated[str, Field(description="Run tag (default: latest).")] = "",
    ) -> dict:
        """Export the LEF (Library Exchange Format) macro view.

        ## Return Format
        {"success": bool, "data": {"lef_file": str, "size_bytes": int}}

        ## Examples
        await pr_export_lef(design_name="my_counter")
        """
        design_dir = os.path.join(designs_dir, design_name)
        run_dir = _latest_run_dir(design_dir, tag)
        if not run_dir:
            return {"success": False, "message": "No run found.", "data": None}
        lef_src = None
        for root, _dirs, files in os.walk(run_dir):
            for fname in files:
                if fname.endswith(".lef"):
                    lef_src = os.path.join(root, fname)
                    break
            if lef_src:
                break
        if not lef_src:
            return {"success": False, "message": "LEF file not found. Run may not have completed.", "data": None}
        dest = os.path.join(output_dir, f"{design_name}.lef")
        shutil.copy2(lef_src, dest)
        return {
            "success": True,
            "message": f"LEF for '{design_name}' exported",
            "data": {"lef_file": dest, "size_bytes": os.path.getsize(dest)},
        }

    return {
        "pr_status": pr_status,
        "pr_create_design": pr_create_design,
        "pr_configure": pr_configure,
        "pr_run_flow": pr_run_flow,
        "pr_read_reports": pr_read_reports,
        "pr_export_gds": pr_export_gds,
        "pr_export_lef": pr_export_lef,
    }
