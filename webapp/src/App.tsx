import { Route, Routes } from 'react-router-dom';
import AppLayout from './components/AppLayout';
import CellsPage from './pages/CellsPage';
import ChiplabPage from './pages/ChiplabPage';
import Dashboard from './pages/Dashboard';
import DepotPage from './pages/DepotPage';
import HelpPage from './pages/HelpPage';
import LogsPage from './pages/LogsPage';
import PlaceRoutePage from './pages/PlaceRoutePage';
import SimulationPage from './pages/SimulationPage';
import StatusPage from './pages/StatusPage';
import SynthesisPage from './pages/SynthesisPage';
import VerificationPage from './pages/VerificationPage';

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
        <Route path="/chiplab" element={<ChiplabPage />} />
        <Route path="/help" element={<HelpPage />} />
        <Route path="/logs" element={<LogsPage />} />
        <Route path="/status" element={<StatusPage />} />
      </Routes>
    </AppLayout>
  );
}
