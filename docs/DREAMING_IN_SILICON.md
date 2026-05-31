# Dreaming in silicon — what this project really is

**Read this before you `start.bat` yourself into a week of Docker.**  
The [README](../README.md) is the brochure; this is the editorial.

---

## 1. Superyacht magazine rules

Chip Design MCP is a **superyacht magazine** for custom silicon.

You flip through glossy pages about:

- RTL that **could** become gates on **sky130**
- OpenLane flows that **could** produce GDSII
- Tiny Tapeout shuttles that **could** put your tile on a wafer for **hundreds of dollars**, not millions
- A KiCad board that **could** someday hold a QFP package with **your** die inside (or, more realistically, an FPGA you programmed while the wafer is still a dream)

Nobody hands you the keys to a 90-metre Feadship. Nobody hands you a commercial foundry account. You get **photography, specifications, and a contact number for a broker** — except here the broker is `volare`, the photography is `syn_show`, and the helipad is port **11023**.

**That is intentional.** The point is to show that the journey is **thinkable** with FOSS tools in 2026, not to pretend you already own the fab.

---

## 2. What we are (and are not)

| We are | We are not |
|--------|------------|
| A **real** FastMCP server calling **real** binaries (Yosys, iverilog, Docker OpenLane, …) | A foundry, shuttle broker, or mask shop |
| An **honest** orchestration layer (`success: false` when tools are missing) | A guarantee of DRC-clean or tapeout-ready silicon |
| A **documentation stack** for the open RTL→GDSII adventure | A replacement for experienced PD engineers on production chips |
| A **fleet demo** aligned with [mcp-central-docs](https://github.com/sandraschi/mcp-central-docs) | Legal advice on export control, ITAR, or foundry contracts |

The Python code does not implement neuromorphic neurons or place cells. It **runs programs that do**, and tells you when those programs are not installed.

---

## 3. The fantasy arc (the article you came for)

```text
  You, at 2 a.m.
       |
       v
  Read about OpenSpike / neuraedge / Tiny Tapeout spiking tiles
       |     [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md)
       v
  Discover you can *generate* RTL with LiteX or Chisel, not only type Verilog
       |     [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md)
       v
  `depot_init` → cocotb passes → Yosys maps to sky130 cells
       |     chip-design-mcp tools
       v
  OpenLane runs for hours; Docker fan sounds like a small aircraft
       |
       v
  You have a GDSII file and a new respect for physical design
       |
       v
  Optional: Tiny Tapeout ~$100–500 tile, 6–12 month wait
       |     [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md)
       v
  Optional: KiCad board with socket, regulators, and dreams
       |     fleet **kicad-mcp** — PCB, not wafer
       v
  You tell friends you "do chip design." You mean it. You also mean sim.
```

**The fascinating part:** Ten years ago this pipeline was mostly PowerPoints and NDA PDFs. Today: open PDKs, OpenROAD, LibreLane lineage, shuttle aggregators, and repos that already taped out spiking accelerators on sky130. Still hard. No longer **unimaginable**.

---

## 4. KiCad is the epilogue, not chapter one

Silicon and PCB are different sports:

| Layer | Tool | Delivers |
|-------|------|----------|
| **Wafer** | Verilog + PDK + OpenLane | GDSII |
| **Board** | KiCad | Gerbers |

You do **not** draw your CPU in KiCad Eeschema and send Gerbers to TSMC. You **do** design a board that holds:

- The packaged part from shuttle / dev kit (when it arrives)
- Or an FPGA dev kit while the shuttle is still baking
- Power, clocks, connectors, and the ritual decoupling capacitor farm

Fleet **kicad-mcp** automates the board story. **chip-design-mcp** automates the wafer story. A complete fantasy ends with **both** repos open in the IDE and a coffee that has gone cold twice.

---

## 5. Do not do this at home (ok, you have been warned)

Serious operators only — or enthusiastic fools with backups:

1. **Time** — OpenLane on a laptop is measured in **hours**, not TikTok lengths.
2. **Disk** — Docker images + PDKs are **gigabytes**.
3. **Thermals** — Your machine will sound like it is clearing for takeoff.
4. **Git** — Checkpoint before any agent batch-edits `src/`. Learned the hard way.
5. **Signoff** — MCP `verify_drc` / `verify_lvs` use **heuristics**, not foundry signoff decks. Read real reports.
6. **Law & export** — PDKs and shuttles have terms. Read them. We do not.
7. **Money** — Shuttle tiles can be **affordable** compared to historical NRE; they are not **free**, and failed runs still cost patience.
8. **Ego** — `chip_status` saying `yosys: true` does not mean you are a principal engineer at Intel.

If you only want to **read and dream**, that is a valid mode. Use Help tabs, skim [ARCHITECTURE.md](ARCHITECTURE.md), admire [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md), close the laptop, go for a walk. The magazine does not require a subscription to Docker.

If you **run** the flow anyway: welcome to the club. Bring logs.

---

## 6. What “document it all” means in this repo

Everything below is part of the same issue — **issue 0: democratized curiosity**.

| Doc | Role in the magazine |
|-----|----------------------|
| [README.md](../README.md) | Cover story + warnings + quick start |
| **This file** | Editorial / philosophy |
| [INSTALL.md](../INSTALL.md) | How to actually start the presses (Windows) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full RTL→GDSII pipeline diagram |
| [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md) | FOSS CAD to **create** RTL (Chisel, LiteX, KiCad boundary, FPGA, macros) |
| [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md) | **Catalog** of interesting open RTL (SNN, CPUs, tapeouts) |
| [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md) | How GDSII becomes silicon (tiles, shuttles, money) |
| [PDK_GUIDE.md](PDK_GUIDE.md) | sky130 / gf180 / IHP — the “paint set” |
| [PRD.md](PRD.md) | Product requirements (for builders, less poetry) |
| [docs/tools/](tools/README.md) | Per-tool Help for agents |
| [MINI_FAB.md](MINI_FAB.md) | Backyard fab (even more fantasy — read for laughs and science) |
| [PRODUCTION_PATHS.md](PRODUCTION_PATHS.md) | Production-oriented notes |

Webapp **Help** exposes the same markdown at `GET /api/v1/help/{slug}`.

---

## 7. Suggested reading order

**Dreamers (no install):**

1. This file  
2. [FOSS_RTL_SOURCES.md](FOSS_RTL_SOURCES.md) — spiking nets and tiny CPUs  
3. [FABRICATION_AND_FABS.md](FABRICATION_AND_FABS.md) — what a shuttle costs emotionally and financially  
4. [FOSS_EDA_ECOSYSTEM.md](FOSS_EDA_ECOSYSTEM.md) — skim tool names once  

**Operators (install anyway):**

1. [INSTALL.md](../INSTALL.md)  
2. [ARCHITECTURE.md](ARCHITECTURE.md)  
3. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when Docker lies  

**Agents:**

1. `chip_status`  
2. `chip_pipeline_stages`  
3. Help slug `foss-rtl-sources` before promising OpenLane on a full OpenSpike clone  

---

## 8. One paragraph for the curious non-engineer

People used to assume custom chips required a building, a lawyer, and a nine-figure line item. Open toolchains and shared wafer shuttles changed the **floor** of the story: students and hobbyists can **touch** real PDKs, run **real** place-and-route, and **maybe** share a wafer with hundreds of strangers for the price of a nice dinner (times vary, read the fab doc). This repository is a **guided fantasy** that still runs real commands — a superyacht magazine where, if you squint, the last page includes a parts list and a warning label.

**Ok, you have been warned. Dream responsibly.**

---

*Fleet humor disclaimer: No superyachts were synthesized in the making of this MCP server. Any resemblance to a working 3 nm phone SoC is coincidental.*
