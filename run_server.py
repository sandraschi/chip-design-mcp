"""Entry point for PyInstaller-bundled server."""
import _strptime  # noqa: F401 -- PyInstaller must bundle this eagerly
import os
import sys

sys.path.insert(0, ".")
if getattr(sys, "frozen", False):
    meipass = getattr(sys, "_MEIPASS", "")
    if meipass:
        os.environ.setdefault("CHIP_DESIGN_MCP_REPO_ROOT", meipass)

from chip_design_mcp.server import main

main()

