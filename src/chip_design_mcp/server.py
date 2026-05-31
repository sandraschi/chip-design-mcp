"""
FastMCP 3.2 Unified Gateway for open-source RTL-to-GDSII chip design.

Architecture:
  MCP client/tool -> subprocess (yosys, iverilog, magic, netgen, sta)
                   -> Docker OpenLane (ghcr.io/the-openroad-project/openlane:latest)
                   -> JSON response + REST /api/v1/*
"""

from __future__ import annotations

import asyncio
import inspect
import json
import logging
import os
import subprocess
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any
import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastmcp import FastMCP

from chip_design_mcp import __version__
from chip_design_mcp.prompts_resources import register_prompts_and_resources
from chip_design_mcp.tools import (
    register_agentic_chip_tools,
    register_depot_tools,
    register_place_route_tools,
    register_prefab_tools,
    register_simulation_tools,
    register_standard_cells_tools,
    register_synthesis_tools,
    register_verification_tools,
)

logger = logging.getLogger("chip-design-mcp")

_READ_ONLY = {"readOnlyHint": True}
_START_TIME = time.time()
_REPO_ROOT = Path(__file__).resolve().parents[2]

WORK_DIR = os.environ.get(
    "CHIP_DESIGN_MCP_WORK_DIR",
    os.path.join(os.environ.get("TEMP", os.environ.get("TMP", ".")), "chip_design_mcp_work"),
)
UPLOAD_DIR = os.path.join(WORK_DIR, "uploads")
OUTPUT_DIR = os.path.join(WORK_DIR, "output")
DESIGNS_DIR = os.path.join(WORK_DIR, "designs")

_HELP_SLUGS: dict[str, Path] = {
    "fabrication": _REPO_ROOT / "docs" / "tools" / "fabrication.md",
    "mini_fab": _REPO_ROOT / "docs" / "MINI_FAB.md",
    "production": _REPO_ROOT / "docs" / "PRODUCTION_PATHS.md",
    "tools-index": _REPO_ROOT / "docs" / "tools" / "README.md",
    "synthesis": _REPO_ROOT / "docs" / "tools" / "synthesis.md",
    "simulation": _REPO_ROOT / "docs" / "tools" / "simulation.md",
    "place_route": _REPO_ROOT / "docs" / "tools" / "place_route.md",
    "verification": _REPO_ROOT / "docs" / "tools" / "verification.md",
    "standard_cells": _REPO_ROOT / "docs" / "tools" / "standard_cells.md",
    "depot": _REPO_ROOT / "docs" / "tools" / "depot.md",
    "system": _REPO_ROOT / "docs" / "tools" / "system.md",
    "prefab": _REPO_ROOT / "docs" / "tools" / "prefab.md",
    "install": _REPO_ROOT / "INSTALL.md",
    "architecture": _REPO_ROOT / "docs" / "ARCHITECTURE.md",
    "configuration": _REPO_ROOT / "docs" / "CONFIGURATION.md",
    "development": _REPO_ROOT / "docs" / "DEVELOPMENT.md",
    "troubleshooting": _REPO_ROOT / "docs" / "TROUBLESHOOTING.md",
    "pdk": _REPO_ROOT / "docs" / "PDK_GUIDE.md",
}

_DISCOVER_NAMES = {
    "yosys": ["yosys"],
    "iverilog": ["iverilog"],
    "openlane": ["openlane"],
    "docker": ["docker"],
    "magic": ["magic"],
    "netgen": ["netgen"],
    "sta": ["sta", "opensta"],
    "volare": ["volare"],
}

OPENLANE_IMAGE = "ghcr.io/the-openroad-project/openlane:latest"

_state: dict[str, Any] = {}
_all_tools: dict[str, Any] = {}


# ── Subprocess helpers ───────────────────────────────────────────────────────


async def _run_eda(
    cmd: list[str],
    timeout: int = 120,
    cwd: str | None = None,
    env_extra: dict | None = None,
) -> dict:
    """Run an EDA binary and return {success, stdout, stderr, returncode}."""
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd or WORK_DIR,
            env=env,
        )
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        stdout = out.decode("utf-8", errors="replace") if out else ""
        stderr = err.decode("utf-8", errors="replace") if err else ""
        return {
            "success": proc.returncode == 0,
            "stdout": stdout,
            "stderr": stderr,
            "returncode": proc.returncode or 0,
        }
    except FileNotFoundError:
        return {"success": False, "stdout": "", "stderr": f"Command not found: {cmd[0]}", "returncode": -1}
    except TimeoutError:
        return {"success": False, "stdout": "", "stderr": f"Timed out ({timeout}s)", "returncode": -1}
    except Exception as e:
        return {"success": False, "stdout": "", "stderr": str(e), "returncode": -1}


