import { Suspense } from 'react';
import { Outlet } from 'react-router-dom';
import { useAppState } from '../app/store.js';
import MetricTable from './MetricTable.jsx';
import Sidebar from './Sidebar.jsx';
import ErrorBoundary from './ErrorBoundary.jsx';
import withLoading from './withLoading.jsx';
import { UNMEASURED } from '../utils/format.js';

function MeasureColumn({ results, batch, status }) {
  return (
    <>
      <h2>Mesures</h2>
      <p className="unit">
        {status?.executed ? 'Fichier de résultats chargé.' : (status?.reason || 'Aucune exécution.')}
      </p>
      <MetricTable measurements={results?.measurements} batch={batch} />
    </>
  );
}

const LoadedMeasures = withLoading(MeasureColumn);

export default function Layout() {
  const { state } = useAppState();
  const version = state.status?.version || UNMEASURED;
  return (
    <div className="app-shell">
      <a className="skip" href="#contenu">Aller au contenu</a>
      <div className="banner">Projet académique, non clinique. Aucune donnée patient.</div>
      <Sidebar />
      <div className="workspace" id="contenu">
        <ErrorBoundary>
          <Suspense fallback={<p className="page-body">Chargement de la page…</p>}>
            <Outlet />
          </Suspense>
        </ErrorBoundary>
      </div>
      <aside className="measures" aria-label="Mesures">
        <LoadedMeasures
          loadState={state.loadState}
          error={state.error}
          results={state.results}
          batch={state.batch}
          status={state.status}
        />
      </aside>
      <footer className="strip">
        <span>Schéma {version}</span>
        <span>Unités mm, mm², mm³, HU</span>
        <span>Exécuté : {state.status ? (state.status.executed ? 'oui' : 'non') : UNMEASURED}</span>
      </footer>
    </div>
  );
}
