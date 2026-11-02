export function publicData(name) {
  const base = import.meta.env.BASE_URL || './';
  return `${base}data/${name}`;
}

export function parseCsv(text) {
  if (!text || !text.trim()) {
    return [];
  }
  const lines = text.trim().split(/\r?\n/);
  const header = splitCsvLine(lines[0]);
  return lines.slice(1).filter(Boolean).map((line) => {
    const cells = splitCsvLine(line);
    const row = {};
    header.forEach((key, index) => {
      const raw = cells[index] ?? '';
      if (raw === '' || raw === 'NaN') {
        row[key] = null;
        return;
      }
      const numeric = Number(raw);
      row[key] = Number.isNaN(numeric) ? raw : numeric;
    });
    return row;
  });
}

function splitCsvLine(line) {
  return line.split(',').map((cell) => cell.trim());
}
