# chip-design-mcp: Comprehensive User Guide and Workflow Manual

Welcome to the Chip Design MCP ecosystem. This guide provides step-by-step instructions for designing ASICs from RTL to GDSII using open-source tools through natural language commands via your MCP client. Whether you are a student learning chip design, a researcher prototyping a custom accelerator, or an engineer taping out a production chip this guide covers the complete open-source ASIC flow orchestrated through chip-design-mcp.

## 1. Quick Start: Environment Verification

The fastest way to verify your setup is to check what EDA tools are available on your system.

"What EDA tools are available for chip design on this system?"

The server calls chip_status which probes PATH for yosys, iverilog, openlane, docker, magic, netgen, sta, and volare. It also checks PDK_ROOT for installed process design kits. The response shows each tool with a green checkmark (available) or red X (not installed). If no tools are installed the server still returns success with all tools showing unavailable -- each tool will give clear installation guidance when called.

## 2. Tutorial 1: Writing and Simulating RTL

Goal: Write a simple Verilog counter module and verify it with a test bench.

Step 1: Upload your Verilog file using depot_init to ensure the directory structure exists: depot_init(). Step 2: Write a counter module. The RTL should be placed in the work directory. Step 3: Write a test bench. Step 4: List available test benches: sim_list_tests. Step 5: Run the simulation: sim_run_testbench top_module="counter" testbench="counter_tb.v" waves=true. This compiles the RTL and test bench with iverilog, runs the simulation, and generates a VCD waveform file if requested. Step 6: Check the result: the tool returns pass/fail status and simulation log. Step 7: Read the waveform: sim_read_waveform vcd_path="counter.vcd" signals=["counter.clk", "counter.out", "counter.rst"]. This returns signal transitions in a structured table format. Step 8: Check coverage: sim_check_coverage to see line and toggle coverage metrics.

## 3. Tutorial 2: Synthesizing RTL to Gates

Goal: Synthesize an RTL design to a gate-level netlist targeting the Sky130 PDK.

Step 1: Read your Verilog source: syn_read_verilog filename="counter.v". This loads the file into the synthesis state. Step 2: Run synthesis: syn_run top_module="counter" target="sky130". This executes Yosys with a standard synthesis script that reads the Verilog, performs logic optimization, technology mapping to the Sky130 standard cell library, and outputs a gate-level netlist. Step 3: Check synthesis statistics: syn_stats. Returns cell count by type (DFF, AND, OR, MUX, etc.), estimated area in square microns, and number of wires. A simple counter should synthesize to about 20-30 cells for an 8-bit counter. Step 4: View the synthesis graph: syn_show. Returns the DOT representation of the synthesized netlist showing the cell-level connectivity. Step 5: Export the netlist: syn_export_netlist output_filename="counter_synth.v" format="verilog". The synthesized netlist can now be used for place-and-route or formal verification.

Synthesis parameters: top_module is the Verilog module name to synthesize. target selects the technology library (sky130, gf180mcu, or generic). flatten=true collapses all hierarchy. retime=true enables sequential optimization (moving flip-flops across logic). extra_yosys_cmds allows passing custom Yosys TCL commands for advanced synthesis flows.

## 4. Tutorial 3: Full RTL-to-GDSII Flow with OpenLane

Goal: Take a synthesized design through place-and-route to generate GDSII.

Step 1: Create an OpenLane design: pr_create_design design_name="my_counter" top_module="counter" pdk="sky130" clock_period_ns="20". This creates the design directory structure under DESIGNS_DIR with config.tcl. Step 2: Configure floorplan parameters: pr_configure design_name="my_counter" config_updates={"FP_CORE_UTIL": 40, "DIE_AREA": "0 0 100 100"}. FP_CORE_UTIL controls core utilization (percentage), DIE_AREA sets the die dimensions in microns. Step 3: Run the full flow: pr_run_flow design_name="my_counter" stages="synthesis,floorplan,placement,cts,routing,production" timeout_seconds=3600. This runs OpenLane via Docker. The flow time depends on design size -- a simple counter takes 5-10 minutes, a 10k-cell design takes 30-60 minutes, a 100k-cell design takes several hours. Step 4: Read the reports: pr_read_reports design_name="my_counter" report_types=["area", "timing", "power"]. This parses OpenLane reports and returns structured data including total area, worst slack, and estimated power. Step 5: Export the GDSII: pr_export_gds design_name="my_counter". The GDSII file is the final chip layout ready for manufacturing.

