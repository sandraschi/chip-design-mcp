import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { apiGet } from '../lib/api';
import { Activity, Boxes, Cpu, Layers } from 'lucide-react';

interface ToolsResponse {
  count?: number;
  tools?: string[];
}

export default function Dashboard() {
  const [status, setStatus] = useState<Record<string, unknown> | null>(null);
  const [tools, setTools] = useState<string[]>([]);

  useEffect(() => {
    apiGet('/api/v1/status').then(setStatus).catch(console.error);
    apiGet<ToolsResponse>('/api/v1/tools').then((d) => setTools(d.tools ?? [])).catch(console.error);
  }, []);

  const cards = [
    { label: 'Server', value: String(status?.server ?? 'offline'), icon: Activity, color: 'emerald' },
    { label: 'Version', value: String(status?.version ?? '-'), icon: Cpu, color: 'blue' },
    { label: 'Mode', value: String(status?.mode ?? '-'), icon: Layers, color: 'purple' },
    { label: 'Tools', value: String(tools.length), icon: Boxes, color: 'amber' },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-2">Chip Design Dashboard</h1>
      <p className="text-gray-400 text-sm mb-6">RTL-to-GDSII MCP gateway and OpenLane toolchain</p>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {cards.map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="bg-gray-900 border border-gray-800 rounded-lg p-4">
            <div className={`flex items-center gap-2 text-sm text-gray-400 mb-1 text-${color}-400`}>
              <Icon size={14} />
              {label}
            </div>
            <div className="text-xl font-mono text-gray-100">{value}</div>
          </div>
        ))}
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-lg p-4 mb-4">
        <h2 className="text-lg font-semibold mb-3">Registered tools ({tools.length})</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-1 max-h-64 overflow-y-auto">
          {tools.map((t) => (
            <code key={t} className="text-xs text-gray-400 bg-gray-800 px-2 py-1 rounded">
              {t}
            </code>
          ))}
        </div>
      </div>

      <p className="text-sm text-gray-500">
        <Link to="/help" className="text-emerald-400 hover:text-emerald-300">
          Help and docs
        </Link>
        {' '}
        mirror <code className="text-emerald-400">docs/tools/</code> via the REST help API.
      </p>
    </div>
  );
}
