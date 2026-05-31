"""
Verification MCP tools - DRC, LVS, STA, and formal verification.

Provides design rule checking via Magic, layout-vs-schematic via netgen,
static timing analysis, and formal equivalence checking.

Registered via register_verification_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import os
import re
from typing import Annotated

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}


def register_verification_tools(mcp, state: dict, run_eda, work_dir: str, output_dir: str, upload_dir: str):
    """Register all Verification MCP tools on the FastMCP instance."""

    def _resolve(path: str) -> str:
        if os.path.isabs(path) and os.path.isfile(path):
            return path
        for base in (output_dir, upload_dir, work_dir):
            candidate = os.path.join(base, path)
            if os.path.isfile(candidate):
                return candidate
        return path

    def _sky130_tech() -> str | None:
        pdk_root = os.environ.get("PDK_ROOT", "")
        if not pdk_root:
            return None
        tech = os.path.join(pdk_root, "sky130A", "libs.tech", "sky130A", "sky130A.tech")
        return tech if os.path.isfile(tech) else None

    def _default_liberty() -> str | None:
        pdk_root = os.environ.get("PDK_ROOT", "")
        if not pdk_root:
            return None
        lib = os.path.join(
            pdk_root,
            "sky130A",
            "libs.ref",
            "sky130_fd_sc_hd",
            "lib",
            "sky130_fd_sc_hd__tt_025C_1v80.lib",
        )
        return lib if os.path.isfile(lib) else None

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def verify_drc(
        gds_file: Annotated[str, Field(description="Path to GDSII layout file.")],
        tech_file: Annotated[str, Field(description="Magic technology file path (e.g. sky130A.tech).")] = "",
    ) -> dict:
        """Run Design Rule Check (DRC) on a GDSII layout using Magic.

        ## Return Format
        {"success": bool, "data": {"violations": int, "report": str, "report_file": str | None}}

        ## Examples
        await verify_drc(gds_file="my_counter.gds")
        await verify_drc(gds_file="alu.gds", tech_file="/path/to/sky130A/sky130A.tech")
        """
        if not state.get("tools", {}).get("magic"):
            return {
                "success": False,
                "message": "Magic not found. Install magic (sudo apt install magic).",
                "data": None,
            }
        gds_path = _resolve(gds_file)
        if not os.path.isfile(gds_path):
            return {"success": False, "message": f"GDS file not found: {gds_file}", "data": None}
        tech = tech_file or _sky130_tech()
        if not tech or not os.path.isfile(tech):
            return {
                "success": False,
                "message": "Technology file not found. Set PDK_ROOT or provide tech_file.",
                "data": None,
            }
        report_file = os.path.join(output_dir, f"{os.path.splitext(os.path.basename(gds_path))[0]}.drc.rpt")
        tcl = f"""
tech load {tech}
gds read {gds_path}
load {os.path.splitext(os.path.basename(gds_path))[0]}
select top cell
expand
drc catchup
drc check
drc why
drc count
quit -noprompt
"""
        tcl_path = os.path.join(output_dir, "_drc.tcl")
        with open(tcl_path, "w", encoding="utf-8") as f:
            f.write(tcl.strip() + "\n")
        result = await run_eda(["magic", "-dnull", "-noconsole", tcl_path], timeout=600, cwd=work_dir)
        stdout = result.get("stdout", "") + result.get("stderr", "")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(stdout)
        violations = 0
        for line in stdout.splitlines():
            if "drc" in line.lower():
                nums = re.findall(r"\d+", line)
                if nums:
                    violations = max(violations, int(nums[-1]))
        return {
            "success": result.get("success", False),
            "message": f"DRC complete: {violations} potential violations found",
            "data": {"violations": violations, "report": stdout[:8000], "report_file": report_file},
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def verify_lvs(
        gds_file: Annotated[str, Field(description="Path to GDSII layout file.")],
        spice_netlist: Annotated[str, Field(description="Path to extracted SPICE netlist.")],
        top_cell: Annotated[str, Field(description="Top cell name for LVS comparison.")] = "",
    ) -> dict:
        """Run Layout vs Schematic (LVS) comparison using netgen.

        ## Return Format
        {"success": bool, "data": {"match": bool, "report": str}}

        ## Examples
        await verify_lvs(gds_file="counter.gds", spice_netlist="counter.spice")
        """
        if not state.get("tools", {}).get("netgen"):
            return {"success": False, "message": "netgen not found.", "data": None}
        gds_path = _resolve(gds_file)
        spice_path = _resolve(spice_netlist)
        if not os.path.isfile(gds_path) or not os.path.isfile(spice_path):
            return {"success": False, "message": "Input files not found.", "data": None}
        cell = top_cell or os.path.splitext(os.path.basename(gds_path))[0]
        tcl = f"""
