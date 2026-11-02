import { useAppState } from '../app/store.js';
import MeshViewer from '../features/viewer/MeshViewer.jsx';
import LabelLegend from '../features/viewer/LabelLegend.jsx';
import { isMeasured, UNMEASURED } from '../utils/format.js';

export default function MeshPage() {
  const { state, dispatch } = useAppState();
  const axesKnown = isMeasured(state.results?.measurements?.semiAxesMM)
    && isMeasured(state.results?.axisDirections);
  return (
    <>
      <header className="page-head">
        <p className="kicker">3D</p>
        <h1>Maillage</h1>
        <p>STL en millimètres, os ivoire, axes en terre cuite s'ils ont été exportés.</p>
      </header>
      <div className="page-body">
        <div className="toolbar">
          <button
            type="button"
            aria-pressed={state.viewer.showAxes}
            disabled={!axesKnown}
            onClick={() => dispatch({ type: 'viewer', patch: { showAxes: !state.viewer.showAxes } })}
          >
            Axes principaux
          </button>
          <span className="unit">{axesKnown ? 'Directions exportées' : `Directions ${UNMEASURED}`}</span>
        </div>
        <MeshViewer results={state.results} showAxes={state.viewer.showAxes && axesKnown} />
        <LabelLegend />
      </div>
    </>
  );
}
