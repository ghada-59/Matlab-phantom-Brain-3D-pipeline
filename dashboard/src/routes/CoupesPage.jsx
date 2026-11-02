import { useAppState } from '../app/store.js';
import MprViewer from '../features/viewer/MprViewer.jsx';
import WindowLevel from '../features/viewer/WindowLevel.jsx';

export default function CoupesPage() {
  const { state, dispatch } = useAppState();
  return (
    <>
      <header className="page-head">
        <p className="kicker">Coupes</p>
        <h1>Trois plans</h1>
        <p>Images en niveaux de gris. La fenêtre est un réglage d'affichage en HU.</p>
      </header>
      <div className="page-body">
        <WindowLevel
          preset={state.viewer.preset}
          level={state.viewer.windowLevel}
          width={state.viewer.windowWidth}
          onChange={(patch) => dispatch({ type: 'viewer', patch })}
        />
        <MprViewer />
      </div>
    </>
  );
}