OpenLane runs inside Docker (ghcr.io/the-openroad-project/openlane:latest). The timeout should be generous (3600 seconds default). The server reports progress via stdout logs that can be viewed by checking the tool response. For production flows run stages incrementally to validate each step before proceeding.

## 5. Tutorial 4: Design Rule Checking (DRC)

Goal: Run DRC on a completed layout to verify it is manufacturable.

Step 1: Ensure the design has completed place-and-route. Step 2: Run DRC: verify_drc design_name="my_counter" pdk="sky130". This runs Magic DRC on the GDS file and checks against Sky130 design rules. Step 3: Review the results: the tool returns the violation count and lists violation types (width violations, spacing violations, enclosure violations). Step 4: If violations exist, review the Magic output logs for specific coordinates and rule descriptions. Step 5: Fix violations by adjusting OpenLane configuration (increase cell spacing, adjust metal layer configuration) and re-running the flow. Step 6: Re-run DRC to confirm zero violations.

DRC is typically run as part of the OpenLane signoff stage but can be run independently on any GDS file. The server parses Magic DRC output for violation counts but full DRC database exploration requires the Magic GUI.

## 6. Tutorial 5: Layout vs. Schematic (LVS)

Goal: Verify that the physical layout matches the synthesized netlist.

Step 1: After completing place-and-route and DRC, run LVS: verify_lvs design_name="my_counter" pdk="sky130". Step 2: This runs netgen comparing the layout-extracted netlist (from Magic using the GDS and LEF files) against the synthesized Verilog netlist. Step 3: Review the results: the tool returns a comparison count (number of netlist comparisons) and pass/fail status. Step 4: If LVS fails, check for cell mismatches, missing connections, or shorted nets. Step 5: Common causes of LVS failures include power grid errors, floating pins, and incorrect cell footprint selection.

## 7. Tutorial 6: Static Timing Analysis (STA)

Goal: Verify the design meets timing constraints at the target clock frequency.

Step 1: Ensure the design has been synthesized. Step 2: Run timing analysis: verify_timing top_module="counter" liberty_file="sky130_fd_sc_hd__ff_100C_1v95.lib". The liberty file path depends on your PDK installation. Step 3: Review results: the tool returns slack values for setup and hold timing paths, critical path delay, and frequency limits. Step 4: If timing is not met (negative slack), consider: reducing clock frequency, adding pipeline stages, using higher-drive cells, or adjusting synthesis retiming. Step 5: Re-run synthesis and place-and-route with improved constraints. Step 6: Re-verify timing.

## 7. Tutorial 7: Formal Equivalence Checking

Goal: Verify that a revised RTL implementation is functionally equivalent to a golden reference.

Step 1: Write your golden Verilog model and the revised implementation. Step 2: Run formal verification: verify_formal golden_model="counter_golden.v" revised_model="counter_opt.v" top_module="counter". This uses Yosys SAT-based formal verification to prove equivalence. Step 3: Review results: if successful the designs are proven equivalent. If there are counterexamples the tool reports mismatching signal assignments. Step 4: Debug counterexamples by examining the SAT solver output showing input vectors that produce different outputs.

## 8. Tutorial 8: Standard Cell Library Exploration

Goal: Explore and understand the available standard cells in your PDK.

Step 1: List available cells: cells_list pdk="sky130". Returns thousands of cells grouped by type (DFF, AND, OR, AOI, OAI, MUX, XOR, etc.). Step 2: Get detailed cell info: cells_info cell_name="sky130_fd_sc_hd__dfxtp_1". Returns port list (D, CLK, Q), area in square microns, leakage power, and timing arcs (setup time, hold time, clock-to-Q delay). Step 3: Search for specific cell types: cells_search query="dff" pdk="sky130". Step 4: Get library statistics: cells_stats pdk="sky130". Shows total cell count, cell type distribution, and drive strength range.

## 9. Tutorial 9: Agentic Chip Design Workflow

Goal: Use AI-assisted planning for a multi-step chip design task.

