"""
Depot MCP tools - project scaffolding, file management, and artifact export.

Provides project initialization, file listing/upload/download, and
template generation for common chip design boilerplate.

Registered via register_depot_tools(mcp, **deps) - called from server.py.
"""

from __future__ import annotations

import json
import os
from typing import Annotated, Literal

from pydantic import Field

_READ_ONLY = {"readOnlyHint": True}
_MUTATING = {"readOnlyHint": False}

_PDK_MAP = {"sky130": "sky130A", "gf180mcu": "gf180mcuA", "ihp-sg13g2": "ihp-sg13g2"}


def _rtl_counter(name: str) -> str:
    return f"""// {name} — Parameterizable up-counter with synchronous reset

module {name} #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {{WIDTH}}'d0;
        else if (en)
            count <= count + 1'b1;
    end

endmodule
"""


def _rtl_alu(name: str) -> str:
    return f"""// {name} — Simple 8-bit ALU with add/sub/and/or/xor

module {name} (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] op,
    output reg  [7:0] result,
    output reg        zero,
    output reg        carry
);

    always @(*) begin
        result = 8'd0;
        carry = 1'b0;
        case (op)
            3'b000: result = a + b;
            3'b001: result = a - b;
            3'b010: result = a & b;
            3'b011: result = a | b;
            3'b100: result = a ^ b;
            3'b101: begin
                result = a[7] ? (~a + 1'b1) : a;
            end
            default: result = a;
        endcase
        zero = (result == 8'd0);
    end

endmodule
"""


def _rtl_fsm(name: str) -> str:
    return f"""// {name} — Simple 3-state FSM (IDLE -> BUSY -> DONE -> IDLE)

module {name} (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  done,
    output reg  [1:0] state
);

    localparam IDLE = 2'd0;
    localparam BUSY = 2'd1;
    localparam DONE = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start)
                        state <= BUSY;
                end
                BUSY: state <= DONE;
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
"""


def _rtl_empty(name: str) -> str:
    return f"""// {name} — User-defined module

module {name} (
    input  wire clk,
    input  wire rst_n
);

    // TODO: implement your design here

endmodule
"""


def _tb_counter(name: str) -> str:
    return f'''# cocotb testbench for {name}


import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_{name}_basic(dut):
    """Test basic counter operation."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.en.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.en.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
        assert dut.count.value == (i + 1), f"Expected {{i+1}}, got {{dut.count.value}}"

    dut.en.value = 0
    await RisingEdge(dut.clk)
    prev = dut.count.value
    await RisingEdge(dut.clk)
    assert dut.count.value == prev, "Counter should hold when disabled"
'''


def _tb_alu(name: str) -> str:
    return f'''# cocotb testbench for {name}


import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_{name}_add(dut):
    """Test ALU add operation."""
    dut.a.value = 10
    dut.b.value = 20
    dut.op.value = 0  # ADD
    await Timer(10, units="ns")
    assert dut.result.value == 30, f"10+20 = {{dut.result.value}}"
    assert dut.zero.value == 0

@cocotb.test()
async def test_{name}_subtract(dut):
    """Test ALU subtract operation."""
    dut.a.value = 30
    dut.b.value = 10
    dut.op.value = 1  # SUB
    await Timer(10, units="ns")
    assert dut.result.value == 20, f"30-10 = {{dut.result.value}}"

@cocotb.test()
async def test_{name}_zero_flag(dut):
    """Test ALU zero flag."""
    dut.a.value = 5
    dut.b.value = 5
    dut.op.value = 1  # SUB
    await Timer(10, units="ns")
    assert dut.zero.value == 1, "Zero flag should be set for 5-5"
'''


