"""Agentic chip-design workflows via FastMCP 3.2 sampling (SEP-1577)."""

from __future__ import annotations

from typing import Annotated, Any, Literal

from fastmcp import Context
from pydantic import Field

_TOOL_CATALOG = """
Domains: synthesis (syn_*), simulation (sim_*), place_route (pr_*), verification (verify_*),
standard_cells (cells_*), depot (depot_*), system (chip_status, chip_pipeline_stages, chip_available_pdks).
Start with chip_status and depot_init before long OpenLane runs.
"""


def register_agentic_chip_tools(mcp, all_tools: dict, state: dict):
    """Register chip_agentic — host LLM sampling for flow planning and Q&A."""

    @mcp.tool(version="0.1.0", annotations={"readOnlyHint": True})
    async def chip_agentic(
        operation: Annotated[
            Literal["natural_query", "flow_plan", "status_summary"],
            Field(description="natural_query: Q&A; flow_plan: RTL-to-GDSII steps; status_summary: EDA/PDK snapshot."),
        ],
        prompt: Annotated[
            str | None,
            Field(description="User goal or question (required for natural_query and flow_plan)."),
        ] = None,
        ctx: Context = None,
    ) -> dict[str, Any]:
        """LLM-assisted chip design orchestration using MCP sampling when available.

        ## Return Format
        {"success": bool, "operation": str, "message": str, "data": dict | None, "steps": list | None}

        ## Examples
        - chip_agentic(operation="status_summary")
        - chip_agentic(operation="flow_plan", prompt="Counter on sky130, sim then OpenLane")
        - chip_agentic(operation="natural_query", prompt="Which tools do I need for DRC only?")
        """
        if operation == "status_summary":
            status_fn = all_tools.get("chip_status")
            if not status_fn:
                return {"success": False, "operation": operation, "message": "chip_status not registered", "data": None}
            data = await status_fn()
            ready = sum(1 for v in (data.get("tools") or {}).values() if v)
            total = len(data.get("tools") or {})
            msg = (
                f"EDA tools: {ready}/{total} available. "
                f"PDK installed: {data.get('pdk_installed')}. "
                f"Work dir: {data.get('work_dir')}."
            )
            return {"success": True, "operation": operation, "message": msg, "data": data, "steps": None}

        if operation in ("natural_query", "flow_plan") and not prompt:
            return {
                "success": False,
                "operation": operation,
                "message": "prompt is required for natural_query and flow_plan",
                "data": None,
            }

        if ctx is None:
            return {
                "success": False,
                "operation": operation,
                "message": "MCP Context required — enable sampling on the host or use chip_status / chip_pipeline_stages directly",
                "data": None,
                "suggestions": [
                    "Call chip_status and chip_pipeline_stages without sampling",
                    "Use the webapp at http://localhost:11023 for guided flows",
                ],
            }

        if operation == "flow_plan":
            step = await ctx.sample_step(
                prompt=(
                    "You are an open-source ASIC flow engineer (Yosys, cocotb, OpenLane, Magic, sky130). "
                    f"Plan ordered tool calls for: {prompt}\n{_TOOL_CATALOG}"
                ),
                max_steps=6,
            )
            return {
                "success": True,
                "operation": operation,
                "message": "Flow plan generated via sampling",
                "data": {"prompt": prompt},
                "steps": [step] if step is not None else [],
            }

        res = await ctx.sample(
            messages=[
                {
                    "role": "user",
                    "content": (
                        "Answer as a chip-design MCP assistant. Be concise. "
                        f"Question: {prompt}\n\nTool catalog:\n{_TOOL_CATALOG}\n\n"
                        f"Current state keys: {list(state.keys())}"
                    ),
                }
            ],
            max_tokens=2048,
        )
        text = getattr(res, "text", None) or str(res)
        return {
            "success": True,
            "operation": operation,
            "message": text,
            "data": {"prompt": prompt},
            "steps": None,
        }

    return {"chip_agentic": chip_agentic}
