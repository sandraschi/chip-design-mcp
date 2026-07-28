# -*- mode: python ; coding: utf-8 -*-
# Tauri sidecar — single-file backend (FastMCP + FastAPI on :11022)
from PyInstaller.building.build_main import Analysis, EXE, PYZ
from PyInstaller.utils.hooks import copy_metadata, collect_submodules

_pydantic_all = collect_submodules('pydantic')

datas = [
    ("src/chip_design_mcp", "src/chip_design_mcp"),
    ("docs", "docs"),
    ("pyproject.toml", "."),
    ("INSTALL.md", "."),
]
for pkg in ("fastmcp", "fastapi", "uvicorn", "pydantic", "starlette", "httpx", "prefab_ui"):
    try:
        datas += copy_metadata(pkg)
    except Exception:
        pass

a = Analysis(
    ["run_server.py"],
    pathex=["src"],
    binaries=[],
    
    datas=datas,
    hiddenimports=[

    "_datetime",
        "uvicorn.logging",
        "uvicorn.loops",
        "uvicorn.loops.asyncio",
        "uvicorn.protocols",
        "uvicorn.protocols.http",
        "uvicorn.protocols.http.httptools_impl",
        "uvicorn.protocols.http.h11_impl",
        "uvicorn.lifespan",
        "uvicorn.lifespan.on",
        "chip_design_mcp.chiplab",
        "chip_design_mcp.prompts_resources",
        "chip_design_mcp.tools",
        "chip_design_mcp.tools.agentic",
        "chip_design_mcp.tools.depot",
        "chip_design_mcp.tools.place_route",
        "chip_design_mcp.tools.prefab",
        "chip_design_mcp.tools.simulation",
        "chip_design_mcp.tools.standard_cells",
        "chip_design_mcp.tools.synthesis",
        "chip_design_mcp.tools.verification",
    "_strptime",
],
    hookspath=[],
    
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "playwright",
        "torch",
        "volare",
        "cocotb",
    ],
    noarchive=True,
    optimize=0,
)
# Strip .dist-info but preserve metadata for packages that need it at runtime
_keep_dist = ['fastmcp-', 'mcp-', 'fastapi-', 'pydantic-', 'uvicorn-', 'prefab_ui']
_saved = [e for e in a.datas if isinstance(e, tuple) and any(k in str(e[0]) for k in _keep_dist) and '.dist-info' in str(e[0])]
for _list in [a.datas, a.binaries, a.zipfiles, a.scripts]:
    _list[:] = [e for e in _list if not (isinstance(e, tuple) and '.dist-info' in str(e[0]))]
a.datas.extend(_saved)
SKIP = ['torch','playwright','bitsandbytes','llvmlite','pyarrow','pymupdf','grpc','numba','Cython','google','azure','boto3','botocore','matplotlib','PIL','pandas','scipy','sklearn','onnxruntime']
a.binaries = [b for b in a.binaries if not any(s in b[0].lower() for s in SKIP)]
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    
    name="chip-design-mcp-backend",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)





