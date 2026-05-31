import { useEffect, useState } from 'react';
import { apiGet } from '../lib/api';

export default function StatusPage() {
  const [status, setStatus] = useState<Record<string, unknown> | null>(null);

  useEffect(() => {
    const load = () =>
      apiGet('/api/v1/status')
        .then(setStatus)
        .catch(() => {});
    load();
    const interval = setInterval(load, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">Status</h1>
      {status ? (
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-4">
          <table className="w-full text-sm">
            <tbody>
              {Object.entries(status).map(([key, value]) => (
                <tr key={key} className="border-b border-gray-800/50">
                  <td className="py-2 text-gray-400 font-mono">{key}</td>
                  <td className="py-2 text-gray-200 font-mono">{String(value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="text-gray-500">Connecting to server...</div>
      )}
    </div>
  );
}
