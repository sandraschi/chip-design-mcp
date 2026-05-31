# Chip Design MCP — User Guide

This tutorial walks you from a **naked Windows PC** to running simulation, synthesis, and place-and-route through chip-design-mcp. It assumes you want open-source SkyWater 130 nm tooling, but notes alternatives (GF180, IHP) where relevant.

---

## Part 1 — Naked PC Install with start.bat

The fastest path on Windows is the repo launcher:

1. Clone or copy `chip-design-mcp` to a local folder, e.g. `D:\Dev\repos\chip-design-mcp`.
2. Double-click **`start.bat`** (or run from PowerShell: `.\start.bat`).

`start.bat` invokes `start.ps1`, which performs a **naked-PC bootstrap**:

| Step | Action |
|------|--------|
| 1/5 | Ensures **uv** (Python) and **Node.js LTS** via winget if missing |
| 2/5 | Runs `uv sync --all-extras` and import-smoke-tests the server |
| 3/5 | Runs `npm install` in `webapp/` if `node_modules` absent |
| 4/5 | Clears ports **11022** and **11023** (kills stale listeners) |
| 5/5 | Starts backend + Vite frontend; polls `/api/v1/status` up to 90 s; opens browser |

**Flags:**

- `-BackendOnly` — MCP/REST without webapp
- `-NoBrowser` — skip auto-open
- `-Headless` — relaunch hidden (automation)
- `$env:SKIP_SYNC = "1"` — skip `uv sync` on repeat runs

**Work directory:** `%TEMP%\chip_design_mcp_work` (override with `CHIP_DESIGN_MCP_WORK_DIR` before start).

