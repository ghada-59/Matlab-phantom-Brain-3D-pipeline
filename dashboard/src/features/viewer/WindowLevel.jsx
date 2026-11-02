import { WINDOW_PRESETS, windowRange } from '../../utils/windowLevel.js';
import { formatMeasurement } from '../../utils/format.js';

export default function WindowLevel({ preset, level, width, onChange }) {
  const range = windowRange(level, width);
  return (
    <div className="toolbar" aria-label="Fenêtre et niveau, préréglages d'affichage">
      <span className="unit">Préréglage d'affichage, pas une mesure</span>
      {Object.entries(WINDOW_PRESETS).map(([key, item]) => (
        <button
          key={key}
          type="button"
          aria-pressed={preset === key}
          onClick={() => onChange({
            preset: key,
            windowWidth: item.width,
            windowLevel: item.level,
          })}
        >
          {item.label}
        </button>
      ))}
      <label>
        Largeur (HU)
        <input
          type="range"
          min="1"
          max="4000"
          value={width}
          aria-valuetext={formatMeasurement(width, { digits: 0, unit: 'HU' })}
          onChange={(event) => onChange({
            preset: 'manuel',
            windowWidth: Number(event.target.value),
          })}
        />
      </label>
      <label>
        Niveau (HU)
        <input
          type="range"
          min="-1000"
          max="2000"
          value={level}
          aria-valuetext={formatMeasurement(level, { digits: 0, unit: 'HU' })}
          onChange={(event) => onChange({
            preset: 'manuel',
            windowLevel: Number(event.target.value),
          })}
        />
      </label>
      <span className="num unit">
        {formatMeasurement(range.low, { digits: 0 })} → {formatMeasurement(range.high, { digits: 0, unit: 'HU' })}
      </span>
    </div>
  );
}
