# PDK Guide — Process Design Kits for Open-Source Chip Design

## What is a PDK?

A **Process Design Kit (PDK)** is the bridge between your chip design and the
fabrication foundry. It's a collection of files provided by the foundry that
model their manufacturing process so your EDA tools can produce correct,
manufacturable layouts.

Think of it as the "driver" for chip fabrication — without it, your EDA tools
don't know what transistors exist, what rules to follow, or how to verify your
design will actually work on silicon.

## What's Inside a PDK

```
sky130A/
├── libs.ref/                     # Reference libraries (foundry-provided)
│   └── sky130_fd_sc_hd/          # Standard digital cell library
│       ├── lef/                  # Abstract layout views (for routing tools)
│       ├── gds/                  # Full GDSII layout of each cell
│       ├── verilog/              # Verilog models for each cell
│       ├── liberty/              # Timing/power models (.lib files)
│       ├── spice/                # SPICE netlists for simulation
│       └── cdl/                  # CDL netlists for LVS
│
├── libs.tech/                    # Technology files (tool-specific)
│   ├── magic/                    # Magic layout editor tech file
│   │   └── sky130A.tech          # Layers, colors, DRC rules
│   ├── netgen/                   # netgen LVS setup
│   ├── klayout/                  # KLayout DRC/LVS scripts
│   └── openlane/                 # OpenLane PDK integration
│
└── soic/                         # I/O pad library
    └── sky130_fd_io/
```

## PDK Components (Detail)

### 1. Primitive Device Models

Transistors, resistors, capacitors, diodes — the basic building blocks:

| Device | What it is | Provided as |
|--------|-----------|-------------|
| **NMOS/PMOS FETs** | Standard logic transistors (1.8V core, 5V I/O) | SPICE models (.lib) |
| **Low-VT FETs** | Faster switching, higher leakage | SPICE models |
| **High-VT FETs** | Slower switching, lower leakage | SPICE models |
| **Native FETs** | Zero-threshold voltage | SPICE models |
| **HV FETs** | 10V-20V transistors for analog/power | SPICE models |
| **MiM capacitors** | Metal-insulator-metal capacitors | PCells + SPICE |
| **VPP capacitors** | Vertical parallel plate capacitors | PCells + SPICE |
| **Resistors** | P+/N+ poly and diffusion resistors | PCells + SPICE |
| **Diodes** | Junction diodes, ESD diodes | PCells + SPICE |
| **BJTs** | NPN/PNP bipolar transistors | SPICE models |

### 2. Digital Standard Cell Libraries

Pre-designed, characterized logic gates. SkyWater 130nm HD (High Density):

| Category | Cells | Examples |
|----------|-------|---------|
| **Combinational** | AND, OR, NAND, NOR, XOR, XNOR, MUX, AOI, OAI | `sky130_fd_sc_hd__nand2_1` |
| **Sequential** | DFF, DFF with set/reset, latches | `sky130_fd_sc_hd__dfxtp_1` |
| **Buffers** | Clock buffers, general buffers | `sky130_fd_sc_hd__buf_1` |
| **Inverters** | Single, multi-stage | `sky130_fd_sc_hd__inv_1` |
| **Special** | Fill cells, tap cells, decap, antenna diodes | `sky130_fd_sc_hd__fill_1` |

Each cell is provided in multiple **drive strengths** (X1, X2, X4, X8):
- Stronger drive = larger area = faster signal, more power
- Synthesis chooses appropriate drive for each net

### 3. Technology Data

| Component | Purpose |
|-----------|---------|
| **Layer definitions** | Names, GDS numbers, purpose pairs for each mask layer |
| **Design Rules** | Minimum widths, spacings, enclosures, overlaps |
| **Process constraints** | Via sizes, metal stack, minimum area |
| **Electrical rules** | Current density limits, antenna ratios |

### 4. Verification Decks

