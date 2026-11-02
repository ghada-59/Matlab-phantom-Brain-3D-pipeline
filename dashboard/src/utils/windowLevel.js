// Display presets for a CT window. They are not measurements of a volume.
export const WINDOW_PRESETS = {
  os: { width: 1800, level: 400, label: 'Os' },
  tissus: { width: 400, level: 40, label: 'Tissus mous' },
  poumon: { width: 1600, level: -600, label: 'Poumon' },
};

export function windowRange(level, width) {
  return {
    low: level - width / 2,
    high: level + width / 2,
  };
}

export function applyWindow(hu, level, width) {
  const { low, high } = windowRange(level, width);
  const span = high - low;
  if (!Number.isFinite(hu) || span === 0) {
    return 0;
  }
  return Math.min(1, Math.max(0, (hu - low) / span));
}
