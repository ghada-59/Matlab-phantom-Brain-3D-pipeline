import ColorbarSVG from '../../components/ColorbarSVG.jsx';
import { divergingStops } from '../../utils/colormaps.js';
import { formatMeasurement, formatRelative, UNMEASURED, isMeasured } from '../../utils/format.js';

const METHODS = [
  ['gaussian', 'Gaussien'],
  ['median', 'Médian'],
  ['bilateral', 'Bilatéral'],
  ['nlm', 'Moyennes non locales'],
  ['wiener', 'Wiener'],
  ['wavelet', 'Ondelettes'],
];

export default function CompareGrid({ denoise }) {
  const byName = new Map((denoise?.methods || []).map((method) => [method.name, method]));
  return (
    <div>
      <div className="compare-grid">
        {METHODS.map(([id, label]) => {
          const method = byName.get(id);
          return (
            <article key={id}>
              <h3>{label}</h3>
              {method?.status === 'unavailable' && (
                <p className="unit">{method.note || 'Méthode non disponible. Aucune métrique.'}</p>
              )}
              <p>PSNR <span className="num">{formatMeasurement(method?.psnrHU, { digits: 2, unit: 'dB' })}</span></p>
              <p>SSIM <span className="num">{formatMeasurement(method?.ssimMean, { digits: 3, unit: '1' })}</span></p>
              <p>Erreur de volume <span className="num">{formatRelative(method?.relErrVoxelVolume)}</span></p>
            </article>
          );
        })}
      </div>
      <ColorbarSVG
        label="Différence"
        unit="HU"
        stops={divergingStops}
        minLabel={UNMEASURED}
        maxLabel={UNMEASURED}
      />
      <Profile denoise={denoise} />
    </div>
  );
}

function Profile({ denoise }) {
  const profile = denoise?.profile;
  const first = denoise?.methods?.[0];
  if (!profile || !isMeasured(profile.positionMM) || !isMeasured(profile.referenceHU) || !isMeasured(first?.profileHU)) {
    return (
      <div className="chart-empty">
        <p>Profil d'intensité le long d'une ligne</p>
        <p className="num">{UNMEASURED}</p>
        <p className="unit">Position (mm), intensité (HU). Profil non calculé.</p>
      </div>
    );
  }
  return <ProfileSvg profile={profile} series={first.profileHU} name={first.name} />;
}

function ProfileSvg({ profile, series, name }) {
  const width = 640;
  const height = 220;
  const pad = 32;
  const xs = profile.positionMM;
  const ys = profile.referenceHU;
  const xMin = Math.min(...xs);
  const xMax = Math.max(...xs);
  const yMin = Math.min(...ys, ...series);
  const yMax = Math.max(...ys, ...series);
  const xScale = (value) => pad + ((value - xMin) / Math.max(xMax - xMin, 1e-9)) * (width - pad * 2);
  const yScale = (value) => height - pad - ((value - yMin) / Math.max(yMax - yMin, 1e-9)) * (height - pad * 2);
  const toPath = (values) => values.map((value, index) => `${index === 0 ? 'M' : 'L'} ${xScale(xs[index])} ${yScale(value)}`).join(' ');
  return (
    <div className="chart-frame">
      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Profil d'intensité en HU le long de x en mm">
        <path d={toPath(ys)} fill="none" stroke="#2f6f73" strokeWidth="2" />
        <path d={toPath(series)} fill="none" stroke="#b8502f" strokeWidth="2" />
        <text x={pad} y="16" fill="#2b2420" fontSize="12">Intensité (HU)</text>
        <text x={width - 140} y={height - 8} fill="#6d625b" fontSize="12">Position (mm)</text>
      </svg>
      <p className="unit">Pétrole : référence. Terre cuite : {name}.</p>
    </div>
  );
}
