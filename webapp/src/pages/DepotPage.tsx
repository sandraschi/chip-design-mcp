import DomainPageShell from '../components/DomainPageShell';

export default function DepotPage() {
  return (
    <DomainPageShell
      title="Depot"
      subtitle="Project scaffolding, file management, artifact export"
      helpSlug="depot"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        <ul className="space-y-2 text-sm text-gray-300">
          <li>
            <code className="text-emerald-400">depot_init</code> — Create new chip project
          </li>
          <li>
            <code className="text-emerald-400">depot_list</code> — List files and projects
          </li>
          <li>
            <code className="text-emerald-400">depot_status</code> — Depot storage statistics
          </li>
        </ul>
      </div>
    </DomainPageShell>
  );
}
