import { useId } from 'react';
import { UNMEASURED } from '../utils/format.js';

export default function ColorbarSVG({
  unit,
  label,
  stops,
  minLabel = UNMEASURED,
  maxLabel = UNMEASURED,
}) {
  const gradientId = useId().replace(/:/g, '');
  const statedUnit = unit || UNMEASURED;
  return (
    <figure className="colorbar" aria-label={`${label} (${statedUnit})`}>
      <figcaption>
        {label} <span className="unit">({statedUnit})</span>
      </figcaption>
      <svg viewBox="0 0 220 18" role="img">
        <title>{`${label} (${statedUnit})`}</title>
        <defs>
          <linearGradient id={gradientId} x1="0" x2="1" y1="0" y2="0">
            {stops.map((color, index) => (
              <stop
                key={`${color}-${index}`}
                offset={`${(index / Math.max(stops.length - 1, 1)) * 100}%`}
                stopColor={color}
              />
            ))}
          </linearGradient>
        </defs>
        <rect x="0" y="1" width="220" height="16" fill={`url(#${gradientId})`} />
      </svg>
      <div className="colorbar-ticks">
        <span>{minLabel}</span>
        <span>{maxLabel}</span>
      </div>
    </figure>
  );
}
