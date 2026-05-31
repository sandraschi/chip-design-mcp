const API_BASE = import.meta.env.DEV ? '' : 'http://127.0.0.1:11022';

export async function apiGet<T = Record<string, unknown>>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const err = (await res.json()) as { detail?: unknown };
      if (typeof err.detail === 'string') detail = err.detail;
      else if (err.detail != null) detail = JSON.stringify(err.detail);
    } catch {
      /* non-JSON error body */
    }
    throw new Error(`${res.status} ${detail}`);
  }
  return res.json() as Promise<T>;
}

export async function apiPost<T = Record<string, unknown>>(
  path: string,
  body?: unknown,
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const err = (await res.json()) as { detail?: unknown };
      if (typeof err.detail === 'string') detail = err.detail;
      else if (err.detail != null) detail = JSON.stringify(err.detail);
    } catch {
      /* non-JSON */
    }
    throw new Error(`${res.status} ${detail}`);
  }
  return res.json() as Promise<T>;
}
