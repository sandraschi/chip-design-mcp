import { Routes, Route } from 'react-router-dom';
import AppLayout from './components/AppLayout';
import Dashboard from './pages/Dashboard';
import SynthesisPage from './pages/SynthesisPage';
import SimulationPage from './pages/SimulationPage';
import PlaceRoutePage from './pages/PlaceRoutePage';
import VerificationPage from './pages/VerificationPage';
import CellsPage from './pages/CellsPage';
import DepotPage from './pages/DepotPage';
import HelpPage from './pages/HelpPage';
import StatusPage from './pages/StatusPage';

export default function App() {
  return (
    <AppLayout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/synthesis" element={<SynthesisPage />} />
        <Route path="/simulation" element={<SimulationPage />} />
        <Route path="/place-route" element={<PlaceRoutePage />} />
        <Route path="/verification" element={<VerificationPage />} />
        <Route path="/cells" element={<CellsPage />} />
        <Route path="/depot" element={<DepotPage />} />
        <Route path="/help" element={<HelpPage />} />
        <Route path="/status" element={<StatusPage />} />
      </Routes>
    </AppLayout>
  );
}