async def _run_openlane(
    design_dir: str,
    designs_root: str,
    extra_args: list[str],
    timeout: int = 3600,
) -> dict:
    """Run OpenLane via Docker (preferred) or native openlane on PATH."""
    tools = _state.get("tools", {})
    design_name = os.path.basename(design_dir.rstrip("\\/"))
    if tools.get("docker"):
        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{designs_root}:/openlane/designs",
        ]
        pdk_root = os.environ.get("PDK_ROOT")
        if pdk_root and os.path.isdir(pdk_root):
            cmd.extend(["-v", f"{pdk_root}:/openlane/pdks"])
        cmd.extend([OPENLANE_IMAGE, "--design", design_name])
        for arg in extra_args:
            if arg.startswith("--design="):
                continue
            key, _, val = arg.partition("=")
            cmd.extend([key, val])
        return await _run_eda(cmd, timeout=timeout, cwd=designs_root)
    if tools.get("openlane"):
        cmd = ["openlane", f"--design={design_name}", *extra_args]
        return await _run_eda(cmd, timeout=timeout, cwd=designs_root)
    return {"success": False, "stdout": "", "stderr": "Neither Docker nor native openlane available", "returncode": -1}


def _probe_sync(name: str) -> bool:
    """Probe PATH for a tool (Windows where / Unix which)."""
    candidates = _DISCOVER_NAMES.get(name, [name])
    for exe in candidates:
        try:
            if os.name == "nt":
                r = subprocess.run(["where", exe], capture_output=True, text=True, timeout=5)
                if r.returncode == 0 and r.stdout.strip():
                    return True
            else:
                r = subprocess.run(["which", exe], capture_output=True, text=True, timeout=5)
                if r.returncode == 0 and r.stdout.strip():
                    return True
        except Exception:
            continue
    return False


async def _discover_tools() -> dict[str, bool]:
    """Probe EDA toolchain binaries on PATH at startup."""
    results: dict[str, bool] = {}
    for name in _DISCOVER_NAMES:
        results[name] = await asyncio.to_thread(_probe_sync, name)
    if results.get("docker"):
        info = await _run_eda(["docker", "info"], timeout=15)
        results["docker"] = info.get("success", False)
    return results


def _pdk_installed() -> bool:
    pdk = os.environ.get("PDK_ROOT", "")
    return bool(pdk and os.path.isdir(pdk))


# ── Lifespan ─────────────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create work dirs, discover EDA tools."""
    logger.info("chip-design-mcp startup")
    for d in (WORK_DIR, UPLOAD_DIR, OUTPUT_DIR, DESIGNS_DIR):
        os.makedirs(d, exist_ok=True)
    _state["tools"] = await _discover_tools()
    _state["pdk_installed"] = _pdk_installed()
    _state["pdk_root"] = os.environ.get("PDK_ROOT")
    _state["work_dir"] = WORK_DIR
    _state["uploads_dir"] = UPLOAD_DIR
    _state["outputs_dir"] = OUTPUT_DIR
    _state["designs_dir"] = DESIGNS_DIR
    _state["synthesis"] = {}
    yield


