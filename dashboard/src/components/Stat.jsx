import { formatMeasurement, UNMEASURED } from '../utils/format.js';

export default function Stat({ label, value, unit = '', digits = 2 }) {
  return (
    <div>
      <div className="unit">{label}</div>
      <div className="metric-value">{formatMeasurement(value, { unit, digits })}</div>
    </div>
  );
}

export function PlainStat({ label, text }) {
  return (
    <div>
      <div className="unit">{label}</div>
      <div className="metric-value">{text || UNMEASURED}</div>
    </div>
  );
}