If winget is unavailable, install manually: [uv](https://docs.astral.sh/uv/), [Node LTS](https://nodejs.org/), then:

```powershell
cd D:\Dev\repos\chip-design-mcp
uv sync --all-extras
just serve   # backend :11022
just web     # frontend :11023
```

---

## Part 2 — Prerequisites (EDA Stack)

chip-design-mcp orchestrates external tools. Install what you need by flow stage:

### Required for synthesis

- **Yosys** — RTL synthesis
  - Windows: build from source, oss-cad-suite, or WSL `sudo apt install yosys`
  - Verify: `yosys -V`

### Required for simulation

- **Icarus Verilog** (`iverilog`, `vvp`)
- **cocotb** — `pip install cocotb` or via project venv
- Optional: **GTKWave** for interactive waves

### Required for place-and-route

- **Docker Desktop** (recommended) + image:
  `docker pull ghcr.io/the-openroad-project/openlane:latest`
- Or native **OpenLane** on Linux

### Required for signoff-style checks

- **Magic** — DRC, extraction
- **netgen** — LVS
- **OpenSTA** (`sta` on PATH) — timing

### PDK via volare

```powershell
pip install volare
volare enable --pdk sky130 0bbdd5
```

Set `PDK_ROOT` in your environment (volare usually configures this). Restart the MCP server after installing PDK so `chip_status` reflects `pdk_installed: true`.

### Optional

- **Graphviz** — for `syn_show` SVG/PDF output
- **KLayout** — GDS viewing

Run discovery:

```powershell
just yosys-check
just openlane-check
just cocotb-check
```

Or call MCP tool `chip_status`.

---

## Part 3 — MCP Client Installation

### Cursor / Claude Desktop (stdio)

Add to MCP config:

```json
{
  "mcpServers": {
    "chip-design-mcp": {
      "command": "uv",
      "args": ["run", "--project", "D:/Dev/repos/chip-design-mcp", "python", "-m", "chip_design_mcp.server", "--mode", "stdio"],
      "env": {
        "PDK_ROOT": "C:/Users/you/.volare"
      }
    }
  }
}
```

Adjust paths. Use forward slashes in JSON on Windows.

### HTTP / SSE (server already running)

Point client to `http://127.0.0.1:11022/mcp` or `/sse` per client docs. Manifest: `http://127.0.0.1:11022/.well-known/mcp/manifest.json`.

### Verify connection

Ask the assistant to run `chip_status` or open webapp **Status** page at `http://localhost:11023`.

---

## Part 4 — Webapp Pages

| Route | Purpose |
|-------|---------|
| Dashboard | Overview, quick links |
| Synthesis | Invoke syn_* via UI |
| Simulation | sim_* controls |
| Place & Route | pr_* flow triggers |
| Verification | verify_* checks |
| Cells | Browse standard cells |
| Depot | Projects and files |
| Tools Hub | Full catalog with docstrings |
| Apps Hub | Fleet scan (ports 10700–11100) |
| Chat | Local LLM (Ollama/LM Studio) when running |
| API Docs | Swagger/ReDoc for REST |
| Status | Live `/api/v1/status` |

The webapp uses `POST /api/v1/control/{tool_name}` with JSON bodies matching MCP tool parameters.

---

## Part 5 — Step-by-Step: Counter Template → Sim → Syn → PR

### 5.1 Create project

Via MCP:

```
depot_init(project_name="tt_counter", template="counter", pdk="sky130")
```

Creates `designs/tt_counter/` with RTL, cocotb test, Makefile, `config.json`.

### 5.2 Upload RTL for MCP synthesis path

Copy `designs/tt_counter/src/tt_counter.v` to uploads or use REST upload:

```powershell
curl -F "file=@designs/tt_counter/src/tt_counter.v" http://localhost:11022/api/v1/upload
```

### 5.3 Simulation

**Option A — Makefile (full cocotb):**

```powershell
cd $env:TEMP\chip_design_mcp_work\designs\tt_counter
pip install cocotb
make sim
```

**Option B — MCP:**

```
sim_run_testbench(dut_file="tt_counter.v", test_module="test_tt_counter", top_module="tt_counter", waves=True)
```

Review waves: `sim_read_waveform(vcd_file="...")` or GTKWave locally.

### 5.4 Synthesis

```
syn_read_verilog(file_name="tt_counter.v", top_module="tt_counter", liberty="C:/Users/you/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib")
syn_run(top_module="tt_counter", abc9=True)
syn_stats()
syn_export_netlist(format="verilog")
```

Gate netlist appears in `outputs/tt_counter_synth.v`.

### 5.5 Place & Route (OpenLane)

Confirm Docker running and PDK available:

```
pr_status()
pr_create_design(design_name="tt_counter", verilog_file="tt_counter.v", pdk="sky130")
pr_configure(design_name="tt_counter", clock_period=10, core_util=40, target_density=0.55)
pr_run_flow(design_name="tt_counter")
```

Expect **20–60 minutes**. Then:

```
pr_read_reports(design_name="tt_counter", report_type="all")
pr_export_gds(design_name="tt_counter")
pr_export_lef(design_name="tt_counter")
```

### 5.6 Verification

```
verify_drc(gds_file="tt_counter.gds")
verify_timing(netlist="tt_counter_synth.v", sdc_file="constraints.sdc", top_module="tt_counter")
```

Upload SDC to uploads first if needed. Interpret DRC violation counts as **heuristic**—read Magic reports manually for tapeout.

---

## Part 6 — chip_agentic Usage

`chip_agentic` leverages MCP sampling when the host supports it.

| Operation | Prompt required | Behavior |
|-----------|-----------------|----------|
| `status_summary` | No | EDA/PDK snapshot |
| `flow_plan` | Yes | Ordered tool plan for a goal |
| `natural_query` | Yes | Q&A against tool catalog |

Examples:

```
chip_agentic(operation="status_summary")
chip_agentic(operation="flow_plan", prompt="8-bit counter on sky130: sim, syn, OpenLane")
chip_agentic(operation="natural_query", prompt="Do I need Docker for DRC only?")
```

If sampling is unavailable, you'll get suggestions to use `chip_status` and the webapp— not an error to panic about.

---

## Part 7 — Tiny Tapeout vs ChipFoundry

Both are **shuttle services** that aggregate many designs onto one wafer—they are not MCP tools.

| Aspect | Tiny Tapeout | ChipFoundry |
|--------|--------------|-------------|
| Cost | ~$100 | ~$15k+ |
| Area | ~0.016 mm² slots | ~15 mm² class |
| PDK | Sky130, GF180, IHP | Sky130 focus |
| Audience | Hobbyists, first silicon | Startups, larger blocks |
| MCP role | Export GDS + docs; human submits | Same |

chip-design-mcp gets you to **GDSII and reports**. Submission, bonding diagrams, and shuttle deadlines remain manual on the provider portal. Read `docs/MINI_FAB.md` and `docs/PRODUCTION_PATHS.md` in the repo.

---

## Part 8 — Worked Example: ALU Template

```
depot_init(project_name="lab_alu", template="alu", pdk="sky130")
```

Upload `lab_alu.v`, then:

```
sim_run_testbench(dut_file="lab_alu.v", test_module="test_lab_alu", waves=False)
syn_read_verilog(file_name="lab_alu.v", top_module="lab_alu")
syn_run(top_module="lab_alu", flatten=False, abc9=True)
cells_search(function="adder", pdk="sky130", limit=10)
verify_formal(design_verilog="lab_alu_synth.v", reference_verilog="lab_alu.v")
```

ALU is combinational—OpenLane still needs clock port in config; template FSM/counter templates include `clk`.

---

## Part 9 — Worked Example: FSM Template

```
depot_init(project_name="ctrl_fsm", template="fsm")
sim_check_coverage(test_dir="designs/ctrl_fsm/tests")
pr_create_design(design_name="ctrl_fsm", verilog_file="ctrl_fsm.v")
pr_configure(design_name="ctrl_fsm", clock_period=20, core_util=35)
pr_run_flow(design_name="ctrl_fsm", from_stage="synthesis", to_stage="placement", tag="explore")
pr_read_reports(design_name="ctrl_fsm", report_type="timing", tag="explore")
```

Partial flows (`to_stage="placement"`) help debug without full signoff wait.

---

## Part 10 — Worked Example: Standard Cell Exploration

```
chip_available_pdks()
cells_stats(pdk="sky130")
cells_search(function="dff", pdk="sky130", limit=20)
cells_info(cell_name="sky130_fd_sc_hd__dfxtp_1")
show_cells_list_card(pdk="sky130", limit=25)
```

Requires `PDK_ROOT`. Without it, tools return install hints—follow volare steps in Part 2.

---

## Part 11 — Worked Example: DRC-Only on Existing GDS

If you already have `my_chip.gds` in outputs:

```
verify_drc(gds_file="my_chip.gds", tech_file="C:/path/to/sky130A/libs.tech/magic/sky130A.tech")
```

No OpenLane rerun required. Magic must be on PATH.

---

## Part 12 — Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Yosys not found` | Not on PATH | Install Yosys; restart server |
| `PDK_ROOT not set` | volare not run | `volare enable --pdk sky130 0bbdd5` |
| OpenLane Docker fails | Docker stopped | Start Docker Desktop |
| Port 11022 in use | Zombie process | Re-run `start.bat` (clears ports) or kill PID |
| iverilog syntax error | SV unsupported | Use Verilog-2001; try `extra_args="-g2012"` |
| syn_run 0 cells | stat parse / empty RTL | Check stdout; re-read Verilog |
| pr_run_flow timeout | Large design / slow CPU | Increase patience; simplify RTL |
| LVS mismatch | Wrong SPICE top or missing extract | Verify netlists; check OpenLane results |
| chip_agentic no Context | Host lacks sampling | Use direct tools |
| Prefab cards missing | prefab-ui or env | `uv sync --all-extras`; check `CHIP_DESIGN_MCP_PREFAB_APPS` |
| abc9 failure | Liberty mismatch | Verify .lib path; try `abc9=False` |
| Empty cells_list | PDK not installed | volare enable |

**Logs:** `backend.log` in repo root when using `start.ps1`.

**Tests:** `uv run pytest tests/ -q` — smoke tests without EDA.

---

## Part 13 — REST API Quick Reference

```powershell
Invoke-RestMethod http://localhost:11022/api/v1/status
Invoke-RestMethod http://localhost:11022/api/capabilities
Invoke-RestMethod -Method POST -Uri http://localhost:11022/api/v1/control/chip_status -Body '{}' -ContentType 'application/json'
```

Upload: `POST /api/v1/upload` multipart. List: `GET /api/v1/list?dir=designs`. Download: `GET /api/v1/download/{file}?dir=outputs`.

---

## Part 14 — Best Practices

1. **Sim before syn** — Catch functional bugs early.
2. **Always pass Liberty for sky130 syn** — Enables ABC9 mapping.
3. **Name projects snake_case** — Matches depot templates.
4. **Tag OpenLane runs** — `pr_run_flow(..., tag="v2")` for comparisons.
5. **Do not trust heuristic DRC counts for tapeout** — Read full reports.
6. **Use fleet git-github for repo commits** — Not chip-design tools.
7. **Back up `%TEMP%\chip_design_mcp_work`** — Temp can be cleared by OS.

---

## Part 15 — Getting Help

- Repo docs: `docs/SETUP.md`, `docs/TOOLS.md`, `docs/PDK_GUIDE.md`
- AGENTS.md for agent-specific gotchas
- GitHub issues: sandraschi/chip-design-mcp
- Skill: `skill://chip-design-expert/SKILL.md`

Welcome to open-source silicon. Start small—a counter fits on Tiny Tapeout; learn the flow before betting a shuttle slot.


---

## Appendix A — Directory Layout Deep Dive

Understanding where files live prevents confusion when chaining tools.

```
chip_design_mcp_work/
├── uploads/          # RTL, SDC, constraints uploaded for syn/sim/verify
├── outputs/          # Synthesized netlists, exported GDS/LEF, reports copies
└── designs/          # Depot projects and OpenLane trees
    └── my_project/
        ├── src/      # RTL
        ├── tests/    # cocotb
        ├── Makefile
        ├── config.json
        └── runs/     # OpenLane outputs (after pr_run_flow)
            └── RUN_*/
                ├── reports/signoff/
                └── results/final/
```

When `depot_init` creates a project, RTL lives under `designs/` but MCP synthesis reads from `uploads/` unless you copy or upload files. The REST upload endpoint is the canonical bridge.

---

## Appendix B — Clock Constraints and SDC

Static timing via `verify_timing` requires an SDC file alongside the synthesized netlist. Minimal counter SDC example:

```
create_clock -period 10 [get_ports clk]
set_input_delay 2 -clock clk [all_inputs]
set_output_delay 2 -clock clk [all_outputs]
```

Upload `my_counter.sdc` to uploads, then:

```
verify_timing(netlist="my_counter_synth.v", sdc_file="my_counter.sdc", top_module="my_counter")
```

OpenLane uses `CLOCK_PORT` and `CLOCK_PERIOD` from `config.json`—keep SDC philosophically aligned though formats differ slightly.

---

## Appendix C — ABC9 vs ABC Decision Guide

| Scenario | Recommendation |
|----------|----------------|
| sky130 + official Liberty | `abc9=True` (default) |
| No Liberty yet | `abc9` ignored; generic mapping |
| ABC9 crash on older Yosys | Upgrade Yosys or `abc9=False` |
| Comparing area/timing | Run both; diff `syn_stats` and netlists |

ABC9 integrates better with fixed liberty cells for ASIC flows. Classic ABC remains useful for FPGA-centric or debug scripts.

---

## Appendix D — Icarus Verilog Feature Reminder

Supported well: modules, always blocks, assign, generate (limited), parameters, most synthesizable constructs.

Problematic: SystemVerilog classes, constrained random, covergroups, complex SVA, many interface features, packages (version-dependent).

When migrating from commercial simulators, expect to simplify testbenches or run cocotb-only tests with minimal SV in RTL.

---

## Appendix E — OpenLane Docker Volume Notes

On Windows, Docker Desktop must share the drive containing `%TEMP%`. If OpenLane cannot see design files, move `CHIP_DESIGN_MCP_WORK_DIR` to a Docker-shared path like `D:\chip_work` and restart.

Environment inside container may not see host `PDK_ROOT` unless configured in OpenLane docs—many flows embed PDK fetch inside the image. If PDK errors appear, consult OpenLane 2 documentation for sky130 PDK pinning.

---

## Appendix F — Prefab Cards in Claude/Cursor

When your client renders MCP Apps, prefer:

- `show_chip_status_card()` at session start
- `show_pipeline_card()` when explaining flow to beginners
- `show_depks_card()` after volare install
- `show_depot_card()` when managing multiple projects

Cards are read-only mirrors of JSON tools—safe to call anytime.

---

## Appendix G — Example Session Transcript (Abbreviated)

**User:** I want to make a counter for Tiny Tapeout.

**Assistant:** Run `chip_status`. Install volare if PDK missing. `depot_init(project_name="tt_um_counter", template="counter")`. Simulate with Makefile. Upload Verilog. `syn_read_verilog` with sky130 Liberty. `syn_run`. Configure OpenLane with 10 ns clock. Warn about 30–45 min `pr_run_flow`. Export GDS. Heuristic DRC only—review reports before TT submission.

This pattern repeats for every successful shuttle-bound project.

---

## Appendix H — GF180 and IHP Paths

For GF180MCU:

```
volare enable --pdk gf180mcu
depot_init(project_name="gf180_demo", template="counter", pdk="gf180mcu")
pr_create_design(..., pdk="gf180mcu")
cells_list(pdk="gf180mcu")
```

For IHP SG13G2 (RF):

```
volare enable --pdk ihp-sg13g2
cells_list(pdk="ihp-sg13g2")
```

Magic tech files differ—always pass explicit `tech_file` for non-sky130 DRC.

---

## Appendix I — Formal Equivalence Tips

`verify_formal` compares two Verilog files via Yosys equivalence checking. Best practice: use RTL golden vs `syn_run` output netlist. Sequential equivalence may need inductive depth tuning (`equiv_induct -seq 10` is baked in). Failures require examining Yosys stdout—not summarized pass/fail alone.

---

## Appendix J — Makefile vs MCP Simulation

| Approach | Pros | Cons |
|----------|------|------|
| Makefile + cocotb | Full Python tests, industry standard | Requires local make, cocotb |
| sim_run_testbench | Quick MCP integration | Simplified runner |

For coursework and tapeout-quality verification, prefer Makefile flows from depot templates. Use MCP sim tools for quick smoke tests in chat.

---

## Appendix K — Version and CI Expectations

chip-design-mcp version 0.1.0 targets FastMCP 3.2, Python 3.11+, Node 20 LTS. CI runs pytest smoke without mandating EDA on runners. Your machine must provide tools locally for real flows.

---

## Appendix L — Glossary

- **RTL** — Register Transfer Level Verilog source
- **GDSII** — Geometry database for fabrication
- **LEF** — Abstract cell/macro layout exchange
- **PDK** — Process Design Kit from foundry
- **MPW** — Multi-project wafer shuttle
- **DRC** — Design rule check (geometry)
- **LVS** — Layout vs schematic consistency
- **STA** — Static timing analysis
- **Liberty** — Cell timing/power library (.lib)

---

## Appendix M — Security and Privacy

Design files stay local under work dir unless you upload to external shuttles. MCP servers bind `0.0.0.0:11022` by default—on shared networks, firewall or bind to localhost. Do not expose unauthenticated REST to the public internet.

---

## Appendix N — Updating the Server

```powershell
cd D:\Dev\repos\chip-design-mcp
git pull
uv sync --all-extras
cd webapp
npm install
```

Restart via `start.bat`. Fleet git operations: use git-github MCP, not manual copy.

---

## Appendix O — When to Stop Automating

You have enough when: simulation passes, synthesis meets cell count expectations, OpenLane reports timing met (positive WNS), DRC reports reviewed clean by human, GDS exported. Manufacturing is a business/process step beyond MCP—congratulate the user and point to Tiny Tapeout or ChipFoundry docs for submission checklists.

---

## Appendix P — Complete Tool Invocation Cheat Sheet

Every MCP tool at a glance for power users:

**Synthesis:** `syn_status()` · `syn_read_verilog(file_name, top_module, liberty?)` · `syn_run(top_module?, flatten?, abc9?, script_extra?)` · `syn_stats()` · `syn_show(top_module, format?)` · `syn_export_netlist(format?)`

**Simulation:** `sim_list_tests(test_dir?)` · `sim_run_testbench(dut_file, test_module, top_module?, waves?, extra_args?)` · `sim_read_waveform(vcd_file, signals?, start_time?, end_time?)` · `sim_check_coverage(test_dir?)`

**Place & Route:** `pr_status()` · `pr_create_design(design_name, verilog_file, pdk?)` · `pr_configure(design_name, clock_period?, core_util?, target_density?, die_area?, macros?)` · `pr_run_flow(design_name, from_stage?, to_stage?, tag?)` · `pr_read_reports(design_name, report_type?, tag?)` · `pr_export_gds(design_name, tag?)` · `pr_export_lef(design_name, tag?)`

**Verification:** `verify_drc(gds_file, tech_file?)` · `verify_lvs(gds_file, spice_netlist, top_cell?)` · `verify_timing(netlist, sdc_file, liberty?, top_module?)` · `verify_formal(design_verilog, reference_verilog)`

**Cells:** `cells_list(pdk?, limit?)` · `cells_info(cell_name, pdk?)` · `cells_search(function?, pdk?, limit?)` · `cells_stats(pdk?)`

**Depot:** `depot_init(project_name, template?, pdk?)` · `depot_list(directory?)` · `depot_status()`

**System:** `chip_status()` · `chip_pipeline_stages()` · `chip_available_pdks()` · `chip_agentic(operation, prompt?)`

**Prefab:** `show_chip_status_card()` · `show_pdks_card()` · `show_pipeline_card()` · `show_depot_card()` · `show_cells_stats_card(pdk?)` · `show_cells_list_card(pdk?, limit?)`

---

## Appendix Q — Worked Example: End-to-End Tiny Tapeout Counter (Narrative)

This walkthrough ties every stage together with realistic timing expectations for a first-time user on Windows.

**Hour 0 — Install:** Run `start.bat`. Wait for winget/uv/npm if naked PC. Browser opens to dashboard. Call `chip_status`—likely yosys and iverilog missing initially.

**Hour 1 — EDA setup:** Install oss-cad-suite or WSL Ubuntu with `apt install yosys iverilog magic netgen`. Install Docker Desktop, pull OpenLane image. `pip install volare cocotb`. `volare enable --pdk sky130 0bbdd5`. Restart MCP server. `chip_status` now shows green for core tools.

**Hour 2 — Project:** `depot_init(project_name="tt_um_example", template="counter")`. Edit RTL if needed—keep under Tiny Tapeout area guidelines (consult current TT docs for exact µm² limits). Run `make sim` in project dir—fix any cocotb assertion failures.

**Hour 3 — Synthesis:** Upload `tt_um_example.v`. `syn_read_verilog` with full Liberty path. `syn_run(abc9=True)`. Expect hundreds of cells for 8-bit counter. `verify_formal` comparing RTL to netlist optional but educational.

**Hours 4–5 — OpenLane:** `pr_create_design`, `pr_configure(clock_period=10)`, warn user about coffee break. `pr_run_flow`. On success, `pr_read_reports(report_type="all")`. Scan timing summary for WNS. `pr_export_gds`.

**Hour 6 — Signoff review:** `verify_drc` heuristic—open Magic report files anyway. Compare GDS in KLayout. Human checklist for TT: pinout, power, clock, reset, scan chain if applicable.

**Hour 7+ — Submission:** User uploads GDS to Tiny Tapeout portal manually. MCP job complete.

---

## Appendix R — Worked Example: ALU-Only (No P&R)

For users without Docker, deliver value through sim+synthesis:

1. `depot_init(project_name="combo_alu", template="alu")`
2. `make sim` — three cocotb tests (add, sub, zero flag)
3. Upload Verilog → `syn_read_verilog` → `syn_run`
4. `cells_search(function="xor")` — discuss mapping
5. `syn_export_netlist(format="json")` — inspect graph
6. Stop—explain P&R requires OpenLane when ready

This teaches mapping without multi-hour runs.

---

## Appendix S — Worked Example: FSM Timing Closure Iteration

1. `depot_init(template="fsm")`
2. Initial `pr_run_flow` with `clock_period=5` — may fail timing
3. `pr_read_reports(report_type="timing")` — note WNS negative
4. `pr_configure(clock_period=12)` — relax clock
5. `pr_run_flow(tag="slow_clk")` — compare reports
6. Document tradeoff for user—frequency vs area

Partial reruns from `placement` save time on iteration 2.

---

## Appendix T — Windows-Specific Tips

- Use `uv run python` never bare `python` for server modules (PATH on Windows).
- `%TEMP%` path may be long—OpenLane Docker on Windows sometimes prefers short paths like `D:\chip_work`.
- PowerShell `curl` is `Invoke-WebRequest` alias—use explicit cmdlets for upload scripts.
- Line endings: Verilog files should be LF or CRLF consistent; avoid BOM in uploaded `.v`.
- Antivirus may slow Docker first pull—plan time.
- `start.ps1` kills processes on 11022/11023—safe for dev, warn if sharing ports.

---

## Appendix U — Linux and WSL Alternative

Many designers run EDA natively on Ubuntu/WSL:

```bash
sudo apt install yosys iverilog magic netgen
pip install volare cocotb
volare enable --pdk sky130 0bbdd5
docker pull ghcr.io/the-openroad-project/openlane:latest
cd chip-design-mcp && uv sync --all-extras && just serve
```

WSL2 Docker integration shares localhost with Windows—MCP clients on Windows host can hit `localhost:11022` from WSL-served backend if bound correctly.

---

## Appendix V — MCP Client Troubleshooting

| Issue | Fix |
|-------|-----|
| Server not listed | Check uv path in config |
| Tools timeout | OpenLane long runs—raise client timeout |
| PDK false in status | Export PDK_ROOT in MCP env block |
| stdio vs HTTP mismatch | Match `--mode` to client transport |
| Duplicate servers | One instance per port |

Re-read `/.well-known/mcp/manifest.json` when configuring LobeHub or fleet indexers.

---

## Appendix W — Reading OpenLane Reports Manually

After `pr_read_reports`, users should open files on disk:

- `{design}/runs/{tag}/reports/signoff/{design}.sta.rpt` — timing
- `{design}.area.rpt` — utilization
- `{design}.drc.rpt` — geometry rules
- `{design}.power.rpt` — dynamic/static power estimates

MCP summaries truncate to first 1000–2000 characters—insufficient for tapeout signoff. Teach users to navigate run directories via `depot_list(directory="my_project")`.

---

## Appendix X — Community and Learning Resources

- SkyWater PDK documentation and OpenROAD flow guides
- Tiny Tapeout GitHub and Discord for shuttle deadlines
- Yosys manual for `script_extra` advanced synthesis
- cocotb documentation for testbench patterns
- chip-design-mcp `docs/PDK_GUIDE.md` for Liberty corners

Encourage users to share reproducible project dirs, not screenshots alone.

---

## Appendix Y — FAQ

**Q: Can MCP submit to the fab?** A: No—export GDS only.

**Q: Does it work offline?** A: Yes, after tools and PDK are local. Docker pull and volare need network once.

**Q: Can I use VHDL?** A: Not natively—convert to Verilog or extend tools separately.

**Q: FPGA flow?** A: Partial—Yosys targets FPGA with different flows; this server targets ASIC PDK mapping.

**Q: How big a design?** A: Toy to small blocks—large SoCs exceed practical OpenLane laptop runtime.

**Q: Is DRC clean when violations=0?** A: Not guaranteed—heuristic only.

**Q: abc9 errors?** A: Check Yosys version and Liberty path; try abc9=False temporarily.

**Q: iverilog fails on interfaces?** A: Rewrite without SystemVerilog interfaces.

---

## Appendix Z — Pre-Flight Checklist Before OpenLane

Print mentally before `pr_run_flow`:

- [ ] Docker running (`pr_status`)
- [ ] PDK installed (`chip_available_pdks`)
- [ ] RTL simulates clean
- [ ] Synthesis produces reasonable cell count
- [ ] `config.json` clock matches intended frequency
- [ ] User aware of 30–60 min runtime
- [ ] Disk space >5 GB free for runs
- [ ] Design name matches module/top conventions

Skipping sim before P&R wastes hours on functionally broken RTL.

---

## Appendix AA — SDC Examples for Common Templates

**Counter template:** Clock on `clk`, async reset `rst_n` ( treated as data for STA unless set_false_path):

```
create_clock -name clk -period 10 [get_ports clk]
set_input_delay 1.5 -clock clk [get_ports en]
set_output_delay 1.5 -clock clk [get_ports count*]
```

**ALU template (combinational):** Virtual clock for IO budgeting:

```
create_clock -name virtual_clk -period 10
set_input_delay 3 -clock virtual_clk [all_inputs]
set_output_delay 3 -clock virtual_clk [all_outputs]
```

**FSM template:** Include `start` and `done` in input/output delays. Upload as `{project}.sdc` before `verify_timing`.

---

## Appendix AB — Interpreting Synthesis Statistics

After `syn_run`, inspect returned `cells`, `wires`, `modules`, and `area`. An 8-bit counter might map to tens of flops plus combinational logic—expect roughly 8–16 DFF cells plus mux/logic depending on enable logic. Sudden explosion to thousands of cells suggests accidental latch inference or unconstrained width. Zero cells means elaboration failed—read Yosys stdout in the data payload. Compare `abc9=True` vs `False` runs by cell count and area when users ask about optimization.

---

## Appendix AC — Docker OpenLane First-Run Walkthrough

1. Install Docker Desktop; enable WSL2 backend on Windows.
2. Open PowerShell: `docker pull ghcr.io/the-openroad-project/openlane:latest`
3. Test: `docker run --rm ghcr.io/the-openroad-project/openlane:latest --version`
4. Ensure `%TEMP%` drive is shared in Docker Desktop → Settings → Resources → File Sharing.
5. Set `CHIP_DESIGN_MCP_WORK_DIR=D:\chip_work` if bind-mount errors occur.
6. Restart chip-design-mcp; `pr_status()` should show docker_available true.

First `pr_run_flow` downloads additional PDK data inside container context—allow extra time and bandwidth.

---

## Appendix AD — Uploading Files via PowerShell

```powershell
$uri = "http://localhost:11022/api/v1/upload"
$form = @{ file = Get-Item -Path "D:\path	o\counter.v" }
Invoke-RestMethod -Uri $uri -Method Post -Form $form
```

List uploads:

```powershell
Invoke-RestMethod "http://localhost:11022/api/v1/list?dir=uploads"
```

Download synthesized netlist:

```powershell
Invoke-WebRequest "http://localhost:11022/api/v1/download/counter_synth.v?dir=outputs" -OutFile counter_synth.v
```

---

## Appendix AE — ChipFoundry vs Tiny Tapeout Decision Tree

Choose **Tiny Tapeout** when: budget ~$100, design fits minimal slot, learning first silicon, community shuttle timing acceptable, simple digital macro.

Choose **ChipFoundry** when: need ~15 mm² class area, startup prototype with more pins, willing to spend ~$15k, may need provider support.

Choose **Europractice/CMP** when: academic affiliation in EU, grant-funded MPW.

MCP prepares GDS regardless—business choice is human. Document area estimate from `pr_read_reports` area section before promising TT fit.

---

## Appendix AF — Extending Depot Templates

After `depot_init(template="empty")`, users add ports and logic in `src/{name}.v`. Update `config.json` VERILOG_FILES if adding multiple files. Regenerate cocotb tests manually. Re-upload consolidated top for synthesis. Template `"counter"`, `"alu"`, `"fsm"` are starting points—not limits.

---

## Appendix AG — Night-Before-Tapeout Review

Suggest users verify: (1) latest GDS hash matches exported file in outputs, (2) top cell name matches TT submission form, (3) power pins connected per PDK docs, (4) clock tree reasonable in OpenLane logs, (5) no antenna or density warnings ignored in reports, (6) LVS if extraction available—not just heuristic MCP pass, (7) repo tagged in git-github MCP for reproducibility.

---

## Appendix AH — Performance Expectations by Machine Class

| Machine | OpenLane counter | Notes |
|---------|------------------|-------|
| Laptop 4-core | 45–90 min | Thermal throttling common |
| Desktop 8-core | 20–40 min | Docker overhead |
| WSL2 Linux | Similar to native Linux | Preferred for heavy flows |
| CI cloud | Not supported by default | Long jobs timeout |

Set expectations—users on older laptops should run partial flows overnight.

---

## Appendix AI — Glossary Extended

**WNS (Worst Negative Slack):** Most critical timing violation magnitude; positive means met.

**TNS (Total Negative Slack):** Sum of violations—closure metric.

**LEF/DEF:** Abstract layout and placement exchange between P&R stages.

**SPEF:** Parasitic extraction for timing—produced in advanced flows.

**MPW:** Multi-project wafer—shuttle model.

**PDK corner:** Process/voltage/temperature variant for Liberty (.lib).

**Elaboration:** Yosys resolving hierarchy to a single top module.

**Technology mapping:** Binding logic to standard cells via ABC/ABC9.

**Signoff:** Final DRC/LVS/timing checks before tapeout.

**Shuttle:** Shared fab run with aggregated designs from multiple teams.

Keep learning—the open-source ASIC ecosystem evolves quickly; re-run `chip_status` after any toolchain upgrade.
