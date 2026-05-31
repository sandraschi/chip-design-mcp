# Production Paths — Getting Your Chip Manufactured

> **Expanded guide (recommended):** [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md) — tiles/slices, complexity & density tiers, **free vs commercial** providers, step-by-step submission, and fab/broker directory.

This page is a **shorter comparison** of the main open-PDK paths. All paths here target **130nm** (SkyWater) or **180nm** (GF) — mature nodes with open PDKs and affordable shuttle runs.

## Quick Comparison

| Path | Cost | Area | Lead Time | Chips | Best For |
|------|------|------|-----------|-------|----------|
| **Tiny Tapeout** | ~$100-500 | 0.016mm²/tile | 6-9 months | 1 chip + dev kit | Hobby, education, prototyping |
| **ChipFoundry (Efabless)** | ~$15k | ~15mm² | 6 months | 100 QFN or bare die | Startups, real products |
| **Multi-Project Wafer (MPW)** | ~$50-150k/mm² | Any | 3-6 months | Full wafers | Volume production |
| **Full mask set** | ~$500k-2M | Any | 2-3 months | Unlimited | High volume |

---

## 1. Tiny Tapeout — Best for Hobby & Education

### What It Is

Tiny Tapeout takes many small designs, packs them into a shared carrier chip,
and sends the whole thing to SkyWater for fabrication. You get back a dev kit
with your design as one of many "tiles" on the chip.

### How It Works

```
Your Verilog → OpenLane → GDS tile (160μm × 100μm)
    ↓
Tiny Tapeout collects 100-400 tiles from different designers
    ↓
Carrier chip with all tiles is taped out to SkyWater 130nm
    ↓
Dev kits assembled (chip on PCB with RP2040 controller)
    ↓
You receive a working chip with YOUR design running on it!
```

### Current Shuttles (May 2026)

| Shuttle | PDK | Closes | Status |
|---------|-----|--------|--------|
| **GF26a** | GF180 | June 2026 | Open for submissions |
| **SKY26c** | Sky130 | June 2026 | Open |
| **SKY26b** | Sky130 | — | In fabrication |
| **IHP26a** | IHP 130nm BiCMOS | — | In fabrication |

### Costs (from tinytapeout.com)

| Item | Price |
|------|-------|
| 1 tile (160×100μm) + 1 dev kit | ~$100 early bird |
| Extra tiles | ~$20-50 each |
| Analog slot (1×2 tiles) | ~$150-300 |
| Extra dev kit PCBs | ~$50 each |

Each tile fits approximately **1000 digital logic gates**.
1 tile ≈ 16,000μm² = ~10,000 transistors in Sky130.

### What You Get

- A working chip with your design fabricated on Sky130 or GF180
- Dev kit PCB (RP2040-based) for testing and demonstrating
- Breakout board with the bare chip accessible
- Online documentation template (GitHub Pages)
- Community support via Discord

### Limitations

- **One chip only** (you can buy extra dev kits but each is ~$50)
- Small design area (1-4 tiles typical)
- 6-12 month wait (fabrication + assembly takes time)
- No control over the carrier chip's clock, I/O assignment
- **WiFi/bluetooth/etc. not possible** — pure digital/analog design

### How to Submit

```
1. Design using Wokwi (browser) or Verilog/HDL
2. Fork the submission template on GitHub
3. Push your code and let GitHub Actions run OpenLane
4. Submit via app.tinytapeout.com
5. Pay and wait for fabrication
```

### Links

- Website: https://tinytapeout.com
- Calculator: https://app.tinytapeout.com/calculator
- Discord: https://discord.gg/qZHPrPsmt6
- Templates: https://github.com/TinyTapeout

---

## 2. ChipFoundry (formerly Efabless) — Best for Startups

### What It Is

ChipFoundry's **chipIgnite** program provides a standardized SoC platform
with a complete RISC-V subsystem plus a user design area. You design your
custom logic, drop it into their template, and get back packaged chips.

### How It Works

```
Your custom RTL → OpenLane → GDS
    ↓
ChipFoundry integrates your logic into their SoC template
    (RISC-V CPU + SRAM + peripherals + your design)
    ↓
Full mask set sent to SkyWater 130nm
    ↓
100 packaged QFN chips or bare die returned
    ↓
Evaluation board + software SDK included
```

### Key Specifications

| Spec | Value |
|------|-------|
| **Design area** | Up to 15mm² |
| **I/O** | 38 configurable digital/analog |
| **Package** | 100-pin QFN or bare die |
| **Price** | ~$14,950 per tapeout |
| **Evaluation board** | Included |
| **EDA tools** | Open-source (OpenLane) or commercial |

### What $15k Gets You

- Full RTL-to-GDSII open-source flow
- Pre-built RISC-V SoC with SRAM, SPI, UART, I2C, GPIO
- 15mm² user design area
- 100 packaged chips
- Evaluation board and software SDK
- Debug and bring-up support

### When to Use

