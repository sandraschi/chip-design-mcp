import DomainPageShell from '../components/DomainPageShell';

export default function VerificationPage() {
  return (
    <DomainPageShell
      title="Verification"
      subtitle="DRC, LVS, STA, and formal equivalence checking"
      helpSlug="verification"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        <ul className="space-y-2 text-sm text-gray-300">
          <li>
            <code className="text-emerald-400">verify_drc</code> — Design rule check (Magic)
          </li>
          <li>
            <code className="text-emerald-400">verify_lvs</code> — Layout vs schematic (netgen)
          </li>
          <li>
            <code className="text-emerald-400">verify_timing</code> — Static timing analysis
            (OpenSTA)
          </li>
          <li>
            <code className="text-emerald-400">verify_formal</code> — Formal equivalence check
            (Yosys)
          </li>
        </ul>
      </div>
    </DomainPageShell>
  );
}
