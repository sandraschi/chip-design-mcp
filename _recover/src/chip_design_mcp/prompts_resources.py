"""FastMCP 3.2 prompts and resources for chip-design-mcp."""

from fastmcp.prompts import Message


def register_prompts_and_resources(mcp) -> None:
    """Register @mcp.prompt and @mcp.resource handlers on the shared FastMCP instance."""

    @mcp.resource("resource://chip-design/quickstart")
    def chip_design_quickstart() -> str:
        return """# chip-design-mcp Quickstart

1. chip_status — EDA binaries and PDK on PATH / PDK_ROOT
2. chip_available_pdks — sky130, gf180mcu, ihp-sg13g2
3. depot_init — scaffold RTL + cocotb project
4. sim_run_testbench — verify RTL
5. syn_read_verilog → syn_run → syn_stats — Yosys synthesis
6. pr_create_design → pr_configure → pr_run_flow — OpenLane (Docker or native)
7. verify_drc / verify_lvs / verify_timing — signoff
8. pr_export_gds — GDSII output

Backend http://127.0.0.1:11022/mcp — Webapp http://127.0.0.1:11023
Skill: skill://chip-design-expert/SKILL.md
"""

    @mcp.prompt()
    def chip_rtl_flow_guide() -> list[Message]:
        """Starter prompt for RTL-to-GDSII on open PDKs."""
        return [
            Message(
                "Use chip_status first, then depot_init. Run simulation before OpenLane. "
                "For sky130 use volare; prefer Docker OpenLane if native openlane is missing. "
                "List tools via GET /api/v1/tools or chip_pipeline_stages.",
                role="user",
            )
        ]

    @mcp.prompt()
    def chip_openlane_checklist() -> list[Message]:
        """Pre-flight checklist before a long OpenLane run."""
        return [
            Message(
                "Before pr_run_flow: confirm pr_status (docker or native), PDK_ROOT set, "
                "pr_create_design + pr_configure done, and RTL simulated. "
                "OpenLane Docker image is large — allow time for first pull.",
                role="user",
            )
        ]
