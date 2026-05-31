import DomainPageShell from '../components/DomainPageShell';

const tools = (
  <ul className="space-y-2 text-sm text-gray-300">
    <li>
      <code className="text-emerald-400">sim_list_tests</code> — List available testbenches
    </li>
    <li>
      <code className="text-emerald-400">sim_run_testbench</code> — Run cocotb testbench
    </li>
    <li>
      <code className="text-emerald-400">sim_read_waveform</code> — Read VCD waveform data
    </li>
    <li>
      <code className="text-emerald-400">sim_check_coverage</code> — Check test coverage
    </li>
  </ul>
);

export default function SimulationPage() {
  return (
    <DomainPageShell
      title="Simulation"
      subtitle="cocotb + iverilog testbench management"
      helpSlug="simulation"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        {tools}
      </div>
    </DomainPageShell>
  );
}
