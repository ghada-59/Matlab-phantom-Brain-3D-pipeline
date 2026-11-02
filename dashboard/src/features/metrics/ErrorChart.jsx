import { isMeasured, UNMEASURED, formatRelative } from '../../utils/format.js';

export default function ErrorChart({ rows }) {
  const points = (rows || []).filter((row) => (
    row.rotationDeg === 0
    && isMeasured(row.voxelSizeMM)
    && isMeasured(row.relErrVoxelVolume)
  ));
  if (points.length === 0) {
    return (
      <div className="chart-empty">
        <p>Erreur de volume selon la résolution</p>
        <p className="num">{UNMEASURED}</p>
        <p className="unit">Aucun point. validation.csv n'a pas été produit.</p>
      </div>
    );
  }

  const grouped = new Map();
  points.forEach((row) => {
    const list = grouped.get(row.voxelSizeMM) || [];
    list.push(row.relErrVoxelVolume);
    grouped.set(row.voxelSizeMM, list);
  });
  const series = [...grouped.entries()]
    .map(([size, values]) => ({
      size,
      mean: values.reduce((sum, value) => sum + value, 0) / values.length,
      low: Math.min(...values),
      high: Math.max(...values),
    }))
    .sort((a, b) => a.size - b.size);

  const width = 640;
  const height = 240;
  const pad = 36;
  const sizes = series.map((item) => Math.log(item.size));
  const errors = series.flatMap((item) => [item.low, item.high, item.mean]);
  const xMin = Math.min(...sizes);
  const xMax = Math.max(...sizes);
  const yMin = Math.min(0, ...errors);
  const yMax = Math.max(0, ...errors);
  const xScale = (size) => pad + ((Math.log(size) - xMin) / Math.max(xMax - xMin, 1e-9)) * (width - pad * 2);
  const yScale = (value) => height - pad - ((value - yMin) / Math.max(yMax - yMin, 1e-9)) * (height - pad * 2);
  const path = series.map((item, index) => `${index === 0 ? 'M' : 'L'} ${xScale(item.size)} ${yScale(item.mean)}`).join(' ');

  return (
    <div className="chart-frame">
      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Erreur relative de volume selon la taille de voxel, en mm">
        <line x1={pad} y1={yScale(0)} x2={width - pad} y2={yScale(0)} stroke="#e4d8c8" />
        <path d={path} fill="none" stroke="#b8502f" strokeWidth="2" />
        {series.map((item) => (
          <g key={item.size}>
            <line
              x1={xScale(item.size)}
              x2={xScale(item.size)}
              y1={yScale(item.low)}
              y2={yScale(item.high)}
              stroke="#2f6f73"
            />
            <circle cx={xScale(item.size)} cy={yScale(item.mean)} r="4" fill="#b8502f" />
          </g>
        ))}
        <text x={pad} y="16" fill="#2b2420" fontSize="12">Erreur relative de volume (1)</text>
        <text x={width - 150} y={height - 8} fill="#6d625b" fontSize="12">Taille de voxel (mm), échelle log</text>
      </svg>
      <p className="unit">
        Moyenne au plus fin voxel exporté : {formatRelative(series[0]?.mean)}
      </p>
    </div>
  );
}