| Check | Tool | What it verifies |
|-------|------|------------------|
| **DRC** | Magic / KLayout / Calibre | Physical rules: metal spacing, via enclosure, etc. |
| **LVS** | netgen / Calibre | Layout matches schematic connectivity |
| **Antenna** | Magic / KLayout | Metal antennas won't damage transistor gates |
| **ERC** | Magic | Electrical rules: floating nodes, power connectivity |

### 5. Liberty Timing Files

The `.lib` files describe each cell's timing under different conditions:

| Corner | Temperature | Voltage | Use case |
|--------|------------|---------|----------|
| **tt_025C_1v80** | 25°C | 1.80V | Typical — main design target |
| **ff_n40C_1v95** | -40°C | 1.95V | Fast — setup hold analysis |
| **ss_100C_1v60** | 100°C | 1.60V | Slow — max delay analysis |
| **ff_n40C_1v65** | -40°C | 1.65V | Fast, low voltage |

Each corner provides: rise/fall delays, setup/hold times, power consumption,
output slew, input capacitance for every pin-cell combination.

## The SkyWater SKY130 PDK

### Key Facts

| Attribute | Value |
|-----------|-------|
| **Node** | 130nm (actual drawn gate length) |
| **Metal layers** | 5 (met1-met5) + 1 local interconnect (li) |
| **Vt options** | Low, standard, high, native |
| **Core voltage** | 1.8V |
| **I/O voltage** | 2.5V, 5V |
| **HV options** | 10V, 16V, 20V |
| **License** | Apache 2.0 (fully open-source) |
| **Digital cells** | ~500 standard cells in HD library |
| **Memo** | OpenRAM, SRAM compilers available |

### Installation

```bash
# Via volare (recommended — handles PDK_ROOT conventions)
pip install volare
volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095
# Must be a full 40-char open_pdks commit (volare ls-remote --pdk sky130). Short prefixes fail.

# Verify
echo $PDK_ROOT     # Should point to volare's install dir
ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog/
```

### What You Get

After install, `$PDK_ROOT/sky130A/` contains:
- Complete standard cell library (GDS, LEF, Verilog, Liberty)
- Technology files for Magic, KLayout, netgen, OpenLane
- Device SPICE models for analog simulation
- I/O pad library with ESD protection
- DRC/LVS/antenna decks

## Other Open PDKs

### GF180MCU (GlobalFoundries 180nm)

| Attribute | Value |
|-----------|-------|
| **Node** | 180nm |
| **Voltage** | 1.8V core, 5V I/O |
| **License** | Apache 2.0 |
| **Cells** | 300+ standard cells |
| **Install** | `volare enable --pdk gf180mcu` |

### IHP SG13G2 (IHP 130nm BiCMOS)

| Attribute | Value |
|-----------|-------|
| **Node** | 130nm BiCMOS |
| **Special** | SiGe HBT bipolar transistors |
| **License** | Open (IHP) |
| **Use case** | RF, analog, high-speed digital |
| **Install** | `volare enable --pdk ihp-sg13g2` |

## PDK vs Process: What's the Difference?

| Term | Meaning |
|------|---------|
| **Process node** | The manufacturing technology (e.g. "130nm") |
| **PDK** | The specific set of models/rules for running a design |
| **Foundry** | The company that fabricates the chip (e.g. SkyWater) |
| **Shuttle** | Multi-project wafer — shared run, lower cost |

"130nm" is a process. "sky130A" is a PDK for that process.

## Common PDK Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| **Missing DRC deck** | PDK not fully installed | Re-run volare enable |
| **Liberty file not found** | Wrong path in synthesis script | Point to correct .lib in PDK |
| **LVS fails** | Wrong CDL netlist path | Verify PDK install path |
| **$PDK_ROOT not set** | Shell not configured | Add to ~/.bashrc or ~/.zshrc |
| **Wrong magic tech file** | PDK version mismatch | Use volare to install matching version |
