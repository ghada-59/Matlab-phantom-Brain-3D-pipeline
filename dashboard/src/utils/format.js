// U+2014 EM DASH. The MATLAB helper unmeasuredSentinel returns the same character.
export const UNMEASURED = '\u2014';

export function isMeasured(value) {
  if (value === null || value === undefined || value === '') {
    return false;
  }
  if (typeof value === 'number') {
    return Number.isFinite(value);
  }
  if (Array.isArray(value)) {
    return value.length > 0 && value.every((item) => isMeasured(item));
  }
  return true;
}

export function formatMeasurement(value, options = {}) {
  const { digits = 2, unit = '' } = options;
  if (!isMeasured(value)) {
    return UNMEASURED;
  }
  if (typeof value !== 'number') {
    return String(value);
  }
  const formatted = new Intl.NumberFormat('fr-FR', {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits,
  }).format(value);
  return unit ? `${formatted} ${unit}` : formatted;
}

export function formatRelative(value) {
  if (!isMeasured(value)) {
    return UNMEASURED;
  }
  return new Intl.NumberFormat('fr-FR', {
    style: 'percent',
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(value);
}

export function standardDeviation(values) {
  const series = (values || []).filter((value) => typeof value === 'number' && Number.isFinite(value));
  if (series.length < 2) {
    return null;
  }
  const mean = series.reduce((sum, value) => sum + value, 0) / series.length;
  const variance = series.reduce((sum, value) => sum + (value - mean) ** 2, 0) / (series.length - 1);
  return Math.sqrt(variance);
}
