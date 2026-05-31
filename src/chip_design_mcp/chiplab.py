"""ChipLab workflow orchestration for the REST webapp (start, supervise, assess)."""

from __future__ import annotations

import asyncio
import os
import shutil
import uuid
from collections.abc import Awaitable, Callable
from copy import deepcopy
from datetime import UTC, datetime
from typing import Any

PIPELINE_STAGES = [
    {"id": "rtl", "label": "RTL / depot", "tools": ["depot_init", "depot_list"]},
    {"id": "sim", "label": "Simulation", "tools": ["sim_run_testbench", "sim_list_tests"]},
    {"id": "syn", "label": "Synthesis", "tools": ["syn_read_verilog", "syn_run", "syn_stats"]},
    {"id": "pnr", "label": "Place & route", "tools": ["pr_run_flow", "pr_read_reports"]},
    {"id": "signoff", "label": "Signoff", "tools": ["verify_drc", "verify_lvs", "verify_timing"]},
]

PRESETS: dict[str, dict[str, Any]] = {
    "project_bringup": {
        "label": "Project bring-up",
        "description": "Scaffold RTL, testbench, and OpenLane config under designs/.",
        "estimated_minutes": 1,
        "steps": [
            {"id": "init", "label": "Initialize depot project", "tool": "depot_init"},
        ],
    },
    "rtl_validate": {
        "label": "RTL validate (sim)",
        "description": "Create project, stage RTL for sim, run cocotb smoke test.",
        "estimated_minutes": 5,
        "steps": [
            {"id": "init", "label": "Initialize depot project", "tool": "depot_init"},
            {"id": "stage", "label": "Copy RTL to uploads", "builtin": "copy_rtl_to_uploads"},
            {"id": "sim", "label": "Run cocotb testbench", "tool": "sim_run_testbench"},
        ],
    },
    "synthesis_loop": {
        "label": "Synthesis loop",
        "description": "Yosys read → synth → stats on staged RTL.",
        "estimated_minutes": 3,
        "steps": [
            {"id": "init", "label": "Initialize depot project", "tool": "depot_init"},
            {"id": "stage", "label": "Copy RTL to uploads", "builtin": "copy_rtl_to_uploads"},
            {"id": "read", "label": "Load Verilog in Yosys", "tool": "syn_read_verilog"},
            {"id": "syn", "label": "Run Yosys synthesis", "tool": "syn_run"},
            {"id": "stats", "label": "Synthesis statistics", "tool": "syn_stats"},
        ],
    },
    "full_tapeout": {
        "label": "Full RTL→GDSII (long)",
        "description": "Sim gate, synthesis, then OpenLane through signoff. Can take 30-90+ minutes.",
        "estimated_minutes": 60,
        "steps": [
            {"id": "init", "label": "Initialize depot project", "tool": "depot_init"},
            {"id": "stage", "label": "Copy RTL to uploads", "builtin": "copy_rtl_to_uploads"},
            {"id": "sim", "label": "Run cocotb testbench", "tool": "sim_run_testbench"},
            {"id": "read", "label": "Load Verilog in Yosys", "tool": "syn_read_verilog"},
            {"id": "syn", "label": "Run Yosys synthesis", "tool": "syn_run"},
            {"id": "pnr", "label": "OpenLane place & route", "tool": "pr_run_flow"},
            {"id": "reports", "label": "Read P&R reports", "tool": "pr_read_reports"},
        ],
    },
}


def _utc_now() -> str:
    return datetime.now(UTC).isoformat()


def _subst_params(obj: Any, params: dict[str, str]) -> Any:
    if isinstance(obj, str):
        out = obj
        for key, val in params.items():
            out = out.replace("{" + key + "}", val)
        return out
    if isinstance(obj, dict):
        return {k: _subst_params(v, params) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_subst_params(v, params) for v in obj]
    return obj


