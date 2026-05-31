# Fabrication guide — chips, tiles, fabs, and who to use

How to go from **GDSII** (layout) to **silicon**, and which **provider** fits your **complexity**, **density**, and **budget**. This doc is the fleet reference for chip-design-mcp users; the webapp **Help → Fabrication** tab shows the same content.

---

## 1. Words you need (chip vs slice vs shuttle)

| Term | Meaning |
|------|---------|
| **RTL** | Verilog/SystemVerilog source (behavior) |
| **Netlist** | Gate-level connectivity after synthesis |
| **Layout / GDSII** | Geometry the fab prints — what you **tape out** |
| **Die** | One rectangular piece of silicon cut from a wafer |
| **Chip / packaged part** | Die in a package (QFN, BGA, …) you can solder |
| **Tile / slot** | Tiny Tapeout unit (~160×100 µm on a **carrier** die shared with hundreds of designs) |
| **User area / macro** | Your block inside a larger SoC template (e.g. ChipFoundry ~15 mm²) |
| **Shuttle / MPW run** | One mask set, many designs on the same wafer — cost sharing |
| **Tapeout** | Handing GDSII + rules checks to the fab on a fixed deadline |
| **NRE** | Non-recurring engineering (masks, setup, package NRE) |
| **PDK** | Process Design Kit — cells, rules, tech files for one **node** |

**“Slice”** in hobby contexts usually means a **tile** on a shared shuttle chip, not a separate wafer.

---

## 2. Pick your path by complexity (logic + area)

Use this matrix before choosing a fab broker. Numbers are **order-of-magnitude** for open PDK flows (sky130, gf180).

| Tier | Approx. digital scale | Typical area | Analog / RF | Realistic path | Indicative cost (2026) |
|------|----------------------|--------------|-------------|----------------|-------------------------|
| **T0 — Learn only** | &lt;500 gates, sim OK | N/A (no silicon) | No | Local Yosys + cocotb + chip-design-mcp | **$0** (your PC) |
| **T1 — Tiny digital** | 500–10k gates | 0.016–0.064 mm² (1–4 tiles) | No | **Tiny Tapeout** (Sky130 / GF180 / IHP shuttle) | **~$100–500** + 6–12 mo wait |
| **T2 — Small digital / controller** | 10k–100k gates | 0.1–1 mm² | Mixed low | Tiny Tapeout (many tiles) or **academic MPW** | **$100–3k** (TT) / **€8k–15k** (EU academic) |
| **T3 — SoC / startup block** | 100k–5M gates | 1–15 mm² | Yes (limited) | **ChipFoundry chipIgnite** (Sky130 + RISC-V shell) | **~$15k**, ~100 packaged parts |
| **T4 — Custom ASIC prototype** | Any | 1–10+ mm² | Full mixed-signal | **MPW broker** (Muse, CMP, Europractice, direct SkyWater/X-Fab) | **~$50k–150k per mm²** NRE share |
| **T5 — Production** | High volume | Reticle/full | Production QA | Foundry direct, full mask set, OSAT package/test | **$500k–2M+** masks + wafers |

**Complexity** = logic depth + clocks + memories + analog. **Density** = which **node** and **cell library** (see §3).

---

## 3. Density = process node + standard-cell library

“Density” is not one number — it is **feature size (nm)** plus **library variant**.

| Open PDK | Node | Library (digital) | Rough gate density | Best for |
|----------|------|-------------------|--------------------|----------|
| **sky130** (SkyWater) | 130 nm | `sky130_fd_sc_hd` (high density) | ~1–2 M gates/mm² (placed+routed, varies) | General digital, Tiny Tapeout, ChipFoundry |
| **sky130** | 130 nm | `sky130_fd_sc_hs` (high speed) | Lower area, higher power | Faster paths, fewer gates/mm² |
| **gf180mcu** (GlobalFoundries) | 180 nm | MCU-oriented libs | Lower than sky130 HD | IO-rich, MCU, TT shuttles on GF180 |
| **ihp-sg13g2** (IHP) | 130 nm BiCMOS | Digital + **BJT/HBT** devices | Digital similar; analog stronger | RF, BiCMOS, lab chips |

Install with **volare** (never hand-copy PDK trees):

```powershell
pip install volare
volare enable --pdk sky130 0bbdd5
volare enable --pdk gf180mcu
volare enable --pdk ihp-sg13g2
```

`chip_available_pdks` and `PDK_ROOT` must agree before OpenLane or liberty-based STA.

**Rule of thumb:** If you only need “a lot of gates cheap,” use **sky130 HD**. If you need **analog/RF**, plan **IHP** or commercial mixed-signal MPW, not a single digital tile.

