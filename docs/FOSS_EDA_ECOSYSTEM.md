# FOSS EDA ecosystem — creating RTL and getting to silicon (2026)

**Audience:** Operators and agents using chip-design-mcp who want to understand where RTL comes from, which open tools actually build chips, and how that relates to KiCad, FPGAs, and PDK macros.

**Tone:** This repo is a [superyacht magazine for silicon](DREAMING_IN_SILICON.md) — you are reading the **tool buyer's guide**, not signing a foundry contract.

**Companion:** [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md) — curated third-party Verilog/SystemVerilog repositories.  
**Fleet survey (Jan 2026):** [Baungarten-Leon, *Electronics* 15(5):1048](https://doi.org/10.3390/electronics15051048) — RTL-to-fabrication tool and PDK overview.  
**This repo implements:** orchestration only (Yosys, iverilog/cocotb, OpenLane Docker, Magic, netgen, OpenSTA) — see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. Two different “chips” (do not conflate)

| Domain | What you design | Primary FOSS CAD | Output | chip-design-mcp? |
|--------|-----------------|------------------|--------|------------------|
| **Printed circuit board (PCB)** | Components on a board | **KiCad** (schematic + layout) | Gerber / IPC-2581 | No — use **kicad-mcp** in fleet |
| **Integrated circuit (IC / ASIC)** | Transistors on a wafer | **Verilog + PDK + RTL2GDS** | GDSII | **Yes** — this server |

**KiCad does not synthesize ASIC RTL.** It places footprints, routes copper on FR4, and runs board-level DRC. A 2026 industry view: KiCad 10.x is viable for commercial 2–6 layer products when process and library governance are owned in-house; enterprise PLM integration remains a gap versus Altium (see community writeups, May 2026).

**Bridge cases (niche):**

- [galacticstudios/KiCadVerilog](https://github.com/galacticstudios/KiCadVerilog) — schematic netlist → Verilog for **retro discrete TTL** simulation, not FPGA/ASIC flows.
- [DLR-RY/kicad_firmware_generation](https://github.com/DLR-RY/kicad_firmware_generation) (2026) — schematic metadata → MCU **firmware**, not gate-level RTL.
- Fleet **kicad-mcp** — PCB automation; netlists can feed downstream tools but not OpenLane.

**Rule:** If the goal is **sky130 GDSII**, start in Verilog (or a generator that emits Verilog), not in KiCad.

---

## 2. How FOSS designs actually create RTL

RTL is not only “typing Verilog in Vim.” In 2026 the open stack supports several **creation paths**, all of which must eventually converge on **synthesizable Verilog/SystemVerilog** (or VHDL via plugins) for Yosys and OpenLane.

### 2.1 Hand-written HDL (baseline)

| Language | Typical use | Simulation | Synthesis into sky130 |
|----------|-------------|------------|------------------------|
| **Verilog-2005** | Legacy IP, OpenCores, course labs | Icarus, Verilator | Yosys (best supported) |
| **SystemVerilog** | Modern blocks, testbenches | Verilator, commercial | Yosys subset; full SV → **Tabby CAD Suite** / commercial |
| **VHDL** | EU academic, legacy IP | GHDL | Yosys VHDL plugin → RTLIL |

chip-design-mcp `syn_*` tools assume **Verilog** staged under the work dir. Export generators to `.v` before `syn_read_verilog`.

### 2.2 Generator languages (raise abstraction)

These are **software that writes hardware**. They excel at parameterized CPUs, SoCs, and repeat structures.

| Project | Language | Emits | Maturity (2026) | Notes |
|---------|----------|-------|-----------------|-------|
| [Chisel](https://www.chisel-lang.org/) / [chipsalliance/chisel](https://github.com/chipsalliance/chisel) | Scala embedded DSL | Verilog via **FIRRTL / CIRCT** | Production for research + industry adopters | v7.x line; strong CPU generator ecosystem (Rocket, etc.) |
| [SpinalHDL](https://github.com/SpinalHDL/SpinalHDL) | Scala | Verilog/VHDL | Widely used in EU open-hardware | Good for custom pipelines and SoCs |
| [Amaranth](https://github.com/amaranth-lang/amaranth) | Python | Verilog | Active | Successor spirit to nMigen; nice for small accelerators |
| [Migen](https://github.com/m-labs/migen) | Python | Verilog | Stable / legacy | Still core of LiteX |
| [LiteX](https://github.com/enjoy-digital/litex) | Python (Migen) | Verilog + FPGA bitstreams | **Primary open SoC builder** | DRAM/Ethernet/PCIe ecosystem via [litex-hub](https://github.com/litex-hub) |
| [CIRCT](https://github.com/llvm/circt) | MLIR dialects | Verilog | Infrastructure | Chisel/FIRRTL lowering target; industry interest |

**Typical LiteX workflow (FPGA-first, ASIC-possible):**

1. `python -m litex_boards.targets.<board>` — builds SoC (VexRiscv/PicoRV32/etc.).
2. Verilog lands in `build/<platform>/gateware/`.
3. For ASIC: point Yosys/OpenLane at top `*.v`; replace FPGA BRAM/inferred memories with **SRAM macros** (OpenRAM) or latch-based fallbacks for tiny demos.

**Chisel workflow:** `sbt` compile → FIRRTL → `firtool` → Verilog → same as any RTL.

chip-design-mcp does not run sbt/LiteX; **you generate Verilog offline**, upload or copy into `uploads/`, then run `syn_*` / `pr_*`.

### 2.3 High-level synthesis (C/C++ → RTL)

| Tool | License | Target | 2026 note |
|------|---------|--------|-----------|
| [Bambu (Panda)](https://github.com/ferrandi/Panda-bambu) | LGPL | FPGA + ASIC-oriented flows | Academic/industrial HLS; check PDK integration docs |
| LegUp | — | — | Historical; not the default path today |
| Vivado HLS / Intel HLS | Proprietary | — | Out of scope for FOSS doc |

HLS output quality and timing closure on sky130 still require expert review; treat as **experimental** unless a project ships a reproducible OpenLane config.

### 2.4 LLM-generated RTL (2026 caution)

Survey literature and fleet practice treat LLM Verilog as **untrusted input**: good for scaffolding, dangerous for tapeout without formal sim + synthesis + human review. Use `depot_init` templates or small modules first; run `sim_run_testbench` and `syn_run` before any OpenLane job. Never skip license checks on generated code.

### 2.5 Analog / mixed-signal (not “RTL”, but same silicon)

Mixed-signal chips combine:

- **Schematic-driven** blocks (Xschem → SPICE → layout in Magic/KLayout)
- **Digital RTL** (Verilog → Yosys → OpenROAD)

Reference open flow (JKU / CERN training materials, 2025–2026): **IIC-OSIC-TOOLS** Docker bundles Xschem, Magic, KLayout, ngspice, OpenRAM, sky130 and **IHP SG13G2** partial support. Example: 12-bit SAR ADC tapeout stories using Xschem custom cells + OpenLane for digital control — see CERN/indico mixed-signal tutorials.

**GDSFactory** ([gdsfactory](https://github.com/gdsfactory/gdsfactory)) — Pythonic layout (photonics, mm-wave cells); complements RTL flows for pad frames and RF structures.

chip-design-mcp **does not** run Xschem/ngspice; digital verification tools still apply to synthesized netlists extracted from mixed designs.

---

## 3. Front-end: simulate and verify before synthesis

| Tool | Role | chip-design-mcp |
|------|------|-----------------|
| [Verilator](https://www.veripool.org/verilator/) | Fast cycle-accurate C++ sim | Not wrapped (use offline); LiteX default |
| [Icarus Verilog](https://steveicarus.github.io/iverilog/) | Event-driven sim | **sim_run_testbench** (via subprocess) |
| [cocotb](https://www.cocotb.org/) | Python testbenches | **sim_*** tools |
| [Verilator](https://www.veripool.org/verilator/) + cocotb | Cosim | Manual |
| [SymbiYosys](https://github.com/YosysHQ/sby) | Formal (Yosys-based) | **verify_formal** (smoke / equivalence style) |
| [GHDL](https://ghdl.github.io/ghdl/) | VHDL sim | External |
| [GTKWave](https://github.com/gtkwave/gtkwave) | Waveforms | View `.vcd` from sim |

**OSS CAD Suite** ([YosysHQ/oss-cad-suite-build](https://github.com/YosysHQ/oss-cad-suite-build)) — single download with Yosys, Verilator, SymbiYosys, ABC; recommended on Windows/WSL when not using chip-design-mcp’s `install-eda.ps1` subset.

---

## 4. Logic synthesis (RTL → gates)

| Tool | Version line (2026) | Function |
|------|---------------------|----------|
| [Yosys](https://github.com/YosysHQ/yosys) | v0.63+ (Mar 2026) | RTLIL-based synthesis; sky130 `abc9` mapping |
| **ABC** | (bundled) | Technology mapping |
| [Tabby CAD Suite](https://www.yosyshq.com/tabby-cad-datasheet) | Commercial OSS-adjacent | Industrial SV/VHDL parsers |

chip-design-mcp **`syn_run`** builds a Yosys script: `read_verilog` → `hierarchy` → `proc/fsm/memory/techmap` → `abc9` + `.lib` → `stat` → `write_verilog`.

**Standard-cell libraries** live in the PDK (not a separate “macro CAD” for logic): e.g. `sky130_fd_sc_hd` (~437 cells). Explore via **`cells_*`** tools when `PDK_ROOT` is set.

---

## 5. FPGA implementation (programmable silicon, not GDSII)

FOSS **FPGA** flow (no mask, no foundry):

```
Verilog → Yosys (synth_<family>) → JSON/ASC → nextpnr → bitstream
```

| Tool | Families (2026) |
|------|-----------------|
| [nextpnr](https://github.com/YosysHQ/nextpnr) | iCE40, ECP5, Nexus, Gowin, GateMate, NG-Ultra (500k LUT milestone, 2026), experimental Cyclone V / MachXO2 / **Xilinx 7-series (Project X-Ray)** |
| [Project IceStorm](https://github.com/YosysHQ/icestorm) | iCE40 bitgen |
| [prjtrellis](https://github.com/YosysHQ/prjtrellis) | Lattice ECP5/MachXO2 |
| [prjxray](https://github.com/f4pga/prjxray) | Xilinx 7-series (partial; no PCIe hard IP, etc.) |

**Vendor tools (Vivado 2026.x):** Still required for proprietary Xilinx/Intel hard IP and full timing signoff. Community note (2026): Linux CI users on free Vivado should audit primitive coverage; Yosys+nextpnr is a **partial** substitute for LUT/BRAM-centric 7-series designs only.

**LiteX** can target both vendor toolchains and open **nextpnr** backends — best path to “I built my own SoC” on a dev board before ASIC.

FPGA bitstreams are **out of scope** for chip-design-mcp; use LiteX/nextpnr locally, then reuse generated Verilog for ASIC experiments.

---

## 6. ASIC physical design (RTL → GDSII)

### 6.1 Engines

| Tool | Role |
|------|------|
| [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) | Floorplan, placement, CTS, routing, STA integration |
| [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) | Static timing |
| [Magic](https://github.com/rtimothyedwards/magic) | Layout viewer, DRC, stream-out |
| [KLayout](https://github.com/KLayout/klayout) | DRC/LVS, mask tools, DEF/GDS |
| [Netgen](http://opencircuitdesign.com/netgen/) | LVS |

### 6.2 Flow packaging (which “Lane” in 2026?)

| Project | Maintainer / era | Status (2026) | chip-design-mcp |
|---------|------------------|---------------|-----------------|
| [OpenLane 1](https://github.com/The-OpenROAD-Project/OpenLane) | Classic efabless flow | Legacy reference | — |
| [OpenLane 2](https://github.com/efabless/openlane2) | Efabless infrastructure | Active library; OpenMPW/chipIgnite | — |
| [LibreLane](https://github.com/librelane/librelane) | FOSSi Foundation | **Successor** to OpenLane 2 (v3.x, Apr 2026); Python `Flow` API | Compatible ecosystem |
| [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) | ORFS | Reference Makefile flows per PDK | Manual |
| [HighTide](https://github.com/VLSIDA/HighTide) | VLSIDA | Benchmark designs + ORFS configs (sky130, gf180, ASAP7) | Good regression corpus |

**This server** invokes **`ghcr.io/the-openroad-project/openlane:latest`** via `pr_run_flow` — same conceptual stack (Yosys + OpenROAD + Magic). When migrating configs, compare against **LibreLane/OpenLane 2** `config.json` semantics.

### 6.3 PDK installation (macros + rules + std cells)

| Tool | Purpose |
|------|---------|
| [open_pdks](https://github.com/efabless/open_pdks) | Build sky130/gf180 PDK artifacts |
| [volare](https://github.com/chipfoundry/volare) | Versioned prebuilt PDK snapshots (archived repo; still widely used) |
| [ciel](https://github.com/fossi-foundation/ciel) | FOSSi Foundation PDK release channel (successor direction) |
| [google/skywater-pdk](https://github.com/google/skywater-pdk) | Source documentation |

**Libraries inside sky130** (digital + more):

| Library | Contents |
|---------|----------|
| `sky130_fd_sc_hd` | **Standard cells** for synthesis/P&R |
| `sky130_fd_sc_hs` | Higher-speed variant |
| `sky130_fd_sc_hvl` | Level shifters |
| `sky130_fd_io` | IO pads |
| `sky130_fd_pr` | Primitives (transistors, passives) |
| `sky130_sram_macros` | Pre-built SRAM hard macros |

Enable via `volare enable --pdk sky130 <hash>` — automated in `scripts/install-eda.ps1`. **`chip_available_pdks`** reports install state.

**Other open PDKs (2026):**

| PDK | Node | Notes |
|-----|------|-------|
| **gf180mcu** | 180 nm | MCU-oriented; Tiny Tapeout shuttles |
| **ihp-sg13g2** | 130 nm BiCMOS | RF/analog strength; digital + special devices |
| **ICsprout55** | 55 nm preview | [openecos-projects/icsprout55-pdk](https://github.com/openecos-projects/icsprout55-pdk) — **not** commercial mass production; academic/small batch |
| **ASAP7 / NanGate45** | Academic | OpenROAD research; not hobby shuttle |

### 6.4 Memory compilers (hard macros)

| Tool | Output | Use |
|------|--------|-----|
| [OpenRAM](https://github.com/VLSIDA/OpenRAM) | SRAM GDS, LEF, Liberty, SPICE | **OpenSpike**-class chips; attach as macro in OpenLane |
| [OpenXRAM](https://github.com/RIOSLaboratory/OpenXRAM) | Research compiler | Alternative generator stack |

Digital flows often **blackbox** SRAMs for place-and-route; OpenRAM-generated macros must match the PDK and be declared in OpenLane `config.json` (`MACROS`, `EXTRA_LEFS`, etc.).

---

## 7. “Little CPUs” and SoC building blocks (FOSS)

| Core | Generator / source | Typical scale | ASIC note |
|------|-------------------|---------------|-----------|
| [PicoRV32](https://github.com/YosysHQ/picorv32) | Verilog | Tiny RV32 | Excellent Yosys smoke test |
| [SERV](https://github.com/olofk/serv) | Verilog | Minimal RV32 | Smallest useful CPU |
| [VexRiscv](https://github.com/SpinalHDL/VexRiscv) | SpinalHDL → Verilog | Configurable RV32/64 | Common in LiteX |
| [Rocket Chip](https://github.com/chipsalliance/rocket-chip) | Chisel | Full application cores | Large; research ASICs |
| [CV32E40P](https://github.com/openhwgroup/cv32e40p) | SystemVerilog | OpenHW RISC-V | Formal-friendly |
| [BlackParrot](https://github.com/black-parrot/black-parrot) | SystemVerilog | Multicore research | Academic |
| [Mor1kx](https://github.com/openrisc/mor1kx) | Verilog | OpenRISC | Legacy open ISA |
| [NEORV32](https://github.com/stnolting/neorv32) | VHDL | All-in-one SoC | Good dev board → Verilog export path via GHDL/Yosys |

**SoC wrappers:** LiteX generates interconnect + peripherals around these cores; **OpenSpike** uses **PicoRV32** + custom SNN fabric (taped out sky130).

---

## 8. Specialist CAD you asked about (macro libs, FPGA, CPUs)

| Need | Tool category | FOSS answer |
|------|---------------|-------------|
| **Logic standard cells** | PDK lib | sky130_hd Verilog + LEF/GDS in PDK_ROOT |
| **SRAM macros** | Compiler | OpenRAM |
| **IO pads** | PDK | `sky130_fd_io` |
| **Hard IP (PCIe, DDR, …)** | Vendor | Generally **not** open for ASIC; avoid for first tapeout |
| **FPGA mapping** | Yosys + nextpnr | See §5 |
| **CPU + buses** | LiteX / Chisel | See §2.2, §7 |
| **PCB for the dev board** | KiCad | kicad-mcp |
| **Analog macros** | Hand layout + Xschem | Magic/KLayout; not Yosys |
| **DRC/LVS decks** | PDK + tools | Magic/KLayout runsets under PDK |

There is **no single “KiCad for silicon logic.”** The specialist stack is **PDK + Yosys + OpenROAD (+ OpenLane/LibreLane) + Magic/KLayout**.

---

## 9. Recommended learning paths (2026)

| Goal | Path |
|------|------|
| First Yosys + sim | `depot_init` → **PicoRV32** or counter in repo |
| First FPGA SoC | **LiteX** on iCE40/ECP5 with nextpnr |
| First ASIC GDS (small) | Tiny Tapeout template + OpenLane/LibreLane |
| First ASIC GDS (serious digital) | **HighTide** or ORFS `flow/designs` |
| Neuromorphic RTL | **neuraedge** (study) → **OpenSpike** (tapeout reference) |
| Mixed-signal | IIC-OSIC-TOOLS + IHP/sky130 training labs |
| Tool survey paper | MDPI *Electronics* 2026 open EDA review |

---

## 10. Mapping tools → chip-design-mcp

| Stage | External FOSS tool | MCP surface |
|-------|-------------------|-------------|
| RTL ingest | (your generator) | Upload API, `depot_init` |
| Sim | iverilog + cocotb | `sim_*` |
| Synth | Yosys | `syn_*` |
| P&R | OpenLane Docker | `pr_*` |
| STA | OpenSTA | `verify_timing` |
| DRC/LVS | Magic, netgen | `verify_*` |
| Discovery | — | `chip_status`, `chip_available_pdks`, `chip_pipeline_stages` |
| Cells | PDK Verilog libs | `cells_*` |

**Install on Windows:** [INSTALL.md](../INSTALL.md) — `install-eda.ps1` pulls Yosys, Docker/OpenLane, volare sky130.

**Fleet PCB partner:** [kicad-mcp](https://github.com/sandraschi/kicad-mcp) — netlist export for boards that **host** your packaged ASIC or FPGA; not a substitute for RTL2GDS.

---

## 11. References and further reading

- FOSSi Foundation — [LibreLane docs](https://librelane.readthedocs.io/), Matrix chat, events.
- Zero to ASIC — [zerotoasiccourse.com](https://zerotoasiccourse.com) — pedagogy aligned with OpenLane.
- VLSIDA — [chip-tutorials/sky130.md](https://github.com/VLSIDA/chip-tutorials/blob/main/sky130.md) — PDK layer and stdcell detail.
- JKU ICD — [IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) — analog/mixed-signal container (2026.02 release train).
- YosysHQ — [nextpnr 0.10](https://github.com/YosysHQ/nextpnr/releases) (Mar 2026), NG-Ultra support news.

*Last updated: 2026-05-31 — tool versions change; verify release pages before pinning flows.*