def _default_tool_params(tool: str, params: dict[str, str]) -> dict[str, Any]:
    project = params.get("project_name", "lab_counter")
    template = params.get("template", "counter")
    pdk = params.get("pdk", "sky130")
    verilog_file = f"{project}.v"
    test_module = f"test_{project}"
    mapping: dict[str, dict[str, Any]] = {
        "depot_init": {"project_name": project, "template": template, "pdk": pdk},
        "sim_run_testbench": {
            "dut_file": verilog_file,
            "test_module": test_module,
            "top_module": project,
            "waves": True,
        },
        "syn_read_verilog": {"file_name": verilog_file, "top_module": project},
        "syn_run": {"top_module": project, "abc9": True},
        "syn_stats": {},
        "pr_run_flow": {
            "design_name": project,
            "from_stage": "synthesis",
            "to_stage": "",
            "tag": params.get("run_tag", "chiplab"),
        },
        "pr_read_reports": {"design_name": project, "report_type": "all", "tag": params.get("run_tag", "chiplab")},
    }
    return mapping.get(tool, {})


class ChiplabManager:
    """In-memory workflow supervisor (REST-only; survives until server restart)."""

    def __init__(
        self,
        all_tools: dict[str, Callable[..., Awaitable[Any]]],
        state: dict[str, Any],
        *,
        designs_dir: str,
        upload_dir: str,
        llm_chat_fn: Callable[[str], Awaitable[dict[str, Any]]] | None = None,
    ) -> None:
        self._tools = all_tools
        self._state = state
        self._designs_dir = designs_dir
        self._upload_dir = upload_dir
        self._llm_chat = llm_chat_fn
        self._workflows: dict[str, dict[str, Any]] = {}
        self._tasks: dict[str, asyncio.Task[None]] = {}

    def list_presets(self) -> list[dict[str, Any]]:
        out = []
        for pid, preset in PRESETS.items():
            out.append(
                {
                    "id": pid,
                    "label": preset["label"],
                    "description": preset["description"],
                    "estimated_minutes": preset.get("estimated_minutes"),
                    "step_count": len(preset["steps"]),
                    "steps": [{"id": s["id"], "label": s["label"]} for s in preset["steps"]],
                }
            )
        return out

    def list_workflows(self) -> list[dict[str, Any]]:
        return [
            self._snapshot(wf) for wf in sorted(self._workflows.values(), key=lambda w: w["created_at"], reverse=True)
        ]

    def get_workflow(self, workflow_id: str) -> dict[str, Any] | None:
        wf = self._workflows.get(workflow_id)
        return self._snapshot(wf) if wf else None

    async def create_workflow(
        self,
        preset_id: str,
        params: dict[str, str] | None = None,
        *,
        auto_start: bool = True,
    ) -> dict[str, Any]:
        preset = PRESETS.get(preset_id)
        if not preset:
            raise ValueError(f"Unknown preset: {preset_id}")
        params = {k: str(v) for k, v in (params or {}).items()}
        if "project_name" not in params:
            params["project_name"] = f"lab_{uuid.uuid4().hex[:8]}"
        if "template" not in params:
            params["template"] = "counter"
        if "pdk" not in params:
            params["pdk"] = "sky130"

        wf_id = uuid.uuid4().hex
        steps = []
        for spec in preset["steps"]:
            steps.append(
                {
                    "id": spec["id"],
                    "label": spec["label"],
                    "tool": spec.get("tool"),
                    "builtin": spec.get("builtin"),
                    "status": "pending",
                    "started_at": None,
                    "finished_at": None,
                    "result": None,
                }
            )
        wf = {
            "id": wf_id,
            "preset_id": preset_id,
            "preset_label": preset["label"],
            "params": params,
            "status": "queued",
            "created_at": _utc_now(),
            "started_at": None,
            "finished_at": None,
            "steps": steps,
            "assessment": None,
            "error": None,
        }
        self._workflows[wf_id] = wf
        if auto_start:
            self._start_task(wf_id)
        return self._snapshot(wf)

    def _start_task(self, workflow_id: str) -> None:
        existing = self._tasks.get(workflow_id)
        if existing and not existing.done():
            return
        self._tasks[workflow_id] = asyncio.create_task(self._run_workflow(workflow_id))

    async def _run_workflow(self, workflow_id: str) -> None:
        wf = self._workflows.get(workflow_id)
        if not wf:
            return
        wf["status"] = "running"
        wf["started_at"] = wf["started_at"] or _utc_now()
        params = wf["params"]

        for step in wf["steps"]:
            if wf["status"] == "cancelled":
                break
            step["status"] = "running"
            step["started_at"] = _utc_now()
            try:
                if step.get("builtin") == "copy_rtl_to_uploads":
                    result = self._builtin_copy_rtl(params)
                elif step.get("tool"):
                    tool_name = step["tool"]
                    tool_fn = self._tools.get(tool_name)
                    if not tool_fn:
                        result = {"success": False, "message": f"Tool not registered: {tool_name}"}
                    else:
                        body = _subst_params(_default_tool_params(tool_name, params), params)
                        result = await tool_fn(**body)
                else:
                    result = {"success": False, "message": "Step has no tool or builtin"}
                step["result"] = result
                ok = bool(result.get("success")) if isinstance(result, dict) else False
                step["status"] = "passed" if ok else "failed"
                if not ok:
                    wf["status"] = "failed"
                    wf["error"] = result.get("message") if isinstance(result, dict) else "Step failed"
                    wf["finished_at"] = _utc_now()
                    wf["assessment"] = self._assess_workflow(wf)
                    return
            except Exception as exc:
                step["status"] = "failed"
                step["result"] = {"success": False, "message": str(exc)}
                wf["status"] = "failed"
                wf["error"] = str(exc)
                wf["finished_at"] = _utc_now()
                wf["assessment"] = self._assess_workflow(wf)
                return
            finally:
                step["finished_at"] = _utc_now()

        wf["status"] = "completed"
        wf["finished_at"] = _utc_now()
        wf["assessment"] = self._assess_workflow(wf)

    def _builtin_copy_rtl(self, params: dict[str, str]) -> dict[str, Any]:
        project = params["project_name"]
        src = os.path.join(self._designs_dir, project, "src", f"{project}.v")
        if not os.path.isfile(src):
            return {"success": False, "message": f"RTL not found: {src}", "data": None}
        os.makedirs(self._upload_dir, exist_ok=True)
        dest = os.path.join(self._upload_dir, f"{project}.v")
        shutil.copy2(src, dest)
        return {
            "success": True,
            "message": f"Staged {project}.v for synthesis/simulation",
            "data": {"source": src, "dest": dest},
        }

    def _assess_workflow(self, wf: dict[str, Any]) -> dict[str, Any]:
        steps = wf["steps"]
        passed = sum(1 for s in steps if s["status"] == "passed")
        failed = sum(1 for s in steps if s["status"] == "failed")
        total = len(steps)
        tools = self._state.get("tools") or {}
        ready = sum(1 for v in tools.values() if v)
        score = int(100 * passed / total) if total else 0
        grade = "A" if score >= 90 else "B" if score >= 70 else "C" if score >= 50 else "F"
        summary = (
            f"Workflow {wf['status']}: {passed}/{total} steps passed. "
            f"EDA tools ready: {ready}/{len(tools) or 0}. Grade {grade}."
        )
        if wf.get("error"):
            summary += f" Last error: {wf['error']}"
        return {
            "score": score,
            "grade": grade,
            "passed_steps": passed,
            "failed_steps": failed,
            "total_steps": total,
            "summary": summary,
        }

    async def assist(
        self,
        operation: str,
        *,
        prompt: str | None = None,
        workflow_id: str | None = None,
        preset_id: str | None = None,
    ) -> dict[str, Any]:
        tools = self._state.get("tools") or {}
        pdk = self._state.get("pdk_installed")
        context_lines = [
            f"EDA tools available: {sum(1 for v in tools.values() if v)}/{len(tools)}",
            f"PDK installed: {pdk}",
            "Work dir keys: designs, uploads, outputs under CHIP_DESIGN_MCP_WORK_DIR",
        ]
        if workflow_id:
            wf = self._workflows.get(workflow_id)
            if wf:
                context_lines.append(f"Active workflow {workflow_id}: status={wf['status']}, preset={wf['preset_id']}")
                for s in wf["steps"]:
                    context_lines.append(f"  - {s['label']}: {s['status']}")

        if operation == "readiness":
            return {
                "success": True,
                "operation": operation,
                "message": "ChipLab readiness snapshot",
                "data": {
                    "tools": tools,
                    "pdk_installed": pdk,
                    "pipeline": PIPELINE_STAGES,
                    "presets": [p["id"] for p in self.list_presets()],
                },
            }

        if operation == "plan":
            preset = PRESETS.get(preset_id or "rtl_validate", PRESETS["rtl_validate"])
            plan = [
                {"order": i + 1, "label": s["label"], "tool": s.get("tool") or s.get("builtin")}
                for i, s in enumerate(preset["steps"])
            ]
            hint = (
                f"Suggested preset '{preset['label']}': {len(plan)} steps. "
                "Start with project_bringup if depot is empty."
            )
            if prompt and self._llm_chat:
                llm = await self._llm_chat_with_prompt(
                    "You are a sky130 RTL-to-GDSII flow planner. Given tool availability, suggest ordered MCP tool calls.\n"
                    + "\n".join(context_lines)
                    + f"\nUser goal: {prompt}\n"
                    f"Default plan: {plan}",
                )
                if llm.get("ok"):
                    return {
                        "success": True,
                        "operation": operation,
                        "message": llm.get("response", hint),
                        "data": {"plan": plan, "preset_id": preset_id or "rtl_validate"},
                        "provider": llm.get("provider"),
                    }
            return {
                "success": True,
                "operation": operation,
                "message": hint,
                "data": {"plan": plan, "preset_id": preset_id or "rtl_validate"},
            }

        if operation == "assess":
            wf = self._workflows.get(workflow_id) if workflow_id else None
            if not wf:
                return {
                    "success": False,
                    "operation": operation,
                    "message": "workflow_id required for assess",
                    "data": None,
                }
            assessment = wf.get("assessment") or self._assess_workflow(wf)
            msg = assessment["summary"]
            provider = None
            if prompt and self._llm_chat:
                llm = await self._llm_chat_with_prompt(
                    "Assess this chip design workflow run. Be concise; list risks and next steps.\n"
                    + msg
                    + f"\nOperator question: {prompt}",
                )
                if llm.get("ok"):
                    msg = llm.get("response", msg)
                    provider = llm.get("provider")
            return {
                "success": True,
                "operation": operation,
                "message": msg,
                "data": assessment,
                "provider": provider,
            }

        if operation == "chat":
            if not prompt:
                return {"success": False, "operation": operation, "message": "prompt required", "data": None}
            if self._llm_chat:
                llm = await self._llm_chat_with_prompt(
                    "You are ChipLab assistant for open-source ASIC (Yosys, cocotb, OpenLane, sky130).\n"
                    + "\n".join(context_lines)
                    + f"\n\nUser: {prompt}",
                )
                if llm.get("ok"):
                    return {
                        "success": True,
                        "operation": operation,
                        "message": llm.get("response", ""),
                        "data": None,
                        "provider": llm.get("provider"),
                    }
                return {
                    "success": False,
                    "operation": operation,
                    "message": llm.get("error") or "LLM unavailable",
                    "data": None,
                    "suggestions": ["Start Ollama (11434) or LM Studio (1234)", "Use operation=plan without LLM"],
                }
            return {
                "success": False,
                "operation": operation,
                "message": "No local LLM detected. Start Ollama or LM Studio.",
                "data": None,
                "suggestions": [
                    "chip_status via REST",
                    "GET /api/v1/chiplab/presets for workflow templates",
                ],
            }

        return {"success": False, "operation": operation, "message": f"Unknown operation: {operation}", "data": None}

    async def _llm_chat_with_prompt(self, message: str) -> dict[str, Any]:
        if not self._llm_chat:
            return {"ok": False, "error": "LLM not configured"}
        return await self._llm_chat(message)

    def _snapshot(self, wf: dict[str, Any]) -> dict[str, Any]:
        return deepcopy(wf)
