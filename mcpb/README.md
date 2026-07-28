# chip-design-mcp (MCPB Bundle)

MCP server and React webapp for open-source chip design: Verilog hardware description, Yosys synthesis, simulation, optional OpenLane layout (GDSII). REST :11022, dashboard :11023.

## Usage

Add to \claude_desktop_config.json\:
\\\json
{
  "mcpServers": {
    "chip-design-mcp": {
      "command": "uv",
      "args": ["run", "--directory", "\D:\Dev\repos", "python", "-m", "chip_design_mcp"],
      "env": { "PYTHONPATH": "\D:\Dev\repos/src" }
    }
  }
}
\\\

## Tools

- **get_logs**: get_logs
- **clear_logs**: clear_logs
- **export_logs**: export_logs
- **chip_status**: chip_status
- **chip_pipeline_stages**: chip_pipeline_stages
- **chip_available_pdks**: chip_available_pdks
- **api_status**: api_status
- **api_list_tools**: api_list_tools
- **api_control_tool**: Dispatch REST calls to registered MCP tools by name.
- **api_capabilities**: api_capabilities
- **well_known_manifest**: well_known_manifest
- **api_help_index**: api_help_index
- **api_help_slug**: api_help_slug
- **api_tools_detail**: Tool catalog with domain prefix and first docstring line.
- **api_fleet_scan**: Bounded port scan for fleet MCP servers (10700-11100).
- **api_llm_status**: Detect local LLM (Ollama 11434 / LM Studio 1234).
- **api_llm_chat**: Proxy chat to detected local LLM (Ollama or LM Studio).
- **api_chiplab_presets**: api_chiplab_presets
- **api_chiplab_workflows**: api_chiplab_workflows
- **api_chiplab_workflow**: api_chiplab_workflow
- **api_chiplab_create_workflow**: api_chiplab_create_workflow
- **api_chiplab_assist**: api_chiplab_assist
- **api_upload**: api_upload
- **api_list_files**: api_list_files
- **api_download**: api_download
- **chip_agentic**: chip_agentic
- **register_agentic_chip_tools_natural_query**: register_agentic_chip_tools(natural_query)
- **register_agentic_chip_tools_flow_plan**: register_agentic_chip_tools(flow_plan)
- **register_agentic_chip_tools_status_summary**: register_agentic_chip_tools(status_summary)
- **depot_init**: depot_init
- **depot_list**: depot_list
- **depot_status**: depot_status
- **_rtl_counter_counter**: _rtl_counter(counter)
- **_rtl_counter_alu**: _rtl_counter(alu)
- **_rtl_counter_fsm**: _rtl_counter(fsm)
- **_rtl_counter_empty**: _rtl_counter(empty)
- **pr_status**: pr_status
- **pr_create_design**: pr_create_design
- **pr_configure**: pr_configure
- **pr_run_flow**: pr_run_flow
- **pr_read_reports**: pr_read_reports
- **pr_export_gds**: pr_export_gds
- **pr_export_lef**: pr_export_lef
- **register_place_route_tools_synthesis**: register_place_route_tools(synthesis)
- **register_place_route_tools_floorplan**: register_place_route_tools(floorplan)
- **register_place_route_tools_placement**: register_place_route_tools(placement)
- **register_place_route_tools_cts**: register_place_route_tools(cts)
- **register_place_route_tools_routing**: register_place_route_tools(routing)
- **register_place_route_tools_signoff**: register_place_route_tools(signoff)
- **show_chip_status_card**: show_chip_status_card
- **show_pdks_card**: show_pdks_card
- **show_pipeline_card**: show_pipeline_card
- **show_depot_card**: show_depot_card
- **show_cells_stats_card**: show_cells_stats_card
- **show_cells_list_card**: show_cells_list_card
- **sim_list_tests**: sim_list_tests
- **sim_run_testbench**: sim_run_testbench
- **sim_read_waveform**: sim_read_waveform
- **sim_check_coverage**: sim_check_coverage
- **cells_list**: cells_list
- **cells_info**: cells_info
- **cells_search**: cells_search
- **cells_stats**: cells_stats
- **_classify_cell_buffer**: _classify_cell(buffer)
- **_classify_cell_inverter**: _classify_cell(inverter)
- **_classify_cell_and**: _classify_cell(and)
- **_classify_cell_or**: _classify_cell(or)
- **_classify_cell_nand**: _classify_cell(nand)
- **_classify_cell_nor**: _classify_cell(nor)
- **_classify_cell_xor**: _classify_cell(xor)
- **_classify_cell_mux**: _classify_cell(mux)
- **_classify_cell_dff**: _classify_cell(dff)
- **_classify_cell_latch**: _classify_cell(latch)
- **_classify_cell_adder**: _classify_cell(adder)
- **_classify_cell_all**: _classify_cell(all)
- **syn_status**: syn_status
- **syn_read_verilog**: syn_read_verilog
- **syn_run**: syn_run
- **syn_stats**: syn_stats
- **syn_show**: syn_show
- **syn_export_netlist**: syn_export_netlist
- **register_synthesis_tools_dot**: register_synthesis_tools(dot)
- **register_synthesis_tools_svg**: register_synthesis_tools(svg)
- **register_synthesis_tools_pdf**: register_synthesis_tools(pdf)
- **verify_drc**: verify_drc
- **verify_lvs**: verify_lvs
- **verify_timing**: verify_timing
- **verify_formal**: verify_formal

## Requirements

- Python 3.12+
- uv
