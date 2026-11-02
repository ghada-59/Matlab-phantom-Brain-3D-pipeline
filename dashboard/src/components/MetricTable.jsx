import { formatMeasurement, formatRelative, standardDeviation, UNMEASURED, isMeasured } from '../utils/format.js';

const ROWS = [
  { key: 'voxelVolumeMM3', label: 'Volume voxel', unit: 'mm³', digits: 1 },
  { key: 'meshVolumeMM3', label: 'Volume maillage', unit: 'mm³', digits: 1 },
  { key: 'meshAreaMM2', label: 'Aire du maillage', unit: 'mm²', digits: 1 },
  { key: 'referenceAreaMM2', label: 'Aire de référence', unit: 'mm²', digits: 1 },
  { key: 'sphericityMesh', label: 'Sphéricité maillage', unit: '1', digits: 3 },
  { key: 'sphericityVoxel', label: 'Sphéricité voxel', unit: '1', digits: 3 },
  { key: 'solidity', label: 'Solidité', unit: '1', digits: 3 },
  { key: 'relErrVoxelVolume', label: 'Erreur volume voxel', relative: true },
  { key: 'relErrMeshVolume', label: 'Erreur volume maillage', relative: true },
  { key: 'relErrArea', label: 'Erreur d’aire', relative: true },
];

export default function MetricTable({ measurements, batch = [] }) {
  const sampleCount = batch.length > 0 ? String(batch.length) : UNMEASURED;
  const volumeErrors = batch.map((row) => row.relErrVoxelVolume);
  const spread = standardDeviation(volumeErrors);

  return (
    <table className="metric-table">
      <thead>
        <tr>
          <th>Mesure</th>
          <th>Valeur</th>
        </tr>
      </thead>
      <tbody>
        {ROWS.map((row) => (
          <tr key={row.key}>
            <th scope="row">{row.label}</th>
            <td className="num">
              {row.relative
                ? formatRelative(measurements?.[row.key])
                : formatMeasurement(measurements?.[row.key], { unit: row.unit, digits: row.digits })}
            </td>
          </tr>
        ))}
        <tr>
          <th scope="row">Demi-axes estimés</th>
          <td className="num">{formatAxes(measurements?.semiAxesMM)}</td>
        </tr>
        <tr>
          <th scope="row">Demi-axes vrais</th>
          <td className="num">{formatAxes(measurements?.semiAxesTrueMM)}</td>
        </tr>
        <tr>
          <th scope="row">Écart-type du lot (erreur de volume)</th>
          <td className="num">{formatRelative(spread)}</td>
        </tr>
        <tr>
          <th scope="row">Fantômes du lot</th>
          <td className="num">{sampleCount}</td>
        </tr>
      </tbody>
    </table>
  );
}

function formatAxes(values) {
  if (!isMeasured(values) || values.length !== 3) {
    return UNMEASURED;
  }
  return values.map((value) => formatMeasurement(value, { digits: 2, unit: 'mm' })).join(' · ');
}
