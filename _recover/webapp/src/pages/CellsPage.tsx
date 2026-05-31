import DomainPageShell from '../components/DomainPageShell';

export default function CellsPage() {
  return (
    <DomainPageShell
      title="Standard Cells"
      subtitle="PDK library browsing: SkyWater 130nm / GF180 / IHP"
      helpSlug="standard_cells"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        <ul className="space-y-2 text-sm text-gray-300">
          <li><code className="text-emerald-400">cells_list</code> — List standard cells</li>
          <li><code className="text-emerald-400">cells_info</code> — Get cell details</li>
          <li><code className="text-emerald-400">cells_search</code> — Search by logic function</li>
          <li><code className="text-emerald-400">cells_stats</code> — Library statistics</li>
        </ul>
      </div>
    </DomainPageShell>
  );
}
