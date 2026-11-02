import { useAppState } from '../app/store.js';
import { publicData } from '../utils/paths.js';
import { UNMEASURED } from '../utils/format.js';

export default function VideoPage() {
  const { state } = useAppState();
  const video = state.results?.video;
  const ready = video?.status === 'generated' && video.file;
  return (
    <>
      <header className="page-head">
        <p className="kicker">Vidéo</p>
        <h1>Rotation</h1>
        <p>MP4 écrit par VideoWriter. Sans affichage MATLAB, le fichier n'est pas produit.</p>
      </header>
      <div className="page-body">
        {ready ? (
          <video controls src={publicData(video.file)} style={{ width: '100%', background: '#1c1916' }}>
            Rotation du maillage
          </video>
        ) : (
          <div className="chart-empty">
            <p>Vidéo non générée.</p>
            <p className="num">{UNMEASURED}</p>
            <p className="unit">{video?.reason || state.status?.reason || 'rotation.mp4 absent.'}</p>
          </div>
        )}
      </div>
    </>
  );
}
