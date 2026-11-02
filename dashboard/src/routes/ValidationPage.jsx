import { useAppState } from '../app/store.js';
import ErrorChart from '../features/metrics/ErrorChart.jsx';
import Panel from '../components/Panel.jsx';
import { UNMEASURED } from '../utils/format.js';

export default function ValidationPage() {
  const { state } = useAppState();
  const rows = state.validation;
  return (
    <>
      <header className="page-head">
        <p className="kicker">Validation</p>
        <h1>Fantômes</h1>
        <p>
          Le code prévoit les voxels 0,5 mm, 1 mm et 2 mm, deux niveaux de bruit et une rotation.
          Ce sont des conditions, pas des erreurs mesurées.
        </p>
      </header>
      <div className="page-body">
        <ErrorChart rows={rows} />
        <Panel title="Lignes chargées">
          <p className="num">{rows.length > 0 ? String(rows.length) : UNMEASURED}</p>
        </Panel>
      </div>
    </>
  );
}
