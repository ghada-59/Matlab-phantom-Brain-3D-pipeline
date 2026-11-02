import { useAppState } from '../app/store.js';
import CompareGrid from '../features/denoise/CompareGrid.jsx';
import Panel from '../components/Panel.jsx';
import { formatRelative, UNMEASURED } from '../utils/format.js';

export default function DenoisePage() {
  const { state } = useAppState();
  return (
    <>
      <header className="page-head">
        <p className="kicker">Débruitage</p>
        <h1>Effet sur le volume</h1>
        <p>Un PSNR élevé ne prouve pas que le contour est conservé. L'erreur de volume est la mesure qui compte.</p>
      </header>
      <div className="page-body">
        <Panel title="Avant filtrage">
          <p>
            Erreur de volume <span className="num">{formatRelative(state.denoise?.relErrVoxelVolumeBefore)}</span>
          </p>
          <p className="unit">{state.denoise ? 'Valeur lue dans denoise.json.' : `Fichier absent. ${UNMEASURED}`}</p>
        </Panel>
        <CompareGrid denoise={state.denoise} />
      </div>
    </>
  );
}
