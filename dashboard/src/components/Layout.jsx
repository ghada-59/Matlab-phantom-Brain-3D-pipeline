import { Suspense } from 'react';
import { Outlet } from 'react-router-dom';
import { useAppState } from '../app/store.js';
import MetricTable from './MetricTable.jsx';
import Sidebar from './Sidebar.jsx';
import ErrorBoundary from './ErrorBoundary.jsx';
import withLoading from './withLoading.jsx';
import { UNMEASURED } from '../utils/format.js';

function MeasureColumn({ results, batch, status }) {
  const loaded = Boolean(results?.measurements);
  let note = status?.reason || 'Aucune exécution.';
  if (loaded) {
    note = 'Valeurs lues dans results.json.';
  } else if (batch && batch.length > 0) {
    note = 'batch.csv est présent, mais results.json n\'est pas chargé. Cette colonne reste sans mesure.';
  }
  return (
    <>
      <h2>Mesures</h2>
      <p className="unit">{note}</p>
      <MetricTable measurements={loaded ? results.measurements : null} batch={loaded ? batch : []} />
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
        <span>
          {state.results
            ? 'Résultats : chargés'
            : `Exécuté : ${state.status ? (state.status.executed ? 'oui' : 'non') : UNMEASURED}`}
        </span>
      </footer>
    </div>
  );
}
