set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]

export NAME := "Chip Design MCP"
export DESC := "Open-source ASIC/VLSI design automation via MCP tools and REST API"
export VER  := "0.1.0"
export PORT := "11022"
export HOST := "0.0.0.0"

# -- Project Configuration -----------------------------------------------------

default:
    @powershell.exe -NoProfile -ExecutionPolicy Bypass -File ../mcp-central-docs/scripts/just-dashboard.ps1 -Path .

# -- Lifecycle ----------------------------------------------------------------

bootstrap:
    uv sync --all-extras
    Set-Location '{{justfile_directory()}}\webapp'
    if (Get-Command bun -ErrorAction SilentlyContinue) { bun install } else { cmd /c npm install }

clean:
    if (Test-Path -Path "__pycache__") { Remove-Item -Recurse -Force "__pycache__" }; \
    if (Test-Path -Path "**/__pycache__") { Get-ChildItem -Path "." -Recurse -Filter "__pycache__" | Remove-Item -Recurse -Force }; \
    if (Test-Path -Path ".pytest_cache") { Remove-Item -Recurse -Force ".pytest_cache" }; \
    if (Test-Path -Path "htmlcov") { Remove-Item -Recurse -Force "htmlcov" }

setup: clean bootstrap
    Write-Host "Chip Design MCP ready." -ForegroundColor Green

# -- Operation ----------------------------------------------------------------

serve mode="dual" port=PORT:
    uv run python -m chip_design_mcp.server --mode {{mode}} --port {{port}}

stdio:
    uv run python -m chip_design_mcp.server --mode stdio

web:
    Set-Location '{{justfile_directory()}}\webapp'
    if (Get-Command bun -ErrorAction SilentlyContinue) { bun run dev } else { npm run dev }

# -- Development --------------------------------------------------------------

dev port=PORT:
    uv run uvicorn chip_design_mcp.server:app --reload --port {{port}} --host {{HOST}}

# -- Quality ------------------------------------------------------------------

lint:
    uv run ruff check src tests
    uv run ruff format --check src tests
    Set-Location '{{justfile_directory()}}\webapp'
    if (Get-Command bun -ErrorAction SilentlyContinue) { bun run lint } else { npx @biomejs/biome check src/ }
    if (Get-Command bun -ErrorAction SilentlyContinue) { bunx tsc --noEmit } else { npx tsc --noEmit }

fix:
    uv run ruff check src tests --fix
    uv run ruff format src tests
    Set-Location '{{justfile_directory()}}\webapp'
    if (Get-Command bun -ErrorAction SilentlyContinue) { bun run format } else { npx @biomejs/biome check --write src/ }

check: lint test ty

ty:
    uv run ty check src

precommit:
    uv run pre-commit run --all-files

install-mcp client="print":
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{justfile_directory()}}\install-mcp.ps1" {{client}}

mcpb-pack:
    $ver = (Get-Content pyproject.toml | Select-String '^version = "(.*)"' | ForEach-Object { $_.Matches.Groups[1].Value })
    $null = New-Item -ItemType Directory -Path dist -Force
    npx --yes @anthropic-ai/mcpb@latest validate .
    npx --yes @anthropic-ai/mcpb@latest pack . "dist/chip-design-mcp-v$ver.mcpb"
    Write-Host "Created dist/chip-design-mcp-v$ver.mcpb" -ForegroundColor Green

# -- Testing ------------------------------------------------------------------

test:
    uv run pytest

e2e:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Dev\repos\mcp-central-docs\scripts\playwright-audit.ps1" -RepoPath "{{justfile_directory()}}"

# -- Diagnostics --------------------------------------------------------------

health:
    curl http://localhost:11022/api/v1/status

# -- Chip Design Flow ---------------------------------------------------------

install-eda:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{justfile_directory()}}\scripts\install-eda.ps1" -RepoRoot "{{justfile_directory()}}" -UvExe (Get-Command uv).Source

yosys-check:
    uv run python -c "from chip_design_mcp.server import _probe_sync; print('yosys:', _probe_sync('yosys'))"

openlane-check:
    uv run python -c "from chip_design_mcp.server import _probe_sync; print('docker:', _probe_sync('docker'))"

docker-check:
    uv run python -c "from chip_design_mcp.server import _probe_sync; print('docker:', _probe_sync('docker'))"

pdk-check:
    uv run python -c "import os; print('PDK_ROOT=', os.environ.get('PDK_ROOT','(unset)'))"
