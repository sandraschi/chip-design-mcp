# Chip Design MCP — Setup Guide

**Supplement to [INSTALL.md](../INSTALL.md).** Product scope: [PRD.md](PRD.md).

## Automated install (Windows)

**Default:** run `.\start.bat` from the repo root. See [INSTALL.md](../INSTALL.md) — step 3 runs `scripts/install-eda.ps1` (Docker OpenLane, WSL apt packages, volare sky130). No manual steps for naked-PC users.

## Manual / Linux / macOS (optional)

Use this section only when not using the Windows launcher, or to install extra tools (e.g. gtkwave).

### EDA Tools

```bash
# Ubuntu / Debian / WSL
sudo apt update
sudo apt install -y yosys iverilog gtkwave magic netgen

# macOS
brew install yosys icarus-verilog gtkwave magic netgen

yosys -V
iverilog -V
```

### cocotb (Python Verification Framework, Required)

```bash
pip install cocotb
cocotb-config --version
```

### OpenLane (Automated RTL-to-GDSII, Optional but Recommended)

OpenLane runs Yosys + OpenROAD + Magic + netgen together for the full
digital flow. Two install options:

**Option A: Docker (Recommended — Most Portable)**
```bash
# Install Docker Desktop for Windows/Mac, or:
sudo apt install docker.io  # Linux

# Pull OpenLane image (~3 GB)
docker pull ghcr.io/the-openroad-project/openlane:latest

# Test
docker run --rm ghcr.io/the-openroad-project/openlane:latest --version
```

**Option B: Native Install (Linux only)**
```bash
# Requires Python 3.10+, pip
pip install openlane

# Test
openlane --version
```

### PDK (Process Design Kit) Installation

Every chip design needs a PDK — the "driver" that tells EDA tools how to
target the specific manufacturing process.

#### What is a PDK?

A Process Design Kit (PDK) is a collection of files provided by the foundry:

- **Standard cell libraries** — Pre-characterized logic gates (AND, OR, DFF, etc.)
  with timing models (.lib), layout (GDS/LEF), and Verilog models
- **Technology files** — Layer definitions, design rules (DRC), extraction rules
- **Device models** — SPICE models for transistors, resistors, capacitors
- **Verification decks** — DRC, LVS, antenna, and electrical rule checks

Think of it as the "driver" for your chip design — without a PDK, EDA tools
can't produce manufacturable layouts.

#### Install SkyWater 130nm PDK (Primary Target)

```bash
# Volare handles PDK installation and PDK_ROOT conventions
pip install volare

# Enable SkyWater 130nm (downloads ~500 MB)
volare enable --pdk sky130 7519dfb04400f224f140749cda44ee7de6f5e095

# Verify
echo $PDK_ROOT     # Should show e.g. /home/user/.volare
ls $PDK_ROOT/sky130A/  # Should show libs.ref/, libs.tech/, soic/

# Check standard cell library
ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog/
```
> **Note**: `PDK_ROOT` is set automatically by volare. If not set, add
> `export PDK_ROOT=$(volare path)` to your `~/.bashrc` or `~/.zshrc`.

#### Install GF180MCU PDK (Alternative - GlobalFoundries 180nm)

```bash
volare enable --pdk gf180mcu

# Verify
ls $PDK_ROOT/gf180mcuA/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/
```

#### Install IHP SG13G2 PDK (130nm BiCMOS - RF/Analog)

```bash
volare enable --pdk ihp-sg13g2

# Verify
ls $PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/
```

---

## Chip Design MCP Server Setup

```powershell
# 1. Clone the repo (if not already)
git clone https://github.com/sandraschi/chip-design-mcp.git
cd chip-design-mcp

# 2. Bootstrap (Python deps + webapp deps)
just bootstrap

# 3. Start backend
just serve

# 4. (Separate terminal) Start webapp
just web
```

---

## Verify Everything Works

```powershell
# 1. Check EDA tool discovery
just yosys-check       # Should show path or "NOT FOUND"
just openlane-check    # Should show path or "NOT FOUND"
just cocotb-check      # Should show path or "NOT FOUND"

# 2. Start server and test
just serve             # Starts on port 11022

# In another terminal:
curl http://localhost:11022/api/v1/status
# Should return JSON with tool availability and PDK status

# 3. List available tools
curl http://localhost:11022/api/v1/tools
# Should show all 31 registered tools

# 4. Run the test suite
just test
```

---

## First Design Walkthrough

### 1. Create a Counter Project

```python
# Via MCP tool (preferred):
depot_init(project_name="my_counter", template="counter")
```

This creates:
```
designs/my_counter/
├── src/my_counter.v          # Verilog RTL
├── tests/test_my_counter.py  # cocotb testbench
├── Makefile                  # cocotb Makefile
├── config.json               # OpenLane configuration
└── README.md                 # Project README
```

### 2. Synthesize with Yosys

```python
syn_read_verilog(
    file_name="my_counter.v",
    top_module="my_counter"
)
syn_run(top_module="my_counter")
```

### 3. Run Simulation

```bash
# Via local Makefile:
cd designs/my_counter
make -C designs/my_counter sim
```

### 4. Generate GDSII

```python
pr_create_design(
    design_name="my_counter",
    verilog_file="my_counter.v"
)
pr_run_flow(design_name="my_counter")
pr_export_gds(design_name="my_counter")
```

---

## Troubleshooting

| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| **Yosys not found** | Not installed or not on PATH | `sudo apt install yosys` or add to PATH |
| **$PDK_ROOT not set** | PDK not installed or shell not sourced | Run `volare enable --pdk sky130` |
| **OpenLane Docker fails** | Docker daemon not running | Start Docker Desktop / `sudo systemctl start docker` |
| **OpenLane image not pulled** | First-time setup | `docker pull ghcr.io/the-openroad-project/openlane:latest` |
| **Magic DRC fails** | Tech file path not resolved | Provide explicit `tech_file` path, or check PDK_ROOT |
| **Port 11022 in use** | Zombie process | `just clean` or kill zombie: `Stop-Process -Id (Get-NetTCPConnection -LocalPort 11022).OwningProcess` |
| **LVS doesn't match** | PDK CDL path wrong | Check PDK install: `ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/cdl/` |
| **iverilog compile fails** | Verilog syntax issue | Check for SystemVerilog-isms, use `-g2012` flag for newer Verilog |
| **No EDA tools, want to test** | No problem | Server starts without them: chip_status will show which are missing |

---

## Production Deployment

See [PRODUCTION_PATHS.md](PRODUCTION_PATHS.md) for detailed options.

Quick decision guide:

| Your Need | Go With | Cost |
|-----------|---------|------|
| First chip, education, hobby | **Tiny Tapeout** | ~$100 |
| Small startup MVP | **ChipFoundry** | ~$15k |
| Volume production | **Custom MPW** | $50k+ |
| High volume (10k+ units) | **Full mask set** | $500k+ |
