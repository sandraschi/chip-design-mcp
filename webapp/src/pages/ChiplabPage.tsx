import { Bot, FlaskConical, Play, RefreshCw, Sparkles } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';
import {
  type ChiplabPreset,
  type ChiplabWorkflow,
  chiplabAssist,
  fetchLlmStatus,
  fetchPresets,
  fetchWorkflow,
  fetchWorkflows,
  startWorkflow,
} from '../lib/chiplab';

const STATUS_COLORS: Record<string, string> = {
  pending: 'text-gray-500',
  running: 'text-amber-400',
  passed: 'text-emerald-400',
  failed: 'text-red-400',
  queued: 'text-gray-400',
  completed: 'text-emerald-400',
  failed_workflow: 'text-red-400',
};

function stepStatusClass(status: string) {
  return STATUS_COLORS[status] ?? 'text-gray-400';
}

export default function ChiplabPage() {
  const [presets, setPresets] = useState<ChiplabPreset[]>([]);
  const [workflows, setWorkflows] = useState<ChiplabWorkflow[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [active, setActive] = useState<ChiplabWorkflow | null>(null);
  const [presetId, setPresetId] = useState('rtl_validate');
  const [projectName, setProjectName] = useState('lab_counter');
  const [template, setTemplate] = useState('counter');
  const [pdk, setPdk] = useState('sky130');
  const [starting, setStarting] = useState(false);
  const [assistPrompt, setAssistPrompt] = useState('');
  const [assistLog, setAssistLog] = useState<{ role: string; text: string }[]>([]);
  const [llmOk, setLlmOk] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const [p, w] = await Promise.all([fetchPresets(), fetchWorkflows()]);
      setPresets(p.presets);
      setWorkflows(w.workflows);
      setError(null);
      if (selectedId) {
        const wf = await fetchWorkflow(selectedId);
        setActive(wf);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [selectedId]);

  useEffect(() => {
    refresh();
    fetchLlmStatus()
      .then((s) => setLlmOk(Boolean(s.ok)))
      .catch(() => setLlmOk(false));
    const t = setInterval(refresh, 4000);
    return () => clearInterval(t);
  }, [refresh]);

  const onStart = async () => {
    setStarting(true);
    setError(null);
    try {
      const wf = await startWorkflow(presetId, {
        project_name: projectName,
        template,
        pdk,
      });
      setSelectedId(wf.id);
      setActive(wf);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setStarting(false);
    }
  };

  const runAssist = async (operation: 'plan' | 'assess' | 'chat' | 'readiness') => {
    setError(null);
    try {
      const res = await chiplabAssist({
        operation,
        prompt: assistPrompt || undefined,
        workflow_id: active?.id,
        preset_id: presetId,
      });
      const text = res.message || JSON.stringify(res.data ?? res);
      setAssistLog((prev) => [
        ...prev,
        { role: operation, text },
        { role: res.success ? 'assistant' : 'error', text },
      ]);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const selectedPreset = presets.find((p) => p.id === presetId);

  return (
    <div className="max-w-6xl">
      <div className="flex items-start justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <FlaskConical className="text-emerald-400" size={28} />
            ChipLab
          </h1>
          <p className="text-gray-400 text-sm mt-1">
            Start supervised RTL→GDSII workflows, watch step results, and use local AI helpers
            (Ollama / LM Studio).
          </p>
        </div>
        <button
          type="button"
          onClick={() => refresh()}
          className="flex items-center gap-1 px-3 py-2 text-xs rounded-lg border border-gray-700 text-gray-300 hover:bg-gray-800"
        >
          <RefreshCw size={14} />
          Refresh
        </button>
      </div>

      {error && (
        <p className="text-red-400 text-sm mb-4 bg-red-950/40 border border-red-900 rounded-lg px-3 py-2">
          {error}
        </p>
      )}

      <div className="grid lg:grid-cols-3 gap-6">
        <section className="lg:col-span-1 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-4">
            <h2 className="text-sm font-semibold text-white mb-3">New workflow</h2>
            <label className="block text-xs text-gray-500 mb-1">Preset</label>
            <select
              value={presetId}
              onChange={(e) => setPresetId(e.target.value)}
              className="w-full bg-gray-950 border border-gray-700 rounded px-2 py-2 text-sm text-gray-200 mb-3"
            >
              {presets.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.label}
                </option>
              ))}
            </select>
            {selectedPreset && (
              <p className="text-xs text-gray-500 mb-3">{selectedPreset.description}</p>
            )}
            <label className="block text-xs text-gray-500 mb-1">Project name</label>
            <input
              value={projectName}
              onChange={(e) => setProjectName(e.target.value)}
              className="w-full bg-gray-950 border border-gray-700 rounded px-2 py-2 text-sm font-mono text-gray-200 mb-2"
            />
            <div className="grid grid-cols-2 gap-2 mb-3">
              <div>
                <label className="block text-xs text-gray-500 mb-1">Template</label>
                <select
                  value={template}
                  onChange={(e) => setTemplate(e.target.value)}
                  className="w-full bg-gray-950 border border-gray-700 rounded px-2 py-1.5 text-xs text-gray-200"
                >
                  <option value="counter">counter</option>
                  <option value="alu">alu</option>
                  <option value="fsm">fsm</option>
                  <option value="empty">empty</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">PDK</label>
                <select
                  value={pdk}
                  onChange={(e) => setPdk(e.target.value)}
                  className="w-full bg-gray-950 border border-gray-700 rounded px-2 py-1.5 text-xs text-gray-200"
                >
                  <option value="sky130">sky130</option>
                  <option value="gf180mcu">gf180mcu</option>
                </select>
              </div>
            </div>
            <button
              type="button"
              disabled={starting}
              onClick={onStart}
              className="w-full flex items-center justify-center gap-2 py-2 rounded-lg bg-emerald-700 hover:bg-emerald-600 text-white text-sm font-medium disabled:opacity-50"
            >
              <Play size={16} />
              {starting ? 'Starting…' : 'Start workflow'}
            </button>
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-lg p-4">
            <h2 className="text-sm font-semibold text-white mb-2 flex items-center gap-2">
              <Bot size={16} className={llmOk ? 'text-emerald-400' : 'text-gray-500'} />
              AI helper
              <span
                className={`text-xs font-normal ${llmOk ? 'text-emerald-500' : 'text-gray-600'}`}
              >
                {llmOk ? 'LLM online' : 'LLM offline'}
              </span>
            </h2>
            <textarea
              value={assistPrompt}
              onChange={(e) => setAssistPrompt(e.target.value)}
              placeholder="Ask for a flow plan, assessment, or tool advice…"
              rows={3}
              className="w-full bg-gray-950 border border-gray-700 rounded px-2 py-2 text-sm text-gray-200 mb-2"
            />
            <div className="flex flex-wrap gap-1">
              <button
                type="button"
                onClick={() => runAssist('plan')}
                className="px-2 py-1 text-xs rounded bg-gray-800 text-gray-300 hover:bg-gray-700"
              >
                Plan
              </button>
              <button
                type="button"
                onClick={() => runAssist('assess')}
                disabled={!active}
                className="px-2 py-1 text-xs rounded bg-gray-800 text-gray-300 hover:bg-gray-700 disabled:opacity-40"
              >
                Assess run
              </button>
              <button
                type="button"
                onClick={() => runAssist('chat')}
                className="px-2 py-1 text-xs rounded bg-gray-800 text-gray-300 hover:bg-gray-700"
              >
                Chat
              </button>
              <button
                type="button"
                onClick={() => runAssist('readiness')}
                className="px-2 py-1 text-xs rounded bg-gray-800 text-gray-300 hover:bg-gray-700"
              >
                Readiness
              </button>
            </div>
            {assistLog.length > 0 && (
              <div className="mt-3 max-h-40 overflow-y-auto space-y-2 text-xs">
                {assistLog.slice(-6).map((entry, i) => (
                  <div
                    key={`${entry.role}-${i}`}
                    className={
                      entry.role === 'error'
                        ? 'text-red-400'
                        : entry.role === 'assistant'
                          ? 'text-gray-300'
                          : 'text-emerald-500 font-mono'
                    }
                  >
                    <span className="opacity-60">{entry.role}: </span>
                    {entry.text.slice(0, 800)}
                    {entry.text.length > 800 ? '…' : ''}
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>

        <section className="lg:col-span-2 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-4 min-h-[200px]">
            <h2 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
              <Sparkles size={16} className="text-amber-400" />
              Active run
            </h2>
            {!active ? (
              <p className="text-gray-500 text-sm">
                Select a workflow from history or start a new one.
              </p>
            ) : (
              <>
                <div className="flex flex-wrap gap-3 text-xs mb-4">
                  <span className="font-mono text-gray-400">{active.id.slice(0, 8)}…</span>
                  <span className={stepStatusClass(active.status)}>{active.status}</span>
                  <span className="text-gray-500">{active.preset_label}</span>
                  <span className="text-gray-500">project: {active.params.project_name}</span>
                </div>
                {active.assessment && (
                  <div className="mb-4 p-3 rounded-lg bg-gray-950 border border-gray-800 text-sm">
                    <span className="text-amber-400 font-bold mr-2">
                      Grade {active.assessment.grade}
                    </span>
                    <span className="text-gray-400">{active.assessment.summary}</span>
                  </div>
                )}
                <ol className="space-y-2">
                  {active.steps.map((step) => (
                    <li
                      key={step.id}
                      className="border border-gray-800 rounded-lg px-3 py-2 text-sm"
                    >
                      <div className="flex justify-between gap-2">
                        <span className="text-gray-200">{step.label}</span>
                        <span className={`font-mono text-xs ${stepStatusClass(step.status)}`}>
                          {step.status}
                        </span>
                      </div>
                      {(step.tool || step.builtin) && (
                        <p className="text-xs text-gray-600 font-mono mt-0.5">
                          {step.tool ?? step.builtin}
                        </p>
                      )}
                      {step.result && (
                        <p className="text-xs text-gray-500 mt-1 truncate">
                          {String((step.result as { message?: string }).message ?? '')}
                        </p>
                      )}
                    </li>
                  ))}
                </ol>
              </>
            )}
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-lg p-4">
            <h2 className="text-sm font-semibold text-white mb-2">History</h2>
            {workflows.length === 0 ? (
              <p className="text-gray-500 text-xs">No workflows yet this session.</p>
            ) : (
              <ul className="space-y-1 max-h-48 overflow-y-auto">
                {workflows.map((wf) => (
                  <li key={wf.id}>
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedId(wf.id);
                        setActive(wf);
                      }}
                      className={`w-full text-left px-2 py-1.5 rounded text-xs ${
                        selectedId === wf.id
                          ? 'bg-emerald-900/30 text-emerald-200'
                          : 'text-gray-400 hover:bg-gray-800'
                      }`}
                    >
                      <span className="font-mono">{wf.params.project_name}</span>
                      <span className="mx-2 opacity-50">·</span>
                      <span>{wf.preset_label}</span>
                      <span className={`float-right ${stepStatusClass(wf.status)}`}>
                        {wf.status}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
