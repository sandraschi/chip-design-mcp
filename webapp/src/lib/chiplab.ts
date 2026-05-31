import { apiGet, apiPost } from './api';

export interface ChiplabPreset {
  id: string;
  label: string;
  description: string;
  estimated_minutes?: number;
  step_count: number;
  steps: { id: string; label: string }[];
}

export interface ChiplabStep {
  id: string;
  label: string;
  tool?: string;
  builtin?: string;
  status: 'pending' | 'running' | 'passed' | 'failed';
  started_at: string | null;
  finished_at: string | null;
  result?: Record<string, unknown> | null;
}

export interface ChiplabAssessment {
  score: number;
  grade: string;
  passed_steps: number;
  failed_steps: number;
  total_steps: number;
  summary: string;
}

export interface ChiplabWorkflow {
  id: string;
  preset_id: string;
  preset_label: string;
  params: Record<string, string>;
  status: string;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
  steps: ChiplabStep[];
  assessment: ChiplabAssessment | null;
  error: string | null;
}

export interface AssistResult {
  success: boolean;
  operation: string;
  message: string;
  data?: unknown;
  provider?: string;
  suggestions?: string[];
}

export async function fetchPresets() {
  return apiGet<{
    presets: ChiplabPreset[];
    pipeline: { id: string; label: string; tools: string[] }[];
  }>('/api/v1/chiplab/presets');
}

export async function fetchWorkflows() {
  return apiGet<{ workflows: ChiplabWorkflow[]; count: number }>('/api/v1/chiplab/workflows');
}

export async function fetchWorkflow(id: string) {
  return apiGet<ChiplabWorkflow>(`/api/v1/chiplab/workflows/${id}`);
}

export async function startWorkflow(presetId: string, params: Record<string, string>) {
  return apiPost<ChiplabWorkflow>('/api/v1/chiplab/workflows', {
    preset_id: presetId,
    params,
    auto_start: true,
  });
}

export async function chiplabAssist(body: {
  operation: 'plan' | 'assess' | 'chat' | 'readiness';
  prompt?: string;
  workflow_id?: string;
  preset_id?: string;
}) {
  return apiPost<AssistResult>('/api/v1/chiplab/assist', body);
}

export async function fetchLlmStatus() {
  return apiGet<{ ok: boolean; provider?: string; model?: string; error?: string }>(
    '/api/v1/llm/status',
  );
}