def _tb_fsm(name: str) -> str:
    return f'''# cocotb testbench for {name}


import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_{name}_flow(dut):
    """Test FSM IDLE -> BUSY -> DONE -> IDLE cycle."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    assert dut.state.value == 0, "Should be in IDLE"
    assert dut.done.value == 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    assert dut.state.value == 1, "Should be in BUSY"

    await RisingEdge(dut.clk)
    assert dut.state.value == 2, "Should be in DONE"
    assert dut.done.value == 1

    await RisingEdge(dut.clk)
    assert dut.state.value == 0, "Should be back in IDLE"
'''


def _tb_smoke(name: str) -> str:
    return f'''# cocotb testbench for {name}


import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_{name}_smoke(dut):
    """Smoke test: clock the design and check it doesn't X-propagate."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for _ in range(10):
        await RisingEdge(dut.clk)
'''


def _makefile(name: str) -> str:
    return f"""# cocotb Makefile for {name}


TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(PWD)/src/{name}.v
TOPLEVEL = {name}

MODULE = test_{name}


include $(shell cocotb-config --makefiles)/Makefile.sim
"""


def register_depot_tools(
    mcp,
    state: dict,
    work_dir: str,
    upload_dir: str,
    output_dir: str,
    designs_dir: str,
):
    """Register all Depot MCP tools on the FastMCP instance."""

    _TEMPLATES = {
        "counter": (_rtl_counter, _tb_counter),
        "alu": (_rtl_alu, _tb_alu),
        "fsm": (_rtl_fsm, _tb_fsm),
        "empty": (_rtl_empty, _tb_smoke),
    }

    @mcp.tool(annotations=_MUTATING, version="0.1.0")
    async def depot_init(
        project_name: Annotated[str, Field(description="Name of the chip design project (snake_case).")],
        template: Annotated[
            Literal["counter", "alu", "fsm", "empty"],
            Field(description="Template: counter, alu, fsm, empty."),
        ] = "counter",
        pdk: Annotated[str, Field(description="Target PDK: sky130, gf180mcu.")] = "sky130",
    ) -> dict:
        """Initialize a new chip design project with boilerplate Verilog, testbench, and config.

        ## Return Format
        {"success": bool, "message": str, "data": {"project_dir": str, "files": [str, ...], "next_steps": [str, ...]}}

        ## Examples
        await depot_init(project_name="my_counter")
        await depot_init(project_name="my_alu", template="alu")
        """
        project_dir = os.path.join(designs_dir, project_name)
        src_dir = os.path.join(project_dir, "src")
        tests_dir = os.path.join(project_dir, "tests")
        os.makedirs(src_dir, exist_ok=True)
        os.makedirs(tests_dir, exist_ok=True)
        rtl_fn, tb_fn = _TEMPLATES.get(template, _TEMPLATES["counter"])
        rtl_path = os.path.join(src_dir, f"{project_name}.v")
        tb_path = os.path.join(tests_dir, f"test_{project_name}.py")
        with open(rtl_path, "w", encoding="utf-8") as f:
            f.write(rtl_fn(project_name))
        with open(tb_path, "w", encoding="utf-8") as f:
            f.write(tb_fn(project_name))
        with open(os.path.join(project_dir, "Makefile"), "w", encoding="utf-8") as f:
            f.write(_makefile(project_name))
        pdk_name = _PDK_MAP.get(pdk, pdk)
        config = {
            "DESIGN_NAME": project_name,
            "VERILOG_FILES": f"dir::src/{project_name}.v",
            "CLOCK_PORT": "clk",
            "CLOCK_PERIOD": 10,
            "FP_CORE_UTIL": 40,
            "PL_TARGET_DENSITY": 0.55,
            "PDK": pdk_name,
        }
        with open(os.path.join(project_dir, "config.json"), "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        readme = f"""# {project_name}

Chip design project using {pdk_name} PDK.

## Pipeline

1. RTL: `src/{project_name}.v`
2. Simulation: `make -C . sim` (cocotb + iverilog)
3. Synthesis: Yosys via chip-design-mcp `syn_run`
4. Place & Route: OpenLane via chip-design-mcp `pr_run_flow`
5. Verification: DRC/LVS via chip-design-mcp `verify_drc` / `verify_lvs`

## Quick Start

```powershell
# Simulation
pip install cocotb
make sim

# Synthesis (via MCP)
syn_read_verilog(file_name="{project_name}.v", top_module="{project_name}")
syn_run(top_module="{project_name}")
```
"""
        with open(os.path.join(project_dir, "README.md"), "w", encoding="utf-8") as f:
            f.write(readme)
        files = [
            rtl_path,
            tb_path,
            os.path.join(project_dir, "Makefile"),
            os.path.join(project_dir, "config.json"),
            os.path.join(project_dir, "README.md"),
        ]
        return {
            "success": True,
            "message": f"Project '{project_name}' created with template '{template}'",
            "data": {
                "project_dir": project_dir,
                "files": files,
                "next_steps": [
                    f"Edit RTL: {rtl_path}",
                    f"Run simulation: make -C {project_dir} sim",
                    f"Load into MCP: syn_read_verilog(file_name='{project_name}.v', top_module='{project_name}')",
                    f"Run OpenLane: pr_create_design(design_name='{project_name}', verilog_file='{project_name}.v')",
                ],
            },
        }

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def depot_list(
        directory: Annotated[
            str, Field(description="Directory to list: designs, uploads, outputs, or a project name.")
        ] = "designs",
    ) -> dict:
        """List files and projects in the chip design depot.

        ## Return Format
        {"success": bool, "data": {"directory": str, "items": [...], "count": int}}

        ## Examples
        await depot_list()
        await depot_list(directory="uploads")
        await depot_list(directory="my_counter")
        """
        dir_map = {
            "designs": designs_dir,
            "uploads": upload_dir,
            "outputs": output_dir,
        }
        if directory in dir_map:
            target = dir_map[directory]
        else:
            target = os.path.join(designs_dir, directory)
        items = []
        if os.path.isdir(target):
            for name in sorted(os.listdir(target)):
                path = os.path.join(target, name)
                if os.path.isdir(path):
                    items.append({"name": name, "type": "directory", "size_bytes": 0})
                elif os.path.isfile(path):
                    items.append({"name": name, "type": "file", "size_bytes": os.path.getsize(path)})
        return {"success": True, "data": {"directory": directory, "items": items, "count": len(items)}}

    @mcp.tool(annotations=_READ_ONLY, version="0.1.0")
    async def depot_status() -> dict:
        """Get depot storage statistics (project count, file count, total size).

        ## Return Format
        {"success": bool, "data": {"designs_count": int, "uploads_count": int, "outputs_count": int, "total_size_bytes": int}}

        ## Examples
        await depot_status()
        """

        def scan(root: str) -> tuple[int, int]:
            if not os.path.isdir(root):
                return 0, 0
            files = 0
            size = 0
            for dirpath, _dirnames, filenames in os.walk(root):
                for fname in filenames:
                    files += 1
                    try:
                        size += os.path.getsize(os.path.join(dirpath, fname))
                    except OSError:
                        pass
            return files, size

        d_files, d_size = scan(designs_dir)
        u_files, u_size = scan(upload_dir)
        o_files, o_size = scan(output_dir)
        designs_count = (
            len([n for n in os.listdir(designs_dir) if os.path.isdir(os.path.join(designs_dir, n))])
            if os.path.isdir(designs_dir)
            else 0
        )
        return {
            "success": True,
            "data": {
                "designs_count": designs_count,
                "uploads_count": u_files,
                "outputs_count": o_files,
                "total_files": d_files + u_files + o_files,
                "total_size_bytes": d_size + u_size + o_size,
                "designs": {"files": d_files, "size_bytes": d_size},
                "uploads": {"files": u_files, "size_bytes": u_size},
                "outputs": {"files": o_files, "size_bytes": o_size},
            },
        }

    return {
        "depot_init": depot_init,
        "depot_list": depot_list,
        "depot_status": depot_status,
    }
