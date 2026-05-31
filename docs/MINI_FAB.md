# Mini Fab — Approaches to Small-Run Chip Fabrication

The term **"mini fab"** covers several overlapping concepts for small-volume
chip manufacturing. This guide clarifies what each means and what's realistic
for 130nm open-source designs.

---

## 1. The "Real" Mini Fab — Shrinking the Fab Itself

Several projects aim to build physically small semiconductor fabrication
facilities for small batch sizes (50-500 wafers vs. the 50,000-wafer runs
of TSMC and Samsung).

### Active Projects

| Project | Approach | Node | Status |
|---------|----------|------|--------|
| **SkyWater Mini Fab** (Minnesota) | Shrunk traditional fab | 130nm | ~1000 WSPW capacity |
| **X-Fab Mini Fabs** | Smaller 150mm lines | 180nm-1μm | Commercial |
| **Danfoss / Fraunhofer** | Pilot lines for MEMS/Power | Various | EU-funded |
| **TinyFab** (concept) | Desktop fab for education | µm-scale | Research only |

### What a Mini Fab Can Do

- **Small runs**: 25-100 wafers instead of 10,000+
- **Fast turnaround**: 2-4 weeks instead of 12-18
- **Flexible process**: Can run different designs on the same line
- **Research/education**: Support for university and pilot production

### Limitations

- **Still expensive**: A mini fab costs $10M-100M+ to build
- **Limited nodes**: Most are at 180nm+
- **Not truly "mini"**: The smallest fabs are still 10,000sq ft+
- **No consumer access**: You can't just ship them a GDSII file

### Relevance to chip-design-mcp

Mini fabs exist for internal or partner use. For individual designers,
the relevant interface is through **shuttle brokers** (Tiny Tapeout,
ChipFoundry) who pool designs to fill a shared wafer, not walking into a
fab yourself.

---

## 2. Multi-Project Wafer (MPW) Shuttles — The Practical Mini Fab

This is the **real approach** for small-run production with open-source PDKs.

### How MPW Works

```
Designer A    Designer B    Designer C    Designer D
    |             |             |             |
    ↓             ↓             ↓             ↓
  GDSII         GDSII         GDSII         GDSII
    |             |             |             |
    └─────────────┴─────────────┴─────────────┘
                        ↓
              Wafer with 4 different designs
                        ↓
              Dice → Individual chips per designer
```

Each designer pays only for their fraction of the mask set.
At 130nm, a full mask set costs ~$500k — split across 10 designers,
each pays ~$50k. Split across 400 (Tiny Tapeout model), each pays ~$100.

### Active 130nm Shuttle Services (2026)

| Service | PDK | Min Cost | Min Area | Frequency |
|---------|-----|----------|----------|-----------|
| **Tiny Tapeout** | Sky130 / GF180 / IHP | ~$100 | 0.016mm² | ~4 shuttles/year |
| **ChipFoundry** | Sky130 | ~$15k | ~15mm² | ~4 shuttles/year |
| **CMP (France)** | Sky130 / TSMC 180nm | ~€10k | 1mm² | ~2 shuttles/year |
| **Europractice** | Sky130 / X-Fab | ~€8k | 1mm² | ~3 shuttles/year |
| **Muse Semiconductor** | Sky130 / Various | ~$30k | Custom | On request |

---

## 3. "Desktop Fab" — Not Real (Yet)

### What Exists

- **Nanofabrication tools**: Electron beam litho, inkjet printing
- **PCB fabs**: Standard PCB houses can do 100μm traces
- **Organic electronics**: Printed circuits on flexible substrates

### What Doesn't Exist

- A desktop machine that fabricates CMOS chips at 130nm
- Any realistic path to "Print your own chip" at home (May 2026)

### Why Not

| Requirement | 130nm CMOS | Desktop Reality |
|-------------|------------|-----------------|
| **Feature resolution** | 130nm | ~10μm (best inkjet) |
| **Alignment** | <10nm | ~1μm |
| **Cleanroom** | Class 1 (no dust) | Open air |
| **Chemical purity** | Parts-per-trillion | Lab grade |
| **Temperature control** | ±0.1°C | Room |
| **Layers** | 20-30 masks | 1-2 layers |
| **Doping** | Ion implant | Diffusion (poor)
| **Yield** | >95% | <1% (lab) |

### When It Might Exist

| Timeline | What Changes |
|----------|-------------|
| **2030+** | Simple organic transistors on flexible substrate (desktop) |
| **2040+** | Low-performance CMOS on personal fab? |
| **Never** | 130nm+ performance CMOS on desktop |

---

## 4. The xFab Model — Photonic/Laser Fabs

A related concept is **xFab** (cross-fab) — a network of small specialized
fabs for photonics, MEMS, power devices, and sensors, rather than general
CMOS logic. Each is a "mini fab" for its domain.

### Relevance

If your chip needs MEMS (micro-mirrors, accelerometers) combined with
CMOS logic, you'd design the logic in Sky130 via Tiny Tapeout and integrate
with a MEMS fab for the physical layer. This is advanced multi-chip
integration.

---

## 5. The Real Path for Individual Designers

```
Step 1: Design (Verilog + chip-design-mcp)
Step 2: Simulate (cocotb + iverilog)
Step 3: Synthesize (Yosys)
Step 4: Place & Route (OpenLane)
Step 5: Verify (DRC/LVS)
Step 6: Export GDSII
Step 7: Submit to Tiny Tapeout (~$100)
Step 8: Wait 6-9 months
Step 9: Receive working chip!
```

This is the **only realistic path for individuals** to get a 130nm chip
fabricated in 2026. The "mini fab" in this context is Tiny Tapeout's
aggregation service — a **social mini fab** rather than a physical one.

## Summary

| Concept | Real? | Accessible? | For What |
|---------|-------|-------------|----------|
| Physical mini fab | Yes (SkyWater, X-Fab) | No (B2B only) | Small production runs |
| MPW shuttle | Yes | Yes | Pooled access to full fabs |
| Desktop fab | No | No | Not viable for CMOS |
| Tiny Tapeout | Yes | Yes (everyone) | Hobby/education first chip |
| ChipFoundry | Yes | Yes (startups) | Real products at $15k |

**For the chip-design-mcp user**: Tiny Tapeout is your path to getting
a real chip. Use this toolset to verify your design before submitting.
