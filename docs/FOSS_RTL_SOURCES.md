# FOSS RTL sources — where to get interesting open designs

**Audience:** Teams using chip-design-mcp who need **real Verilog/SystemVerilog** to simulate, synthesize, and (optionally) run through OpenLane — especially beyond the built-in `depot_init` templates.

**Tone:** [Dreaming in silicon](DREAMING_IN_SILICON.md) — this is the **catalog of fantasy floor plans** (neuraedge, OpenSpike, tiny CPUs). Cloning is allowed; blaming the magazine when OpenLane runs all weekend is not.

**Companion:** [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md) — tools that **create** and **implement** RTL.  
**Fabrication:** [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md) — tile vs chip vs shuttle after you have GDSII.

---

## 1. How to use external RTL with chip-design-mcp

1. **License** — Check SPDX / CERN-OHL / Apache / custom academic terms before redistribution or tapeout.
2. **Clone** into a clean directory (do not mix licenses blindly into one tapeout repo).
3. **Top module** — Identify the synthesis top; OpenLane `DESIGN_NAME` must match.
4. **Staging:**
   - Copy `*.v` / `*.sv` into work dir `uploads/`, or
   - Point `syn_read_verilog` at absolute paths if the server allows, or
   - Use `depot_init` only as a **layout pattern**, then replace RTL.
5. **Sim first** — `sim_run_testbench` if cocotb/iverilog tests exist.
6. **Yosys** — `syn_read_verilog` → `syn_run` with correct **sky130 `.lib`** and **abc9**.
7. **OpenLane** — `pr_create_design` → `pr_configure` → `pr_run_flow` only when size/Docker/PDK are ready.
8. **Reality check** — `chip_status` and `pr_status` before multi-hour runs.

**Size tiers** (align with fabrication doc):

| Tier | Gates (indicative) | Examples in this doc |
|------|-------------------|----------------------|
| T0–T1 | &lt;10k | tt05-spiking, LIF neuron, counters |
| T2 | 10k–100k | neuraedge subset, tinyODIN, PicoRV32 SoC |
| T3+ | 100k+ | OpenSpike, baochip subset, HighTide large cores |

---

## 2. Spiking / neuromorphic RTL (likely what you remembered)

### 2.1 [anykrver/neuraedge-](https://github.com/anykrver/neuraedge-) — **strong OpenLane/sky130 candidate**

| Attribute | Detail |
|-----------|--------|
| What | Event-driven **SNN accelerator** v2: 2×2 mesh NoC, 256 neurons (4×64), online trace-based STDP, DVS-style events |
| HDL | SystemVerilog / Verilog-2001 style |
| Proof | FPGA timing closed (Artix-7 100T, 100 MHz); README documents **Yosys without FPGA primitives** |
| ASIC path | Explicit **OpenLane + SKY130** migration; BRAM18 inference in `synapse_memory.sv` → swap for SRAM macro on ASIC |
| Why “useful” | Engineering log, UART debug, incremental power opts (v2.1), not a toy single-neuron demo |
| chip-design-mcp | Start with **one cluster** or reduced neuron count; full chip is not a first laptop OpenLane job |

**v1 vs v2 (from project docs):** v1 was 32/128 neurons on Basys3; v2 adds mesh routing, online learning, DVS input path.

### 2.2 [sfmth/OpenSpike](https://github.com/sfmth/OpenSpike) — **tapeout-proven reference**