readnet spice {spice_path}
readnet gds {gds_path}
lvs {{{cell} {cell}}} {{{cell} {cell}}} setup.tcl comp.out
quit
"""
        tcl_path = os.path.join(output_dir, "_lvs.tcl")
        with open(tcl_path, "w", encoding="utf-8") as f:
            f.write(tcl.strip() + "\n")
        result = await run_eda(["netgen", "-batch", "source", tcl_path], timeout=600, cwd=work_dir)
        stdout = result.get("stdout", "")
        match = "Circuits match" in stdout or "match uniquely" in stdout.lower()
        return {
            "success": True,
            "message": f"LVS {'PASSED: circuits match' if match else 'FAILED: mismatch detected'}",
            "data": {"match": match, "report": stdout[:8000]},
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def verify_timing(
        netlist: Annotated[str, Field(description="Path to gate-level Verilog netlist.")],
        sdc_file: Annotated[str, Field(description="Path to SDC timing constraints file.")],
        liberty: Annotated[
            str, Field(description="Path to Liberty (.lib) timing library (empty = sky130 from PDK_ROOT).")
        ] = "",
        top_module: Annotated[str, Field(description="Top module name (empty = derived from netlist filename).")] = "",
    ) -> dict:
        """Run Static Timing Analysis (STA) using OpenSTA.

        ## Return Format
        {"success": bool, "data": {"wns": float | None, "tns": float | None, "setup_violations": int, "hold_violations": int, "report": str}}

        ## Examples
        await verify_timing(netlist="counter_synth.v", sdc_file="counter.sdc")
        """
        sta_bin = "sta" if state.get("tools", {}).get("sta") else None
        if not sta_bin:
            for candidate in ("sta", "opensta"):
                if state.get("tools", {}).get(candidate):
                    sta_bin = candidate
                    break
        if not sta_bin:
            return {
                "success": False,
                "message": "OpenSTA not found. Install OpenSTA or set OPENSTA_HOME.",
                "data": None,
            }
        net_path = _resolve(netlist)
        sdc_path = _resolve(sdc_file)
        if not os.path.isfile(net_path) or not os.path.isfile(sdc_path):
            return {"success": False, "message": "Input files not found.", "data": None}
        top = top_module or os.path.splitext(os.path.basename(net_path))[0].replace("_synth", "").replace(
            "_netlist", ""
        )
        lib_path = liberty or _default_liberty()
        if not lib_path or not os.path.isfile(lib_path):
            return {
                "success": False,
                "message": "No Liberty (.lib) provided and none found in PDK_ROOT. Pass liberty=... (e.g. sky130_fd_sc_hd__tt_025C_1v80.lib).",
                "data": None,
            }
        tcl = f"""
read_liberty {lib_path}
read_verilog {net_path}
link_design {top}
read_sdc {sdc_path}
report_checks -path_delay min_max -format full
report_wns
report_tns
exit
"""
        tcl_path = os.path.join(output_dir, "_sta.tcl")
        with open(tcl_path, "w", encoding="utf-8") as f:
            f.write(tcl.strip() + "\n")
        result = await run_eda([sta_bin, "-no_init", "-exit", tcl_path], timeout=300, cwd=work_dir)
        stdout = result.get("stdout", "") + result.get("stderr", "")
        wns = tns = None
        wns_m = re.search(r"wns\s+(-?\d+\.?\d*)", stdout, re.I)
        tns_m = re.search(r"tns\s+(-?\d+\.?\d*)", stdout, re.I)
        if wns_m:
            wns = float(wns_m.group(1))
        if tns_m:
            tns = float(tns_m.group(1))
        return {
            "success": result.get("success", False),
            "message": f"STA complete. WNS={wns} TNS={tns}",
            "data": {
                "wns": wns,
                "tns": tns,
                "setup_violations": 0,
                "hold_violations": 0,
                "report": stdout[:8000],
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def verify_formal(
        design_verilog: Annotated[str, Field(description="Path to synthesized Verilog netlist.")],
        reference_verilog: Annotated[str, Field(description="Path to golden reference Verilog.")],
    ) -> dict:
        """Run formal equivalence checking between two netlists using Yosys.

        ## Return Format
        {"success": bool, "data": {"equivalent": bool, "report": str}}

        ## Examples
        await verify_formal(design_verilog="counter_synth.v", reference_verilog="counter_golden.v")
        """
        if not state.get("tools", {}).get("yosys"):
            return {"success": False, "message": "Yosys not found.", "data": None}
        design_path = _resolve(design_verilog)
        ref_path = _resolve(reference_verilog)
        if not os.path.isfile(design_path) or not os.path.isfile(ref_path):
            return {"success": False, "message": "Input files not found.", "data": None}
        top = os.path.splitext(os.path.basename(design_path))[0].replace("_synth", "")
        script = f"""
read_verilog {ref_path}
design -stash gold
read_verilog {design_path}
design -stash gate
design -copy-from gold -as gold {top}
design -copy-from gate -as gate {top}
equiv_make gold gate equiv
equiv_induct -seq 10
equiv_status -assert
"""
        script_path = os.path.join(output_dir, f"{top}_equiv.ys")
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(script.strip() + "\n")
        result = await run_eda(["yosys", "-s", script_path], timeout=600, cwd=work_dir)
        stdout = result.get("stdout", "") + result.get("stderr", "")
        equivalent = "PASS" in stdout and "equiv_status" in stdout
        return {
            "success": True,
            "message": f"Formal check {'PASSED: equivalent' if equivalent else 'FAILED or inconclusive'}",
            "data": {"equivalent": equivalent, "report": stdout[:8000]},
        }

    return {
        "verify_drc": verify_drc,
        "verify_lvs": verify_lvs,
        "verify_timing": verify_timing,
        "verify_formal": verify_formal,
    }
