# Fabrication & fabs (quick index)

Full guide: **[FABRICATION_AND_FABS.md](../FABRICATION_AND_FABS.md)** — tiles, shuttles, complexity tiers, free vs commercial providers.

## By budget

| Budget | Path |
|--------|------|
| $0 | Simulate + synthesize locally (no silicon) |
| ~$100–500 | [Tiny Tapeout](https://tinytapeout.com) tile on sky130/GF180/IHP |
| ~$15k | [ChipFoundry chipIgnite](https://chipfoundry.io/chipignite) (~15 mm², ~100 chips) |
| €8k–20k+ | Europractice / CMP (academic) |
| $50k+/mm² | Commercial MPW brokers (Muse, foundry programs) |

## By complexity

| Gates / area | Provider |
|--------------|----------|
| &lt;10k gates, 1–4 tiles | Tiny Tapeout |
| SoC + software | ChipFoundry |
| Custom mm², mixed-signal | MPW broker + NDA PDK |

## MCP tools before tapeout

`chip_status` → `depot_init` → `sim_*` → `syn_*` → `pr_run_flow` → `verify_*` → `pr_export_gds`

See Help → **Fabrication** for the complete provider tables and submission steps.
