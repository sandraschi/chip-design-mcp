import DomainPageShell from '../components/DomainPageShell';

export default function PlaceRoutePage() {
  return (
    <DomainPageShell
      title="Place & Route"
      subtitle="OpenLane automated RTL-to-GDSII flow"
      helpSlug="place_route"
    >
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-white mb-3">Available Tools</h2>
        <ul className="space-y-2 text-sm text-gray-300">
          <li>
            <code className="text-emerald-400">pr_status</code> — Check OpenLane/Docker availability
          </li>
          <li>
            <code className="text-emerald-400">pr_create_design</code> — Create new design project
          </li>
          <li>
            <code className="text-emerald-400">pr_configure</code> — Configure flow parameters
          </li>
          <li>
            <code className="text-emerald-400">pr_run_flow</code> — Run RTL-to-GDS flow
          </li>
          <li>
            <code className="text-emerald-400">pr_read_reports</code> — Read timing/power/area
            reports
          </li>
          <li>
            <code className="text-emerald-400">pr_export_gds</code> — Export GDSII layout
          </li>
          <li>
            <code className="text-emerald-400">pr_export_lef</code> — Export LEF macro view
          </li>
        </ul>
      </div>
    </DomainPageShell>
  );
}