Step 1: Get a flow plan: chip_agentic operation="flow_plan" prompt="Write an 8-bit counter in Verilog, synthesize it for Sky130, run simulation with a test bench, and generate a floorplan". This uses MCP sampling to create a step-by-step plan. Step 2: Ask natural language questions: chip_agentic operation="natural_query" prompt="What is the difference between synthesis and place-and-route?" Step 3: Get a status summary: chip_agentic operation="status_summary". Provides a conversational overview of the current design state. Step 4: Follow the generated plan by calling individual synthesis, simulation, and place-and-route tools with the parameters suggested by the agentic plan.

Agentic tools require a sampling-capable MCP client (Claude Desktop, Cursor). They use ctx.sample() for LLM-powered reasoning. Without sampling support they return a clear error message.

## 10. Tutorial 10: Working with Chiplab Presets

Goal: Use pre-configured Chiplab workflow presets for rapid design iteration.

Step 1: List available Chiplab presets via the REST API: GET /api/v1/chiplab/presets. Returns preset names with descriptions and pipeline configurations. Step 2: Create a workflow from a preset: POST /api/v1/chiplab/workflows with body {"preset_id": "counter_sky130", "auto_start": true}. This creates and optionally starts executing a complete chip design workflow. Step 3: Monitor workflow progress via GET /api/v1/chiplab/workflows/{workflow_id}. Step 4: Use Chiplab assist for AI-guided workflow creation: POST /api/v1/chiplab/assist with body {"operation": "chat", "prompt": "Create a 32-bit RISC-V core flow"}. Step 5: Chiplab manages the workflow lifecycle including stage dependencies, parallel execution where safe, and result collection.

## 11. Configuration Reference

Work directory: Set CHIP_DESIGN_MCP_WORK_DIR to a path with at least 10GB free space for OpenLane runs. PDK root: Set PDK_ROOT to your PDK installation directory. Install Sky130 PDK with: volare enable --pdk sky130 0a6b2e3. EDA tools: Install via package managers: conda install -c litex-hub yosys iverilog, or Docker for OpenLane. Docker is recommended for OpenLane as it includes all dependencies. The server auto-detects tools on PATH but explicit paths can be configured.

## 12. Troubleshooting

Tool not found: Install the missing EDA tool. Yosys and Iverilog can be installed via conda or compiled from source. OpenLane requires Docker. Magic and Netgen can be compiled from source or installed via package managers. OpenSTA (sta) can be compiled from source or installed via conda. PDK not found: Install Sky130 PDK using volare enable --pdk sky130. Set PDK_ROOT to the volare installation directory. The typical path is ~/.volare/sky130_0a6b2e3. Docker not working: Ensure Docker Desktop is running. Check that the OpenLane image has been pulled: docker pull ghcr.io/the-open-road-project/openlane:latest. For native OpenLane without Docker install openlane on PATH. OpenLane run fails: Check disk space (at least 5GB free). Check that the design directory was created correctly with pr_create_design. Check OpenLane logs in the design directory for specific error messages. GDS output not found: Ensure the full flow completed (all stages including production). Check pr_status for design completion status.

## 13. Working with the REST API and Web Dashboard

The chip-design-mcp server exposes a comprehensive REST API on port 11022 alongside the MCP tool surface. The web dashboard on port 11023 provides a visual interface for monitoring and managing chip design flows.

API endpoints: GET /api/v1/status returns server version, EDA tool availability, PDK status, and work directory paths. GET /api/v1/tools returns the list of all registered MCP tool names. POST /api/v1/control/{tool_name} dispatches a tool call with parameters in the JSON request body -- this enables REST clients to call any MCP tool. GET /api/capabilities returns server feature announcements including Prefab Apps status, sampling support, skills, prompts, and help documentation slugs. GET /.well-known/mcp/manifest.json returns the fleet manifest. GET /api/v1/help/{slug} returns markdown documentation for the specified help topic (available slugs: synthesis, simulation, place_route, verification, standard_cells, depot, prefab, architecture, configuration, development, troubleshooting, pdk, foss-eda-ecosystem, foss-rtl-sources, dreaming-in-silicon, tools-index, install, production, mini_fab, fabrication). GET /api/v1/fleet performs a bounded port scan across 10700-11100 to discover other active fleet MCP servers. POST /api/v1/upload accepts file uploads for RTL source code and design files. GET /api/v1/list lists files in the uploads, outputs, or designs directories. GET /api/v1/download/{file_name} downloads a file from the outputs directory.