app = FastAPI(
    title="Chip Design MCP",
    description="Open-source RTL-to-GDSII orchestration - MCP tools + REST API",
    version=__version__,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

mcp = FastMCP.from_fastapi(app, name="Chip Design MCP")

# Skills provider
try:
    from fastmcp.server.providers.skills import SkillsDirectoryProvider

    _skills_dir = Path(__file__).parent / "skills" / "chip-design-expert"
    if _skills_dir.is_dir():
        mcp.add_provider(SkillsDirectoryProvider(roots=[_skills_dir.parent]))
        logger.info("SkillsDirectoryProvider registered: %s", _skills_dir.parent)
except ImportError:
    logger.warning("SkillsDirectoryProvider not available")

register_prompts_and_resources(mcp)

# ── Register domain tools ────────────────────────────────────────────────────

_syn = register_synthesis_tools(
    mcp=mcp,
    state=_state,
    run_eda=_run_eda,
    work_dir=WORK_DIR,
    output_dir=OUTPUT_DIR,
    upload_dir=UPLOAD_DIR,
)
_sim = register_simulation_tools(
    mcp=mcp,
    state=_state,
    run_eda=_run_eda,
    work_dir=WORK_DIR,
    output_dir=OUTPUT_DIR,
    upload_dir=UPLOAD_DIR,
)
_pr = register_place_route_tools(
    mcp=mcp,
    state=_state,
    run_eda=_run_eda,
    run_openlane=_run_openlane,
    work_dir=WORK_DIR,
    output_dir=OUTPUT_DIR,
    designs_dir=DESIGNS_DIR,
    upload_dir=UPLOAD_DIR,
)
_ver = register_verification_tools(
    mcp=mcp,
    state=_state,
    run_eda=_run_eda,
    work_dir=WORK_DIR,
    output_dir=OUTPUT_DIR,
    upload_dir=UPLOAD_DIR,
)
_cells = register_standard_cells_tools(mcp=mcp, state=_state)
_depot = register_depot_tools(
    mcp=mcp,
    state=_state,
    work_dir=WORK_DIR,
    upload_dir=UPLOAD_DIR,
    output_dir=OUTPUT_DIR,
    designs_dir=DESIGNS_DIR,
)

_all_tools.update(_syn)
_all_tools.update(_sim)
_all_tools.update(_pr)
_all_tools.update(_ver)
_all_tools.update(_cells)
_all_tools.update(_depot)


# ── System tools ─────────────────────────────────────────────────────────────


@mcp.tool(annotations=_READ_ONLY, version="0.1.0")
async def chip_status() -> dict:
    """Check server health, EDA tool availability, PDK, and work directories.

    ## Return Format
    {"success": bool, "tools": dict, "pdk_installed": bool, "work_dir": str, "uptime_s": int}

    ## Examples
    await chip_status()
    """
    return {
        "success": True,
        "tools": _state.get("tools", {}),
        "pdk_installed": _pdk_installed(),
        "pdk_root": os.environ.get("PDK_ROOT"),
        "work_dir": WORK_DIR,
        "uploads_dir": UPLOAD_DIR,
        "outputs_dir": OUTPUT_DIR,
        "designs_dir": DESIGNS_DIR,
        "uptime_s": int(time.time() - _START_TIME),
    }


@mcp.tool(annotations=_READ_ONLY, version="0.1.0")
async def chip_pipeline_stages() -> dict:
    """List the 11-stage RTL-to-GDSII ASIC pipeline with tools and I/O.

    ## Return Format
    {"success": bool, "stages": [{"stage": str, "tool": str, "input": str, "output": str}, ...]}

    ## Examples
    await chip_pipeline_stages()
    """
    stages = [
        {"stage": "1 RTL", "tool": "editor/depot_init", "input": "spec", "output": ".v"},
        {"stage": "2 Simulation", "tool": "cocotb+iverilog", "input": "RTL", "output": "pass/fail"},
        {"stage": "3 Synthesis", "tool": "Yosys", "input": "RTL", "output": "gate netlist"},
        {"stage": "4 Floorplan", "tool": "OpenLane", "input": "netlist", "output": "floorplan.def"},
        {"stage": "5 Placement", "tool": "OpenLane", "input": "floorplan", "output": "placement.def"},
        {"stage": "6 CTS", "tool": "OpenLane", "input": "placement", "output": "cts.def"},
        {"stage": "7 Routing", "tool": "OpenLane", "input": "cts", "output": "routed.def"},
        {"stage": "8 STA", "tool": "OpenSTA", "input": "netlist+SDC", "output": "timing.rpt"},
        {"stage": "9 DRC", "tool": "Magic", "input": "GDS", "output": "drc.rpt"},
        {"stage": "10 LVS", "tool": "netgen", "input": "GDS+SPICE", "output": "lvs.rpt"},
        {"stage": "11 GDSII", "tool": "OpenLane", "input": "routed", "output": ".gds"},
    ]
    return {"success": True, "stages": stages, "count": len(stages)}


@mcp.tool(annotations=_READ_ONLY, version="0.1.0")
async def chip_available_pdks() -> dict:
    """List supported open PDKs and whether they are installed under PDK_ROOT.

    ## Return Format
    {"success": bool, "pdks": [{"name": str, "node": str, "vendor": str, "available": bool}], "pdk_root": str | None}

    ## Examples
    await chip_available_pdks()
    """
    pdk_root = os.environ.get("PDK_ROOT", "")
    catalog = [
        {"name": "sky130", "node": "130nm", "vendor": "SkyWater/Google", "subdir": "sky130A"},
        {"name": "gf180mcu", "node": "180nm", "vendor": "GlobalFoundries", "subdir": "gf180mcuA"},
        {"name": "ihp-sg13g2", "node": "130nm BiCMOS", "vendor": "IHP", "subdir": "ihp-sg13g2"},
    ]
    for entry in catalog:
        entry["available"] = bool(pdk_root and os.path.isdir(os.path.join(pdk_root, entry["subdir"])))
    return {"success": True, "pdks": catalog, "pdk_root": pdk_root or None}


_all_tools["chip_status"] = chip_status
_all_tools["chip_pipeline_stages"] = chip_pipeline_stages
_all_tools["chip_available_pdks"] = chip_available_pdks

_agentic = register_agentic_chip_tools(mcp, _all_tools, _state)
_all_tools.update(_agentic)

# Prefab tools are MCP-only (not REST dispatch)
register_prefab_tools(mcp, _all_tools)


# ── REST endpoints ───────────────────────────────────────────────────────────


@app.get("/api/v1/status")
async def api_status():
    tools = _state.get("tools", {})
    return {
        "server": "chip-design-mcp",
        "version": __version__,
        "tools": tools,
        "pdk_installed": _pdk_installed(),
        "pdk_root": os.environ.get("PDK_ROOT"),
        "work_dir": WORK_DIR,
        "uptime_s": int(time.time() - _START_TIME),
    }


@app.get("/api/v1/tools")
async def api_list_tools():
    rest_tools = sorted(_all_tools.keys())
    return {"tools": rest_tools, "count": len(rest_tools)}


@app.post("/api/v1/control/{tool_name}")
async def api_control_tool(tool_name: str, request: Request):
    """Dispatch REST calls to registered MCP tools by name."""
    tool_fn = _all_tools.get(tool_name)
    if tool_fn is None:
        raise HTTPException(status_code=404, detail=f"Tool not found: {tool_name}")
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    result = await tool_fn(**body)
    return result


@app.get("/api/capabilities")
async def api_capabilities():
    prefab_on = os.environ.get("CHIP_DESIGN_MCP_PREFAB_APPS", "1").lower() not in ("0", "false", "no")
    return {
        "status": "ok",
        "server": {"name": "chip-design-mcp", "version": __version__, "fastmcp": "3.2.0"},
        "tools": {"count": len(_all_tools), "names": sorted(_all_tools.keys())},
        "eda": _state.get("tools", {}),
        "pdk_installed": _pdk_installed(),
        "features": {
            "prefab_apps": prefab_on,
            "sampling": True,
            "skills": True,
            "prompts": True,
            "resources": True,
            "help_slugs": sorted(_HELP_SLUGS.keys()),
        },
        "endpoints": {
            "status": "/api/v1/status",
            "tools": "/api/v1/tools",
            "control": "/api/v1/control/{tool_name}",
            "capabilities": "/api/capabilities",
            "help": "/api/v1/help/{slug}",
            "manifest": "/.well-known/mcp/manifest.json",
        },
    }


@app.get("/.well-known/mcp/manifest.json")
async def well_known_manifest():
    manifest_path = _REPO_ROOT / "manifest.json"
    if manifest_path.is_file():
        return JSONResponse(content=json.loads(manifest_path.read_text(encoding="utf-8")))
    return JSONResponse(content={"name": "chip-design-mcp", "version": __version__})


@app.get("/api/v1/help")
async def api_help_index():
    return {"slugs": sorted(_HELP_SLUGS.keys()), "count": len(_HELP_SLUGS)}


@app.get("/api/v1/help/{slug}")
async def api_help_slug(slug: str):
    path = _HELP_SLUGS.get(slug)
    if not path or not path.is_file():
        raise HTTPException(status_code=404, detail=f"Help slug not found: {slug}")
    return {"slug": slug, "title": slug, "content": path.read_text(encoding="utf-8"), "path": str(path)}


@app.get("/api/v1/tools/detail")
async def api_tools_detail():
    """Tool catalog with domain prefix and first docstring line."""
    details = []
    for name, fn in sorted(_all_tools.items()):
        doc = inspect.getdoc(fn) or ""
        first_line = doc.splitlines()[0] if doc else ""
        domain = name.split("_")[0]
        if name.startswith("chip_"):
            domain = "system"
        elif name.startswith("show_"):
            domain = "prefab"
        details.append({"name": name, "domain": domain, "description": first_line})
    return {"tools": details, "count": len(details)}


@app.get("/api/v1/fleet")
async def api_fleet_scan():
    """Bounded port scan for fleet MCP servers (10700-11100)."""
    found = []
    async with httpx.AsyncClient(timeout=0.5) as client:
        for port in range(10700, 11101):
            url = f"http://127.0.0.1:{port}/api/v1/status"
            try:
                resp = await client.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    found.append({"port": port, "server": data.get("server"), "version": data.get("version")})
            except Exception:
                continue
    return {"servers": found, "count": len(found), "scan_range": [10700, 11100]}


@app.get("/api/v1/llm/status")
async def api_llm_status():
    """Detect local LLM (Ollama 11434 / LM Studio 1234)."""
    result: dict[str, Any] = {"ok": False, "provider": None, "model": None, "error": None}

    async def probe_ollama():
        url = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{url}/api/tags")
            resp.raise_for_status()
            models = [m.get("name") for m in resp.json().get("models", [])]
            return {"provider": "ollama", "ok": True, "model": models[0] if models else None, "models": models}

    async def probe_lmstudio():
        url = os.environ.get("LMSTUDIO_URL", "http://127.0.0.1:1234/v1")
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{url}/models")
            resp.raise_for_status()
            models = [m.get("id") for m in resp.json().get("data", [])]
            return {"provider": "lmstudio", "ok": True, "model": models[0] if models else None, "models": models}

    for probe in (probe_ollama, probe_lmstudio):
        try:
            data = await probe()
            result.update(data)
            return result
        except Exception as e:
            result["error"] = str(e)
    return result


@app.post("/api/v1/llm/chat")
async def api_llm_chat(request: Request):
    """Proxy chat to detected local LLM (Ollama or LM Studio)."""
    body = await request.json()
    message = body.get("message") or body.get("prompt") or ""
    if not message:
        raise HTTPException(status_code=400, detail="message required")
    provider = body.get("provider")
    status = await api_llm_status()
    provider = provider or status.get("provider")
    if provider == "ollama":
        url = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
        model = body.get("model") or status.get("model") or "llama3"
        payload = {"model": model, "messages": [{"role": "user", "content": message}], "stream": False}
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{url}/api/chat", json=payload)
            resp.raise_for_status()
            data = resp.json()
        return {"ok": True, "response": data.get("message", {}).get("content", ""), "provider": "ollama"}
    if provider == "lmstudio":
        url = os.environ.get("LMSTUDIO_URL", "http://127.0.0.1:1234/v1")
        model = body.get("model") or status.get("model") or ""
        payload = {"model": model, "messages": [{"role": "user", "content": message}], "max_tokens": 1024}
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{url}/chat/completions", json=payload)
            resp.raise_for_status()
            data = resp.json()
        content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        return {"ok": True, "response": content, "provider": "lmstudio"}
    return {"ok": False, "error": "No local LLM detected. Start Ollama or LM Studio."}


@app.post("/api/v1/upload")
async def api_upload(file: UploadFile):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename")
    safe_name = Path(file.filename).name
    dest = os.path.join(UPLOAD_DIR, safe_name)
    content = await file.read()
    with open(dest, "wb") as f:
        f.write(content)
    return {"success": True, "filename": safe_name, "size_bytes": len(content)}


@app.get("/api/v1/list")
async def api_list_files(dir: str = "uploads"):
    dir_map = {"uploads": UPLOAD_DIR, "outputs": OUTPUT_DIR, "designs": DESIGNS_DIR}
    target = dir_map.get(dir, UPLOAD_DIR)
    files = []
    if os.path.isdir(target):
        for fname in sorted(os.listdir(target)):
            fp = os.path.join(target, fname)
            if os.path.isfile(fp):
                files.append({"name": fname, "size_bytes": os.path.getsize(fp)})
    return {"directory": dir, "files": files, "count": len(files)}


@app.get("/api/v1/download/{file_name}")
async def api_download(file_name: str, dir: str = "outputs"):
    dir_map = {"uploads": UPLOAD_DIR, "outputs": OUTPUT_DIR, "designs": DESIGNS_DIR}
    target = dir_map.get(dir, OUTPUT_DIR)
    path = os.path.join(target, file_name)
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail=f"File not found: {file_name}")
    return FileResponse(path, filename=file_name)


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Chip Design MCP Server")
    parser.add_argument("--mode", default="dual", choices=["dual", "sse", "stdio", "http"])
    parser.add_argument("--port", type=int, default=11022)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--agentic", action="store_true", help="Enable CodeMode BM25 discovery")
    args = parser.parse_args()

    agentic = args.agentic or os.getenv("MCP_AGENTIC", "").lower() in ("true", "1", "yes")
    if agentic:
        try:
            from fastmcp.experimental.transforms.code_mode import CodeMode

            CodeMode().attach(mcp)
            logger.info("CodeMode agentic discovery enabled")
        except ImportError as e:
            logger.warning("CodeMode not available: %s", e)

    if args.mode == "stdio":
        mcp.run(transport="stdio")
    else:
        uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
