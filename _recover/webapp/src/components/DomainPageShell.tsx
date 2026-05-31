import { useState } from 'react';
import { Link } from 'react-router-dom';
import HelpDocPanel from './HelpDocPanel';

type Tab = 'overview' | 'help';

export default function DomainPageShell({
  title,
  subtitle,
  helpSlug,
  children,
}: {
  title: string;
  subtitle: string;
  helpSlug: string;
  children: React.ReactNode;
}) {
  const [tab, setTab] = useState<Tab>('overview');

  return (
    <div>
      <div className="flex flex-wrap items-start justify-between gap-4 mb-4">
        <div>
          <h1 className="text-2xl font-bold text-white">{title}</h1>
          <p className="text-gray-400 text-sm mt-1">{subtitle}</p>
        </div>
        <Link
          to={`/help?tab=${helpSlug}`}
          className="text-xs text-emerald-400 hover:text-emerald-300 border border-emerald-800/50 rounded px-3 py-1.5"
        >
          Open in Help →
        </Link>
      </div>

      <div className="flex gap-1 border-b border-gray-800 mb-6">
        {(['overview', 'help'] as Tab[]).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={`px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 -mb-px ${
              tab === t
                ? 'border-emerald-500 text-emerald-400 bg-emerald-900/20'
                : 'border-transparent text-gray-500 hover:text-gray-300'
            }`}
          >
            {t === 'overview' ? 'Overview' : 'Help'}
          </button>
        ))}
      </div>

      {tab === 'overview' ? children : <HelpDocPanel slug={helpSlug} />}
    </div>
  );
}
