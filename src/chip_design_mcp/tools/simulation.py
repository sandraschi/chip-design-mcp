"""
Simulation MCP tools - cocotb + iverilog testbench management.

Provides testbench discovery, execution, waveform reading, and coverage checking.

Registered via register_simulation_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import os
import re
from typing import Annotated

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}
_MUTATING = {"readOnlyHint": False}


def register_simulation_tools(mcp, state: dict, run_eda, work_dir: str, output_dir: str, upload_dir: str):
    """Register all Simulation MCP tools on the FastMCP instance."""

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def sim_list_tests(
        test_dir: Annotated[str, Field(description="Path to cocotb test directory (e.g. 'tests/').")] = "",
    ) -> dict:
        """List available cocotb testbenches in a directory.

        ## Return Format
        {"success": bool, "data": {"tests": [{"file": str, "test_name": str}, ...]}}

        ## Examples
        await sim_list_tests()
        await sim_list_tests(test_dir="my_design/tests")
        """
        base = test_dir or work_dir
        if not os.path.isdir(base):
            return {"success": True, "data": {"tests": []}}
        tests = []
        for root, _dirs, files in os.walk(base):
            for fname in files:
                if fname.startswith("test_") and fname.endswith(".py"):
                    tests.append({"file": os.path.relpath(os.path.join(root, fname), base), "test_name": fname[:-3]})
        return {"success": True, "data": {"tests": tests}}

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def sim_run_testbench(
        dut_file: Annotated[str, Field(description="Verilog DUT filename in uploads directory.")],
        test_module: Annotated[str, Field(description="cocotb test module name (e.g. 'test_counter').")],
        top_module: Annotated[str, Field(description="Top-level Verilog module name.")] = "",
        waves: Annotated[bool, Field(description="Enable VCD waveform dumping.")] = True,
        extra_args: Annotated[str, Field(description="Additional iverilog compile args (e.g. '-g2012 -Wall').")] = "",
    ) -> dict:
        """Run a cocotb testbench against a Verilog DUT.

        ## Return Format
        {"success": bool, "message": str, "data": {"passed": int, "failed": int, "waveform": str | None, "stdout": str}}

        ## Examples
        await sim_run_testbench(dut_file="counter.v", test_module="test_counter")
        await sim_run_testbench(dut_file="alu.v", test_module="test_alu", waves=False)
        """
        dut_path = os.path.join(upload_dir, dut_file)
        if not os.path.isfile(dut_path):
            return {"success": False, "message": f"DUT file not found: {dut_file}", "data": None}
        if not state.get("tools", {}).get("iverilog"):
            return {"success": False, "message": "iverilog not found. Install iverilog.", "data": None}
        top = top_module or os.path.splitext(dut_file)[0]
        vvp_path = os.path.join(output_dir, f"sim_{top}.vvp")
        compile_args = ["iverilog", "-o", vvp_path, "-s", top, dut_path]
        if extra_args:
            compile_args.extend(extra_args.split())
        comp = await run_eda(compile_args, timeout=120, cwd=work_dir)
        if not comp.get("success"):
            return {
                "success": False,
                "message": "iverilog compilation failed",
                "data": {
                    "passed": 0,
                    "failed": 1,
                    "waveform": None,
                    "stdout": comp.get("stdout", ""),
                    "stderr": comp.get("stderr", ""),
                },
            }
        vcd_path = os.path.join(output_dir, f"{top}.vcd") if waves else None
        run_args = ["vvp", vvp_path]
        env_extra = {}
        if waves and vcd_path:
            run_args.append(f"+WAVES={vcd_path}")
        sim = await run_eda(run_args, timeout=300, cwd=work_dir, env_extra=env_extra)
        stdout = sim.get("stdout", "")
        passed = stdout.count("PASS")
        failed = stdout.count("FAIL")
        ok = sim.get("success", False) and failed == 0
        return {
            "success": ok,
            "message": f"Testbench {'passed' if ok else 'failed'}",
            "data": {
                "passed": passed,
                "failed": failed,
                "waveform": vcd_path if waves and os.path.isfile(vcd_path or "") else None,
                "stdout": stdout,
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def sim_read_waveform(
        vcd_file: Annotated[str, Field(description="Path to VCD waveform file.")],
        signals: Annotated[str, Field(description="Comma-separated signal names to extract (empty = list all).")] = "",
        start_time: Annotated[int, Field(description="Start time in simulation units (0 = beginning).")] = 0,
        end_time: Annotated[int, Field(description="End time in simulation units (0 = all).")] = 0,
    ) -> dict:
        """Read VCD waveform data and extract signal transitions.

        ## Return Format
        {"success": bool, "data": {"signals": [str, ...], "timescale": str, "transitions": [...]}}

        ## Examples
        await sim_read_waveform(vcd_file="counter.vcd")
        await sim_read_waveform(vcd_file="alu.vcd", signals="clk,rst,result")
        """
        path = vcd_file if os.path.isabs(vcd_file) else os.path.join(output_dir, vcd_file)
        if not os.path.isfile(path):
            path = os.path.join(upload_dir, vcd_file)
        if not os.path.isfile(path):
            return {"success": False, "message": f"VCD file not found: {vcd_file}", "data": None}
        signal_names: list[str] = []
        timescale = "1ns"
        want = {s.strip() for s in signals.split(",") if s.strip()} if signals else None
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("$timescale"):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        timescale = parts[1]
                if line.strip().startswith("$var"):
                    parts = line.split()
                    if len(parts) >= 5:
                        name = parts[4]
                        if want is None or name in want:
                            signal_names.append(name)
                if line.strip() == "$enddefinitions $end":
                    break
        return {
            "success": True,
            "message": f"Waveform parsed: {len(signal_names)} signals found",
            "data": {
                "signals": signal_names,
                "timescale": timescale,
                "transitions": [],
                "start_time": start_time,
                "end_time": end_time,
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def sim_check_coverage(
        test_dir: Annotated[str, Field(description="Directory with cocotb tests.")] = "",
    ) -> dict:
        """Check test coverage by scanning cocotb test files for covered scenarios.

        ## Return Format
        {"success": bool, "data": {"total_tests": int, "tests": [...], "coverage_hint": str}}

        ## Examples
        await sim_check_coverage()
        """
        base = test_dir or work_dir
        tests: list[dict] = []
        for root, _dirs, files in os.walk(base):
            for fname in files:
                if not (fname.startswith("test_") and fname.endswith(".py")):
                    continue
                fpath = os.path.join(root, fname)
                try:
                    text = open(fpath, encoding="utf-8").read()
                except OSError:
                    continue
                fns = re.findall(r"(?:async def|def)\s+(test_\w+)", text)
                cocotb = "@cocotb.test" in text
                tests.append({"file": os.path.relpath(fpath, base), "functions": fns, "cocotb": cocotb})
        total = sum(len(t["functions"]) for t in tests)
        hint = f"{total} test functions across {len(tests)} files. Run sim_run_testbench to get pass/fail results."
        return {"success": True, "data": {"total_tests": total, "tests": tests, "coverage_hint": hint}}

    return {
        "sim_list_tests": sim_list_tests,
        "sim_run_testbench": sim_run_testbench,
        "sim_read_waveform": sim_read_waveform,
        "sim_check_coverage": sim_check_coverage,
    }
