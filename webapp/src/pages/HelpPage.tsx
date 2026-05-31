import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { HELP_TABS } from '../lib/helpSlugs';
import HelpDocPanel from '../components/HelpDocPanel';

export default function HelpPage() {
  const [params, setParams] = useSearchParams();
  const initial = params.get('tab') ?? 'install';
  const [active, setActive] = useState(
    HELP_TABS.some((t) => t.id === initial) ? initial : 'install',
  );

  useEffect(() => {
    const tab = params.get('tab');
    if (tab && HELP_TABS.some((t) => t.id === tab)) {
      setActive(tab);
    }
  }, [params]);

  const selectTab = (id: string) => {
    setActive(id);
    setParams({ tab: id });
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-1">Help & Documentation</h1>
      <p className="text-gray-400 text-sm mb-6">
        Fleet README stack and per-domain tool guides — same content as <code className="text-emerald-400">docs/tools/</code>
      </p>

      <div className="flex flex-wrap gap-1 border-b border-gray-800 pb-0 mb-6">
        {HELP_TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => selectTab(tab.id)}
            className={`px-3 py-2 text-xs font-medium rounded-t-lg border-b-2 -mb-px whitespace-nowrap ${
              active === tab.id
                ? 'border-emerald-500 text-emerald-400 bg-emerald-900/20'
                : 'border-transparent text-gray-500 hover:text-gray-300 hover:bg-gray-800/40'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <HelpDocPanel slug={active} />
      </div>
    </div>
  );
}