LLM integration endpoints: GET /api/v1/llm/status probes Ollama (port 11434) and LM Studio (port 1234) for local LLM availability. POST /api/v1/llm/chat proxies chat messages to the detected local LLM for conversational chip design assistance.

Chiplab endpoints: GET /api/v1/chiplab/presets lists available workflow presets. GET /api/v1/chiplab/workflows lists active workflows. GET /api/v1/chiplab/workflows/{id} gets workflow details. POST /api/v1/chiplab/workflows creates a new workflow from a preset. POST /api/v1/chiplab/assist provides AI-guided workflow creation.

## 14. Fleet Integration

chip-design-mcp integrates with the broader fleet ecosystem. The fleet scan endpoint (GET /api/v1/fleet) probes all ports in the reserved fleet range (10700-11100) to discover other active MCP servers. Each discovered server returns its name and version which populates the web dashboard Apps Hub. The server also reports its own status to the fleet monitoring system. The Glama registry is configured via glama.json for external MCP discovery. The llms.txt and llms-full.txt files provide LLM-readable documentation for context injection in agent workflows.

## 15. Working Directory Structure

All EDA work files are organized under CHIP_DESIGN_MCP_WORK_DIR (default %TEMP%/chip_design_mcp_work). Subdirectories: uploads/ (source RTL Verilog files, uploaded via POST /api/v1/upload), outputs/ (synthesis results, simulation logs, gate-level netlists, GDS, reports), designs/ (OpenLane design directories each containing config.tcl, runs/, and results/). Each OpenLane run creates a timestamped subdirectory under designs/{design_name}/runs/ with intermediate and final results. GDSII output files are exported to outputs/ for download. The server creates these directories automatically at startup. Manual file placement in uploads/ is supported as an alternative to the upload API. File size limits are enforced by the HTTP server (default 100MB).

## 16. Citation and Academic Use

chip-design-mcp enables reproducible open-source chip design flows suitable for academic research and education. When using the server in academic work, cite the underlying tools: Yosys (Claire X. Wolf, Yosys Open SYnthesis Suite), Icarus Verilog (Stephen Williams), OpenLane (The OpenROAD Project), Magic (John Ousterhout et al.), Netgen (Tim Edwards), and OpenSTA (The OpenSTA Project). The Sky130 PDK is provided by SkyWater Technology and Google. GF180MCU is provided by GlobalFoundries. The server orchestrates these tools but implements no EDA algorithms itself.

## 17. FAQ

Q: Do I need all EDA tools installed? A: No. The server starts with whatever tools are available on PATH. Each tool reports its availability via chip_status. You can install tools incrementally as needed.

Q: How long does synthesis take? A: A small design (under 1000 cells) synthesizes in under 10 seconds. A 10000-cell design takes 30-60 seconds. A 100000-cell design may take 2-5 minutes.

Q: How long does OpenLane place-and-route take? A: A small counter design (50 cells) takes 2-3 minutes. A 5000-cell design takes 15-30 minutes. A 50000-cell design takes 2-4 hours. The pr_run_flow timeout should be set accordingly.

Q: Can I use a different PDK? A: Yes. chip_available_pdks lists supported PDKs. Use the pdk parameter on synthesis and place-and-route tools. The server supports sky130, gf180mcu, and ihp-sg13g2.

Q: What is the maximum design size supported? A: The server has no hard limit, but practical constraints include available RAM, disk space, and Docker container resource limits. Designs up to 100000 cells are practical on a system with 32GB RAM and 50GB free disk space.

Q: How do I view the GDSII output? A: Export the GDS file with pr_export_gds and open it in KLayout, Magic, or any GDS viewer. The server does not include a GDS viewer but the file is ready for external tools.

## 18. Tutorial 11: RTL Design Best Practices for EDA Flow

Goal: Write Verilog RTL that synthesizes and passes place-and-route efficiently.