| Attribute | Detail |
|-----------|--------|
| What | Full **SNN accelerator** — 1M+ synaptic weights, reprogrammable, **sky130 tapeout** |
| Stack | Open-source EDA + **OpenRAM** macros; **PicoRV32** control; 40 MHz, published power/throughput |
| Paper | [arXiv:2302.01015](https://arxiv.org/abs/2302.01015) |
| Area | ~**33 mm²** — study and borrow RTL/modules; do not expect local full P&R without farm |
| Why “useful” | End-to-end proof that open tools + sky130 + neuromorphic RTL shipped |
| chip-design-mcp | Parse architecture, simulate submodules; full flow is research infrastructure |

### 2.3 Smaller spiking / learning tiles (shuttle-sized)

| Repository | Description | Silicon |
|------------|-------------|---------|
| [rejunity/tt05-spiking-neural-net](https://github.com/rejunity/tt05-spiking-neural-net) | **“The Huge”** binarized NN — ~40 neurons, 320 synapses, &lt;1 mm² sky130 | Tiny Tapeout **tt05** |
| [rejunity/tt04-LIF-neuron-telluride2023](https://github.com/rejunity/tt04-LIF-neuron-telluride2023) | Single BLIF neuron | TT04 / CI2309 |
| [ChFrenkel/tinyODIN](https://github.com/ChFrenkel/tinyODIN) | 256 LIF neurons, 64k 4-bit synapses, minimal crossbar | RTL reference (ODIN family) |
| [ChFrenkel/ODIN](https://github.com/ChFrenkel/ODIN) | Original digital SNN processor (IEEE TBioCAS 2019) | Academic baseline |
| [Yogeeth/neuromorphic-lif-rtl](https://github.com/Yogeeth/neuromorphic-lif-rtl) | LIF + Poisson encoder + 1D systolic array | FPGA-oriented pedagogy |
| [metr0jw/Event-Driven-Spiking-Neural-Network-Accelerator-for-FPGA](https://github.com/metr0jw/Event-Driven-Spiking-Neural-Network-Accelerator-for-FPGA) | AC (accumulate) SNN + PyTorch; VHDL/Verilog mix + HLS | FPGA-first; 256 LIF array in integrated build |

### 2.4 Framework-scale (sim + RTL + research, not “clone and P&R”)

| Repository | Notes |
|------------|-------|
| [anulum/sc-neurocore](https://github.com/anulum/sc-neurocore) | Large neuromorphic stack: stochastic computing, formal properties, NIR bridge, many neuron models — use for **ideas and submodules**, not one-click GDS |
| [jeshraghian/ESSCIRC23-os-neuromorphic-tutorial](https://github.com/jeshraghian/ESSCIRC23-os-neuromorphic-tutorial) | Colab: snnTorch + **OpenLane on sky130** — pedagogy linking ML training to layout |

**Agent hint:** If the user said “spiky neural net on GitHub that’s actually useful,” start with **neuraedge** (actionable ASIC path) and cite **OpenSpike** (silicon proof).

---

## 3. Little CPUs, controllers, and SoC generators

### 3.1 Standalone CPU cores (Verilog or exportable)

| Repository | ISA | Size | Notes |
|------------|-----|------|-------|
| [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) | RV32 | Small | Yosys reference; used in OpenSpike |
| [olofk/serv](https://github.com/olofk/serv) | RV32 | Minimal bit-serial | Smallest “real” CPU |
| [SpinalHDL/VexRiscv](https://github.com/SpinalHDL/VexRiscv) | RV32/64 | Parametric | Generate Verilog then synth |
| [chipsalliance/rocket-chip](https://github.com/chipsalliance/rocket-chip) | RV64 | Large | Generator; tapeout-scale teams only |
| [openhwgroup/cv32e40p](https://github.com/openhwgroup/cv32e40p) | RV32 | Medium | OpenHW; SV |
| [stnolting/neorv32](https://github.com/stnolting/neorv32) | RV32 | SoC in VHDL | FPGA dev boards; export path via GHDL |
| [openrisc/mor1kx](https://github.com/openrisc/mor1kx) | OpenRISC | Medium | Classic open core |

### 3.2 SoC builders (emit Verilog + FPGA bitstreams)

| Repository | CPUs / peripherals | Output |
|------------|-------------------|--------|
| [enjoy-digital/litex](https://github.com/enjoy-digital/litex) | VexRiscv, PicoRV32, Rocket, … + LiteDRAM/Eth/PCIe | `build/*/gateware/*.v` |
| [litex-hub/litex-boards](https://github.com/litex-hub/litex-boards) | Board targets | Copy generated Verilog for ASIC experiments |

**Workflow:** Build for any FPGA target → take gateware Verilog → `syn_read_verilog` in chip-design-mcp → expect to fix **BRAM/inferred memories** for sky130.

### 3.3 Classic educational / benchmark cores

| Repository | Use |
|------------|-----|
| [VLSIDA/HighTide](https://github.com/VLSIDA/HighTide) | **8 designs**, LFSR → quad RISC-V; release Verilog + ORFS/sky130/gf180/ASAP7 configs (2025–2026 active) |
| [The-OpenROAD-Project/OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) `flow/designs` | Known-good OpenLane/ORFS benchmarks |
| [lowRISC/ibex](https://github.com/lowRISC/ibex) | Small RV32 (SystemVerilog) — widely studied |
| [pulp-platform/pulpino](https://github.com/pulp-platform/pulpino) | PULP family (research) |

---

## 4. Tapeout-proven or “real chip” open RTL

| Repository | What | License / notes |
|------------|------|-----------------|
| [baochip/baochip-1x](https://github.com/baochip/baochip-1x) | **Taped-out** open SoC elements (bunnie); `rtl/` frozen per `tapeout-*` tags | CERN-OHL-W; simulation-focused on `main` |
| [sfmth/OpenSpike](https://github.com/sfmth/OpenSpike) | Neuromorphic ASIC | See §2.2 |
| Tiny Tapeout run repos | One tile each | Search GitHub `tinytapeout tt09` / `tt10` |

Use these to **validate your flow** against known silicon, not as first compile targets on a laptop.

---

## 5. Aggregators and datasets

| Source | Content | Caveat |
|--------|---------|--------|
| [OpenCores](https://opencores.org) | Huge catalog of IP | Variable quality, stale projects; verify license and last update |
| [shariethernet/RTL_dataset](https://github.com/shariethernet/RTL_dataset) (NYU-MLDA lineage) | Leaf modules from OpenROAD designs + Yosys PPA CSV | ML/training, not integrated SoCs |
| [librelane/librelane](https://github.com/librelane/librelane) examples | Small designs with `config.json` | Copy flow configs with RTL |
| [efabless/openlane2](https://github.com/efabless/openlane2) | Example designs | Match OpenLane 2 / LibreLane docs |

**Awesome lists** (search periodically): `awesome-open-hardware`, `awesome-asic`, `awesome-fpga` on GitHub — good pointers, not quality guarantees.

---

## 6. Tiny Tapeout and hobby shuttles (2024–2026)

| Resource | URL / pattern |
|----------|----------------|
| Tiny Tapeout | https://tinytapeout.com — aggregator; pay-per-tile shuttles |
| Verilog template | [TinyTapeout/tt09-verilog-template](https://github.com/TinyTapeout/tt09-verilog-template) |
| Spiking example | [rejunity/tt05-spiking-neural-net](https://github.com/rejunity/tt05-spiking-neural-net) |
| Wokwi → TT | Browser entry for beginners |

**Complexity:** T1 in [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md) — ideal first **GDSII** path when your RTL fits tile area.

---

## 7. Chisel / Spinal generated cores (repos to fork)

| Project | URL | Typical export |
|---------|-----|----------------|
| Rocket Chip | https://github.com/chipsalliance/rocket-chip | Verilog via CIRCT |
| Chipyard | https://github.com/ucb-bar/chipyard | Full SoC generator workspace |
| SpinalHDL examples | https://github.com/SpinalHDL/SpinalExamples | Per-example Verilog |

**chip-design-mcp** does not run Scala/sbt. CI pattern: `sbt compile` → commit generated `*.v` in `build/` or use release artifacts.

---

## 8. Mixed-signal and analog (RTL adjacent)

Digital control for analog chips is still Verilog:

- Search **“OpenLane SAR ADC sky130”** — academic repos often bundle digital FSM + analog in Xschem (not pure RTL-only).
- **IHP SG13G2** RF/mm-wave: GDSFactory + PDK cells; digital control via standard flow.

For **pure RTL** neuromorphic + analog pad ring, use **LibreLane `Chip` flow** (padring) when moving beyond Tiny Tapeout tiles.

---

## 9. License and export checklist (before tapeout)

| Check | Question |
|-------|----------|
| SPDX | Is license compatible with your shuttle provider’s terms? |
| Patents | Academic repos may be research-only |
| Third-party RTL | LiteX/VexRiscv have their own licenses |
| Generated code | LLM Verilog needs human review + regression |
| PDK | Design rules are under NDA-like terms for some nodes; sky130/gf180 are open |

---

## 10. Suggested experiments (chip-design-mcp order)

| Week | RTL source | MCP sequence |
|------|------------|--------------|
| 1 | `depot_init` counter | `sim_*` → `syn_*` |
| 2 | [PicoRV32](https://github.com/YosysHQ/picorv32) single file | `syn_run` + `syn_stats` |
| 3 | [rejunity/tt05-spiking-neural-net](https://github.com/rejunity/tt05-spiking-neural-net) | Match Tiny Tapeout top; short OpenLane |
| 4 | [anykrver/neuraedge-](https://github.com/anykrver/neuraedge-) submodule | Cluster-only synth |
| 5 | [VLSIDA/HighTide](https://github.com/VLSIDA/HighTide) smallest design | Compare reports to published PPA |

---

## 11. Cross-links

| Doc | Topic |
|-----|-------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full RTL→GDSII pipeline |
| [PDK_GUIDE.md](PDK_GUIDE.md) | volare, libraries, macros |
| [docs/tools/synthesis.md](tools/synthesis.md) | `syn_*` |
| [docs/tools/place_route.md](tools/place_route.md) | `pr_*` |
| [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md) | KiCad vs ASIC, LiteX, OpenRAM, LibreLane |

*Last updated: 2026-05-31. Repository URLs and shuttle pricing change; verify upstream README before tapeout.*
