"""Smoke tests for chip-design-mcp (no EDA tools required)."""

from __future__ import annotations

import importlib

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from chip_design_mcp.server import app

    with TestClient(app) as c:
        yield c


def test_package_import():
    pkg = importlib.import_module("chip_design_mcp")
    assert pkg.__version__ == "0.1.0"


def test_server_import():
    mod = importlib.import_module("chip_design_mcp.server")
    assert mod._HELP_SLUGS
    assert "fabrication" in mod._HELP_SLUGS


def test_status(client: TestClient):
    r = client.get("/api/v1/status")
    assert r.status_code == 200
    body = r.json()
    assert body["server"] == "chip-design-mcp"
    assert "tools" in body
    assert "uptime_s" in body


def test_tools_list(client: TestClient):
    r = client.get("/api/v1/tools")
    assert r.status_code == 200
    body = r.json()
    assert body["count"] >= 31
    assert "chip_status" in body["tools"]
    assert "syn_run" in body["tools"]
    assert "depot_init" in body["tools"]


def test_capabilities(client: TestClient):
    r = client.get("/api/capabilities")
    assert r.status_code == 200
    body = r.json()
    assert body["server"]["name"] == "chip-design-mcp"
    assert "fabrication" in body["features"]["help_slugs"]


def test_well_known_manifest(client: TestClient):
    r = client.get("/.well-known/mcp/manifest.json")
    assert r.status_code == 200
    body = r.json()
    assert body.get("name") == "chip-design-mcp"


def test_help_index(client: TestClient):
    r = client.get("/api/v1/help")
    assert r.status_code == 200
    slugs = r.json()["slugs"]
    assert "fabrication" in slugs
    assert "synthesis" in slugs
    assert "pdk" in slugs


@pytest.mark.parametrize(
    "slug",
    [
        "fabrication",
        "synthesis",
        "simulation",
        "place_route",
        "verification",
        "standard_cells",
        "depot",
        "system",
        "install",
        "pdk",
    ],
)
def test_help_slug(client: TestClient, slug: str):
    r = client.get(f"/api/v1/help/{slug}")
    assert r.status_code == 200
    body = r.json()
    assert body["slug"] == slug
    assert len(body["content"]) > 50


def test_chip_status_control(client: TestClient):
    r = client.post("/api/v1/control/chip_status", json={})
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "tools" in body


def test_depot_init(client: TestClient, tmp_path, monkeypatch):
    monkeypatch.setenv("CHIP_DESIGN_MCP_WORK_DIR", str(tmp_path))
    import chip_design_mcp.server as srv

    srv.WORK_DIR = str(tmp_path)
    srv.UPLOAD_DIR = str(tmp_path / "uploads")
    srv.OUTPUT_DIR = str(tmp_path / "output")
    srv.DESIGNS_DIR = str(tmp_path / "designs")
    srv._state["work_dir"] = srv.WORK_DIR
    for d in (srv.UPLOAD_DIR, srv.OUTPUT_DIR, srv.DESIGNS_DIR):
        d_path = __import__("os").path
        __import__("os").makedirs(d, exist_ok=True)

    r = client.post(
        "/api/v1/control/depot_init",
        json={"project_name": "test_counter", "template": "counter"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