Step 1: Use synchronous design practices: all flip-flops should use a single clock edge (posedge or negedge, not both). Avoid latches unless explicitly required (latches complicate STA and are not supported by some PDK libraries). Step 2: Keep combinational depth manageable: a rule of thumb is under 50 logic levels between flip-flops for a 20ns clock period in Sky130. For higher clock frequencies, pipeline long combinational paths. Step 3: Avoid gated clocks: use clock enables on flip-flops rather than ANDing the clock signal. Gated clocks create timing analysis complications and clock tree synthesis challenges. Step 4: Use synchronous resets: while both synchronous and asynchronous resets are supported, synchronous resets simplify STA. If using asynchronous resets, ensure proper reset recovery timing. Step 5: Register all outputs: all module outputs should be registered (driven by flip-flops) to avoid combinational output glitches and to maintain clean timing boundaries between blocks. Step 6: Avoid tristate buses inside the core: tristate logic is typically restricted to I/O cells. Use multiplexers for internal bus arbitration. Step 7: Parameterize module widths and depths for easy reuse: use Verilog parameters for bus widths, FIFO depths, counter sizes to enable quick design space exploration through synthesis and place-and-route. Step 8: Add synthesis directives: use /* keep_hierarchy */ and /* keep */ comments to prevent Yosys from optimizing away important signals. Use (* keep *) attribute for register retention across synthesis optimization.

## 19. Tutorial 12: Working with SRAM Macros

Goal: Integrate an SRAM macro into your chip design.

Step 1: Sky130 PDK includes SRAM macros (sky130_fd_sram) in various configurations (1KB, 2KB, 4KB, 8KB with 32-bit and 64-bit data widths). Step 2: The SRAM macros are pre-characterized hard macros with fixed layout, timing, and power characteristics. Step 3: Add an SRAM instance to your RTL by instantiating the SRAM macro module with proper port connections (address, data_in, data_out, chip_enable, write_enable, clock). Step 4: During synthesis, Yosys treats the SRAM as a black box (the SRAM is not synthesized -- it uses the pre-built hard macro). Use the -lib flag to load the SRAM Liberty model. Step 5: During place-and-route, OpenLane's macro placement feature handles SRAM placement. Use pr_configure to set MACRO_PLACEMENT configuration with the SRAM macro location and orientation. The macro placer automatically sets blockage areas around the SRAM to prevent standard cell placement in the macro area. Step 6: SRAM integration requires additional floorplan space. Account for the SRAM area in your DIE_AREA calculation. A 4KB SRAM in Sky130 occupies approximately 500um x 500um including I/O routing area. Step 7: Verify timing with the SRAM's Liberty timing models during STA.

## 20. Tutorial 13: GDS Viewing and Post-Layout Verification

Goal: Visually inspect the final GDSII layout and perform post-layout checks.

Step 1: Export the completed GDS: pr_export_gds design_name="my_counter". The GDS file is saved to the outputs directory. Step 2: Open the GDS in KLayout (recommended free GDS viewer): klayout my_counter.gds. Step 3: In KLayout inspect the layout hierarchy: the top cell shows the complete chip with pad ring, SRAM macros (if used), and standard cell area. Step 4: Check standard cell area density: standard cells should be tightly packed in the core area with no large gaps (gaps indicate low core utilization). Step 5: Verify pin accessibility: I/O pins around the pad ring should be clearly visible and connected to the core. Step 6: Check clock tree distribution: clock buffers should be distributed evenly across the core area. Step 7: Verify power grid: metal1 VDD/VSS stripes should cover the core area. Step 8: Run additional DRC with more comprehensive rule decks if the design is going to manufacturing. Step 9: The GDS file is the final tapeout deliverable. Generate additional views (LEF, Liberty, GDS) for integration into larger chips.

## 21. Continuous Integration for Chip Design

For ongoing chip development projects, integrate chip-design-mcp into your CI pipeline: 1) Use the REST API for automated tool calls from CI runners. 2) Run synthesis and simulation as fast pre-merge checks (complete in under 2 minutes for small designs). 3) Run place-and-route as a nightly or weekly CI job (30-60 minutes per design). 4) Run DRC and LVS as post-processing verification gates. 5) Store GDS output as CI artifacts for download and review. 6) Use the Chiplab workflow engine to define CI pipeline stages with dependency ordering. 7) The server's truthful tool-not-found errors make CI setup self-documenting: the CI configuration only needs to define the pipeline logic, and the server handles capability detection at runtime. 8) GitHub Actions example: checkout repo, install EDA tools in action (Docker-based), start chip-design-mcp, call REST API for synthesis and simulation, verify output artifacts exist.

## 22. Multi-Project and Shared Resource Management

