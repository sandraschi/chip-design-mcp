import {
  Activity,
  BookOpen,
  Boxes,
  CircuitBoard,
  Cpu,
  FlaskConical,
  Grid3x3,
  Map as MapIcon,
  Microchip,
  TestTube2,
} from 'lucide-react';
import { useState } from 'react';
import { NavLink } from 'react-router-dom';

const navItems = [
  { to: '/', label: 'Dashboard', icon: Activity },
  { to: '/synthesis', label: 'Synthesis', icon: Cpu },
  { to: '/simulation', label: 'Simulation', icon: FlaskConical },
  { to: '/place-route', label: 'Place & Route', icon: MapIcon },
  { to: '/verification', label: 'Verification', icon: CircuitBoard },
  { to: '/cells', label: 'Standard Cells', icon: Grid3x3 },
  { to: '/depot', label: 'Depot', icon: Boxes },
  { to: '/chiplab', label: 'ChipLab', icon: TestTube2 },
  { to: '/help', label: 'Help', icon: BookOpen },
  { to: '/status', label: 'Status', icon: Microchip },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="flex h-screen">
      <aside
        className={`bg-gray-900 border-r border-gray-800 transition-all ${collapsed ? 'w-14' : 'w-56'}`}
      >
        <div className="p-3 border-b border-gray-800 flex items-center gap-2">
          <Microchip size={20} className="text-emerald-400 shrink-0" />
          {!collapsed && <span className="font-semibold text-sm">Chip Design MCP</span>}
        </div>
        <button
          type="button"
          className="w-full p-2 text-xs text-gray-500 hover:text-gray-300 border-b border-gray-800"
          onClick={() => setCollapsed(!collapsed)}
        >
          {collapsed ? '>' : '<'}
        </button>
        <nav className="p-2 space-y-1">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-2 px-2 py-2 rounded text-sm transition ${
                  isActive
                    ? 'bg-emerald-900/40 text-emerald-300'
                    : 'text-gray-400 hover:text-gray-200 hover:bg-gray-800'
                }`
              }
            >
              <Icon size={16} className="shrink-0" />
              {!collapsed && <span>{label}</span>}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="flex-1 overflow-auto p-6">{children}</main>
    </div>
  );
}