- You need more than 1000 gates
- Your design requires analog/mixed-signal
- You want a packaged chip (QFN) for PCB integration
- You need a RISC-V CPU to run software alongside your logic
- Small business or startup building a real product

### How It Changed (Efabless Closure)

In 2025, Efabless was acquired by UmbraLogic/ChipFoundry.
The chipIgnite program continues under the new ownership.
The open-source MPW program that was free for open-source designs
has been replaced by the commercial chipIgnite service.

### Links

- Website: https://chipfoundry.io/chipignite
- Knowledge base: https://platform.chipfoundry.io/knowledge-base

---

## 3. Custom MPW — For Volume Prototyping

### What It Is

Direct engagement with a foundry or broker to put your design on a
multi-project wafer (MPW) shuttle. You split the mask cost with other
customers and only pay for your area.

### Foundry Options for 130nm

| Foundry | Node | MPW Cost (est.) | Min Area |
|---------|------|------------------|----------|
| **SkyWater** | 130nm | ~$50K-150K/mm² | 1mm² |
| **X-Fab** | 180nm | ~$100K/mm² | 1mm² |
| **Tower/Jazz** | 180nm | ~$80K/mm² | 1mm² |
| **TSMC** | 180nm | ~$200K/mm² | 5mm² |

### What You Need

- **PDK access**: NDA with foundry (these are not open — you sign for them)
- **Memory compiler**: SRAM, ROM generators (usually extra cost)
- **I/O library**: ESD-protected pads for your package
- **Package**: QFN, BGA, or custom package (extra NRE)
- **Test**: Probe card, test program (significant cost)

### Typical Timeline

```
Week 1-4:    Design finalization, tapeout preparation
Week 5:      Tapeout (GDSII handoff)
Week 6-12:   Mask making
Week 13-20:  Wafer fabrication (Sky130 ~18 weeks)
Week 21-24:  Wafer sort, packaging, test
Week 25-28:  Shipment
```

### Brokers

- **Muse Semiconductor**: Commercial broker for small-volume ASICs
- **CMP (France)**: MPW service for universities and research
- **Europractice**: EU-based MPW broker
- **Mosis**: US-based MPW broker

---

## 4. Full Mask Set — High Volume

For production volumes above 10,000 units, a full mask set becomes
cost-effective. At 130nm, a mask set costs $500k-2M depending on
the number of metal layers and complexity.

This path is beyond the scope of chip-design-mcp but worth knowing for
the roadmap.

---

## Practical Decision Flowchart

```
What are you building?

A simple digital circuit?
├── <1000 gates, first chip → Tiny Tapeout (~$100)
├── <1000 gates, analog     → Tiny Tapeout analog slot (~$300)
└── >1000 gates, complex    → ChipFoundry chipIgnite (~$15k)

A product/startup?
├── Need a RISC-V CPU + custom logic → ChipFoundry (~$15k)
├── Need custom SoC, high performance → Custom MPW ($50k+)
└── Need volume >10k units            → Full mask set ($500k+)

For learning?
├── Complete beginner → Tiny Tapeout Wokwi tutorial (free)
├── Learning RTL      → Tiny Tapeout Verilog template (free)
└── Learning PDK      → chip-design-mcp + local simulation (free)
```

## Cost Breakdown: Tiny Tapeout vs ChipFoundry

| Cost Item | Tiny Tapeout | ChipFoundry |
|-----------|-------------|-------------|
| **Design entry** | ~$100 (1 tile) | ~$15k (full chip) |
| **Per unit cost** | ~$50 (extra dev kits) | ~$150 (per chip, all 100) |
| **Total chips** | 1 | 100 |
| **Chip area** | 0.016mm² | 15mm² |
| **Time** | 6-9 months | 6 months |
| **Design complexity** | Very limited | Full SoC |
| **Eval board** | Included | Included |
| **Suitable for** | Learning, hobby | MVP prototypes |
| **RoHS/commercial** | Hobby grade | Commercial grade |

## Real-World Examples

### Tiny Tapeout Successes

- **TT08 demoscene**: Graphics demos running on fabricated silicon
- **RISC-V CPUs**: Multiple tiny RISC-V cores fabricated and verified
- **FPGA-like configurable logic**: CPLD-like designs in 130nm
- **Sensor interfaces**: I2C/SPI/UART controllers
- **PWM generators**: Servo controllers, audio tone generators

### ChipFoundry/Efabless Successes

- **OpenTitan**: Google's open-source secure chip
- **PicoRV32**: Commercial RISC-V implementations
- **Various AI accelerators**: Edge ML inference chips
- **IoT sensor controllers**: Mixed-signal designs with custom analog

## Next Steps After Your First Chip

```
Tiny Tapeout → Learned the flow
    ↓
ChipFoundry → Built a real product
    ↓
Custom MPW → Volume production
    ↓
Full mask set → High volume, low unit cost
    ↓
Your company → Fabless semiconductor company
```

Each step is a 10x cost multiplier — but also a 10x capability increase.
Start with Tiny Tapeout, learn the flow, build confidence, then scale.