When using chip-design-mcp in a team environment: 1) Each project should use a separate design directory under DESIGNS_DIR. 2) The PDK is shared across all projects via PDK_ROOT. 3) Docker-based OpenLane runs are isolated per design. 4) Multiple concurrent synthesis and simulation operations are supported (async subprocesses). 5) OpenLane runs should be serialized per design (one flow per design at a time) to avoid resource contention. 6) The activity log (activity_log.py) tracks all operations for auditability across team members. 7) The REST API allows remote team members to access the server over the network (set MCP_HOST=0.0.0.0 for network accessibility with appropriate firewall rules). 8) The fleet scan endpoint helps team members discover active chip design servers on the network. 9) The GLAMA and MCPB configurations support publishing the server to shared MCP registries for team-wide discovery. 10) The llms-full.txt provides comprehensive LLM context for team members using AI coding assistants.

## 23. OpenLane Configuration Parameter Reference

Key OpenLane configuration parameters accessible via pr_configure: FP_CORE_UTIL (core utilization percentage, 0-100, default 50, higher values pack cells tighter improving area but risking routing congestion), DIE_AREA (die dimensions in microns as "min_x min_y max_x max_y", must be large enough for the design plus I/O pad ring), IO_MODE (1 for 1-sided pad ring on top, 2 for 2-sided top and bottom, default 1), PL_TARGET_DENSITY (placement density 0.0-1.0, default 0.55, higher values reduce white space), CLOCK_PERIOD (target clock period in nanoseconds, default derived from design), CLOCK_PORT (clock port name, default clk), CTS_TARGET_SKEW (target clock skew in nanoseconds, default derived), CTS_CLK_BUFFER_LIST (list of clock buffer cells from the PDK), ROUTING_STRATEGY (integer 0-14 selecting routing aggressiveness, higher values are more aggressive), VDD_NETS and VSS_NETS (power net names, default vdd and vss), MACRO_PLACEMENT (list of macro placement directives for SRAM and custom blocks), DIODE_INSERTION_STRATEGY (antenna rule compliance, 1-5), RUN_HEURISTIC_DIODE_INSERTION (automatic antenna diode insertion). The configuration is written to the design's config.tcl file before each OpenLane run. The server provides sensible defaults for all parameters. Values that are too small for the design cause OpenLane errors with clear messages indicating the constraint violation.

## 24. Activity Log Reference

The activity log tracks all tool invocations for auditability and debugging. Each log entry includes: timestamp (ISO datetime), tool_name (the MCP tool invoked), parameters (tool arguments, with file paths truncated for privacy), result_status (success, failure, error), execution_duration_ms (how long the operation took), and error_message (if applicable). The activity log is accessible via get_logs operation which returns the most recent entries with optional level filtering. The export_logs operation writes the log to JSON or CSV format for external analysis. The clear_logs operation removes all log entries. Log entries are stored in an in-memory ring buffer with configurable maximum size (default 1000 entries). The buffer prevents memory exhaustion during extended server sessions. For persistent logging, configure the standard Python logging to write to a file via LOG_LEVEL and standard Python logging configuration. The activity log is separate from the server's operational logs (stdout/stderr) which provide debugging information about server internal operations, EDA tool subprocess output, and FastAPI request/response logging.

## 25. Standard Cell Library Reference

The Sky130 sky130_fd_sc_hd standard cell library includes approximately 300-500 cells organized by function type. Sequential cells: D flip-flops (dfxtp with positive-edge triggered data input, dfrtp with asynchronous reset, dfsbp with scan chain input, dlclkp with clock gate latch, dlxtp transparent latch). Combinational cells: basic gates (and2, and3, and4, or2, or3, nand2, nand3, nand4, nor2, nor3, nor4, xor2, xnor2, buf, inv), complex gates (aoi21, aoi22, oai21, oai22, a2bb2o, ha1 full/half adder), special cells (tap cells for well/substrate connections, decap cells for decoupling capacitance, endcap cells for row termination, fill cells for density, tie cells for VDD/VSS connection, antenna cells for charge dissipation). Each cell is available in multiple drive strengths (1, 2, 4, 8, 16, 32 for sequential cells, 1, 2, 4 for combinational cells). Higher drive strengths consume more power and area but provide faster switching and higher fanout capability. The Liberty timing models include multiple corners: tt_025C_1v80 (typical transistor, 25C, 1.8V), ff_100C_1v95 (fast-fast transistor, 100C, 1.95V), ss_100C_1v62 (slow-slow transistor, -40C, 1.62V). Timing analysis typically uses the worst-case corner for setup checks and the best-case corner for hold checks.

