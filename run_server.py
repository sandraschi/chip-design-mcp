"""Entry point for PyInstaller-bundled server."""
import sys

sys.path.insert(0, ".")

from chip_design_mcp.server import main

main()
