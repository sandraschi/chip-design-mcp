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
    uv run ruff check src/
    Set-Location '{{justfile_directory()}}\webapp'
    if (Get-Command bun -ErrorAction SilentlyContinue) { bunx tsc --noEmit } else { npx tsc --noEmit }

fix:
    uv run ruff check src/ --fix
    uv run ruff format src/

check: lint test

ty:
    uv run ty check src

precommit:
    uv run pre-commit run --all-files

install-mcp client="print":
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{justfile_directory()}}\install-mcp.ps1" {{client}}

mcpb-pack:
    $ver = (Get-Content pyproject.toml | Select-String '^version = "(.*)"' | ForEach-Object { $_.Matches.Groups[1].Value })
    $null = New-Item -ItemType Directory -Path dist -Force
    Compress-Archive -Path manifest.json, assets, src, pyproject.toml -DestinationPath "dist/chip-design-mcp-v$ver.mcpb" -CompressionLevel Optimal -Force
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

yosys-check:
    uv run python -c "from chip_design_mcp.server import _find_executable; print(_find_executable('yosys') or 'NOT FOUND')"

openlane-check:
    uv run python -c "from chip_design_mcp.server import _find_executable; print(_find_executable('openlane') or 'NOT FOUND')"

cocotb-check:
    uv run python -c "from chip_design_mcp.server import _find_executable; print(_find_executable('cocotb-config') or 'NOT FOUND')"