---

## 4. Where silicon is actually made (fabs vs brokers)

You rarely talk to TSMC/Samsung as an individual. You use a **broker** or **aggregator** that buys shuttle space.

### 4.1 Open-access / hobby-friendly (individuals)

| Provider | Type | PDK / node | What you submit | Cost | Chips you get | Lead time |
|----------|------|------------|-----------------|------|---------------|-----------|
| **[Tiny Tapeout](https://tinytapeout.com)** | Tile aggregator | sky130, gf180, ihp | GDS tile via GitHub Actions + web app | **~$100–500** (early bird varies) | **1** die on carrier + dev kit | **6–12 months** |
| **Wokwi → TT** | Same | sky130 | Browser schematic (beginners) | Same | Same | Same |

**How tiles work:** Your design is placed in a fixed **160 µm × 100 µm** (order-of-magnitude) slot. ~**1000 gates** per tile is a common planning figure — not a hard guarantee after routing. More area = buy more tiles.

**How to submit (Tiny Tapeout):**

1. Design RTL; verify with `depot_init` + `sim_run_testbench` (chip-design-mcp).
2. Run OpenLane to GDS (or use TT’s template CI).
3. Fork [TinyTapeout](https://github.com/TinyTapeout) submission template.
4. Pass CI → submit at [app.tinytapeout.com](https://app.tinytapeout.com) before shuttle **closing date**.
5. Pay → wait for fab + PCB assembly.

Check active shuttles on their site (e.g. SKY26*, GF26*, IHP26*).

### 4.2 Commercial open-PDK startup path

| Provider | Type | PDK | Area | Cost | Quantity | Notes |
|----------|------|-----|------|------|----------|-------|
| **[ChipFoundry chipIgnite](https://chipfoundry.io/chipignite)** (ex-Efabless) | SoC template + user macro | sky130 | **~15 mm²** user logic | **~$14,950** | **~100** QFN or bare die | RISC-V + peripherals included; not a free MPW anymore |

**How to submit:** Engage ChipFoundry platform; integrate your RTL/GDS into their chipIgnite flow; commercial contract and schedule — not the same as dropping a TT tile.

**When to use:** Product MVP, need **package**, **many dies**, **>1 mm²**, software on bundled RISC-V.

### 4.3 Academic / research (often subsidized, not “free” for everyone)

| Provider | Region | Typical nodes | Eligibility | Indicative cost |
|----------|--------|---------------|-------------|-----------------|
| **[Europractice](https://europractice-ic.com)** | EU | sky130, various | Universities / EU research | **€8k–20k+** per MPW slot |
| **[CMP](https://cmp.imag.fr)** | EU (France) | sky130, CMOS, SOI | Academic partners | **€10k+** range |
| **Mosis** (US heritage) | US academic | Various | US university flows | Program-dependent |
| **Google SKY130 free MPW** (historical) | — | sky130 | **Closed** — replaced by commercial/ecosystem paths | Was $0; **do not plan on it** |

Students: ask your institution’s **Europractice/CMP liaison** first — pricing and nodes are program-specific.

### 4.4 Commercial MPW / small volume (companies)

| Provider | Role | Nodes often quoted | Typical use |
|----------|------|-------------------|-------------|
| **[Muse Semiconductor](https://musesemi.com)** | MPW broker | sky130, others | Startup prototypes |
| **SkyWater** (direct) | Foundry (US) | 130 nm | Larger MPW, production |
| **X-Fab** | Foundry (EU) | 180 nm–1 µm | Automotive, industrial, MPW |
| **Tower/Jazz** | Foundry | 180 nm etc. | Mixed-signal MPW |
| **TSMC / GlobalFoundries** (commercial PDK) | Foundry | Many | **NDA PDK** — not open PDK; $$$$

Expect **NDA**, **closed PDK**, **memory compilers**, **package NRE**, **probe/test** costs on top of shuttle share.

### 4.5 What is NOT available to individuals

| Idea | Reality |
|------|---------|
| **“Free fab” for any design** | Open PDK ≠ free silicon; only specific programs (past Google MPW, academic subsidies) |
| **Desktop CMOS fab** | Not viable at 130 nm (see [MINI_FAB.md](MINI_FAB.md)) |
| **Walk into SkyWater with a USB** | B2B / broker / shuttle only |
| **Unlimited tiles** | Each tile is paid; carrier has finite slots |

---

## 5. Free vs paid — honest breakdown

| Activity | Free? | Tool / provider |
|----------|-------|-----------------|
| Learn RTL, simulate, synthesize | **Yes** | chip-design-mcp, Yosys, iverilog, cocotb |
| PDK install | **Yes** | volare + open PDKs |
| DRC/LVS locally (with tools installed) | **Yes** | Magic, netgen, OpenLane |
| **First physical chip (hobby)** | **Low cost, not free** | Tiny Tapeout **~$100+** |
| **First physical chip (startup)** | **No** | ChipFoundry **~$15k** |
| **MPW academic** | **Subsidized** | Europractice/CMP via university |
| **Production** | **No** | Foundry commercial |

---

## 6. Step-by-step: from chip-design-mcp to silicon

### Path A — Tiny Tapeout tile (T1)

```
chip_status → depot_init → sim_run_testbench → syn_* → pr_* (OpenLane)
→ verify_drc / verify_lvs → pr_export_gds
→ Tiny Tapeout template CI → app.tinytapeout.com → pay → wait
```

**PDK:** sky130 or gf180 per shuttle announcement.  
**Density limit:** tile count, not mm² freedom.

### Path B — ChipFoundry (T3)

```
Full OpenLane SoC-style flow in sky130 → ChipFoundry integration
→ commercial tapeout schedule → packaged QFN shipment
```

Use when tile area is insufficient or you need CPU + peripherals.

### Path C — Academic MPW (T2–T4)

```
University approval → Europractice/CMP reservation → GDS + documentation
→ shared wafer → diced dies → often bare die only
```

Align PDK with broker’s advertised shuttle (often sky130).

### Path D — Commercial MPW (T4+)

```
NDA PDK → design with commercial EDA optional → DRC/LVS signoff
→ broker/foundry tapeout → wafers → package/test at OSAT
```

chip-design-mcp still helps for **open PDK prototyping** before you commit NRE.

---

## 7. Choosing by design type

| You are building | Node hint | Provider |
|------------------|-----------|----------|
| Blinking LED / counter / UART toy | sky130 | Tiny Tapeout |
| PicoRV32-class tiny CPU | sky130 | Tiny Tapeout (many tiles) or ChipFoundry |
| Sensor + SPI + control | sky130 / gf180 | TT or ChipFoundry |
| RF / precise analog | ihp-sg13g2 or commercial | IHP shuttle or MPW |
| Motor driver / high voltage | gf180mcu | TT (GF shuttle) or industrial fab |
| Secure element / big SoC | sky130 commercial | ChipFoundry or MPW |
| **>10k units** | negotiated | Full masks + foundry |

---

## 8. Physical “mini fab” vs shuttle (clarification)

| Concept | Accessible to you? | See also |
|---------|-------------------|----------|
| SkyWater Minnesota fab building | No (B2B) | [MINI_FAB.md](MINI_FAB.md) |
| **MPW shuttle** | Yes, via brokers | This doc §4 |
| **Tiny Tapeout** | Yes | §4.1 |
| Desktop printer fab | No | [MINI_FAB.md](MINI_FAB.md) §3 |

---

## 9. Risks and expectations

- **Shuttle closing dates** are real — missing one means **+6–12 months**.
- **DRC/LVS clean** is required; heuristic checks in chip-design-mcp are **not** signoff.
- **Yield**: MPW may return few working dies; plan **100 units** only on programs that guarantee it (e.g. ChipFoundry batch).
- **RoHS/commercial certification** is separate from “GDS accepted.”
- **Analog on TT** needs analog tile rules — read Tiny Tapeout docs for slot types.

---

## 10. Links (verify before tapeout)

| Resource | URL |
|----------|-----|
| Tiny Tapeout | https://tinytapeout.com |
| TT calculator | https://app.tinytapeout.com/calculator |
| ChipFoundry chipIgnite | https://chipfoundry.io/chipignite |
| Europractice | https://europractice-ic.com |
| CMP | https://cmp.imag.fr |
| Muse Semiconductor | https://musesemi.com |
| Open PDKs (volare) | https://github.com/efabless/volare |
| Production comparison (short) | [PRODUCTION_PATHS.md](PRODUCTION_PATHS.md) |
| PDK install | [PDK_GUIDE.md](PDK_GUIDE.md) |

---

## 11. Using chip-design-mcp in this journey

| Stage | MCP tools |
|-------|-----------|
| Feasibility | `chip_status`, `chip_pipeline_stages`, `chip_available_pdks` |
| Project | `depot_init`, `depot_list` |
| Verify RTL | `sim_*` |
| Synthesize | `syn_*` |
| Physical | `pr_*`, `verify_*`, `pr_export_gds` |
| Library browse | `cells_*` |
| Plan flow | `chip_agentic` (if host supports sampling) |

**Help tabs:** Fabrication (this doc), PDK, Production paths, per-domain tool guides.
