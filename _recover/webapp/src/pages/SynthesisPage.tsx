import DomainPageShell from '../components/DomainPageShell';

export default function SynthesisPage() {
  return (
    <DomainPageShell
      title="Synthesis"
      subtitle="Yosys RTL synthesis: Verilog → gate-level netlist"
      helpSlug="synthesis"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        <ul className="space-y-2 text-sm text-gray-300">
          <li><code className="text-emerald-400">syn_status</code> — Check Yosys availability</li>
          <li><code className="text-emerald-400">syn_read_verilog</code> — Load Verilog source</li>
          <li><code className="text-emerald-400">syn_run</code> — Run synthesis pass</li>
          <li><code className="text-emerald-400">syn_stats</code> — Get synthesis statistics</li>
          <li><code className="text-emerald-400">syn_show</code> — Generate schematic diagram</li>
          <li><code className="text-emerald-400">syn_export_netlist</code> — Export gate-level netlist</li>
        </ul>
      </div>
    </DomainPageShell>
  );
}