## 26. Performance Benchmarking Reference

Typical operation durations for reference: chip_status: under 100ms (PATH probes and PDK check). syn_read_verilog: under 50ms (file reading). syn_run (small design under 500 cells): 2-10 seconds (Yosys synthesis). syn_run (medium design 1000-10000 cells): 10-60 seconds. syn_stats: under 50ms (log parsing). sim_run_testbench (small): 1-5 seconds (iverilog compile + vvp run). sim_run_testbench (large with VCD): 5-30 seconds depending on simulation length. sim_read_waveform (small VCD): 1-5 seconds. pr_create_design: under 500ms (directory creation and config.tcl generation). pr_run_flow synthesis stage: 30 seconds to 5 minutes. pr_run_flow floorplan stage: 30 seconds to 2 minutes. pr_run_flow CTS stage: 1-5 minutes. pr_run_flow routing stage: 2-30 minutes depending on congestion. pr_run_flow signoff stage: 1-5 minutes. pr_read_reports: under 200ms. verify_drc: 30 seconds to 5 minutes. verify_lvs: 30 seconds to 5 minutes. verify_timing: 10 seconds to 2 minutes. cells_list: under 1 second (library metadata read). The server's async subprocess design means long operations do not block other tool calls. OpenLane operations are the most time-intensive and should be planned accordingly.

## 27. Debugging Failed OpenLane Runs

When an OpenLane run fails, diagnose using these steps: 1) Check pr_status to confirm the design state. 2) Use pr_read_reports to check the last completed stage report. 3) The most common failures: synthesis fails due to unsupported Verilog constructs (use Yosys-compatible RTL), floorplan fails due to DIE_AREA too small for the design (increase die area or reduce core utilization), placement fails due to insufficient site rows (check DIE_AREA height must accommodate standard cell row height multiple), CTS fails due to clock buffer availability (verify PDK library includes clock buffers), routing fails due to routing congestion (reduce core utilization, add routing layers, or use higher ROUTING_STRATEGY), signoff DRC fails due to incomplete PDK installation (verify PDK file completeness). 4) Check the OpenLane logs in the design directory under runs/ for detailed error messages. 5) Adjust the relevant configuration parameter and re-run from the failing stage. 6) OpenLane supports resume from last completed stage so only the failing stage and subsequent stages are re-executed. 7) For persistent failures, try the OpenLane design examples as reference for correct configuration values.

## 28. Design Flow for Mixed-Signal Designs

For mixed-signal designs combining analog and digital blocks: 1) Partition the design into separate digital and analog sections. The digital section follows the standard RTL-to-GDSII flow. The analog section requires custom layout (typically done in Magic or KLayout manually). 2) Create the digital section as a synthesizable Verilog module. Run the standard synthesis and place-and-route flow. 3) Create the analog blocks as black boxes for the digital flow: provide LEF views for the analog blocks with pin positions and obstruction areas. 4) During chip integration, the analog blocks are placed as hard macros using MACRO_PLACEMENT configuration. 5) The standard place-and-route flow routes around the analog block obstructions. 6) Run full-chip DRC and LVS including both digital and analog sections. 7) Mixed-signal verification requires additional simulation (AMS simulation) which is outside the current server scope but the digital section can be verified independently with the simulation tools. The Sky130 PDK includes analog devices (resistors, capacitors, diodes, bipolar transistors) through the sky130_fd_pr library for mixed-signal designs.

## 29. Command-Line Interface Reference

The server supports CLI arguments through its main entry point: --mode (transport mode: dual, sse, stdio, http, default dual), --port (server port, default 11022), --host (bind address, default 0.0.0.0), --agentic (enable CodeMode BM25 agentic discovery flag). The dual mode runs both stdio and HTTP simultaneously. Environment variables: CHIP_DESIGN_MCP_WORK_DIR, PDK_ROOT, CHIP_TAURI, CHIP_DESIGN_MCP_PREFAB_APPS, OLLAMA_URL, LMSTUDIO_URL, MCP_AGENTIC, MCP_PORT. The web dashboard runs separately on port 11023 via Vite dev server or built static files. The backend and frontend are independent processes with the frontend proxying API requests to the backend during development.