import { useLayoutEffect, useRef } from 'react';
import { useAppState } from '../../app/store.js';
import { applyWindow, windowRange } from '../../utils/windowLevel.js';
import { formatMeasurement, UNMEASURED } from '../../utils/format.js';
import { useDebounce } from '../../hooks/useDebounce.js';
import { useKeyboardNav } from '../../hooks/useKeyboardNav.js';
import { useZoomPan } from '../../hooks/useZoomPan.js';
import ColorbarSVG from '../../components/ColorbarSVG.jsx';
import { grayStops } from '../../utils/colormaps.js';

const LETTERS = {
  axial: { n: 'A', s: 'P', w: 'R', e: 'L' },
  coronal: { n: 'S', s: 'I', w: 'R', e: 'L' },
  sagittal: { n: 'S', s: 'I', w: 'A', e: 'P' },
};

export default function MprViewer() {
  const { state, dispatch } = useAppState();
  const hostRef = useRef(null);
  const canvasRef = useRef(null);
  const { viewer, slices, results } = state;
  const slice = slices[viewer.plane];
  const drawLevel = useDebounce(viewer.windowLevel, 80);
  const drawWidth = useDebounce(viewer.windowWidth, 80);
  const range = windowRange(drawLevel, drawWidth);

  useKeyboardNav(true, {
    onNext: () => step(1),
    onPrevious: () => step(-1),
  });

  useZoomPan(hostRef, {
    zoom: viewer.zoom,
    onZoom: (zoom) => dispatch({ type: 'viewer', patch: { zoom } }),
    onPan: (dx, dy) => dispatch({
      type: 'viewer',
      patch: { pan: { x: viewer.pan.x + dx, y: viewer.pan.y + dy } },
    }),
  });

  useLayoutEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) {
      return undefined;
    }
    const context = canvas.getContext('2d');
    const width = host.clientWidth || 640;
    const height = host.clientHeight || 420;
    canvas.width = width;
    canvas.height = height;
    context.fillStyle = '#1c1916';
    context.fillRect(0, 0, width, height);
    if (!slice?.hu || !slice.rows || !slice.cols) {
      return undefined;
    }
    const image = context.createImageData(slice.cols, slice.rows);
    for (let index = 0; index < slice.hu.length; index += 1) {
      const gray = Math.round(applyWindow(slice.hu[index], drawLevel, drawWidth) * 255);
      const offset = index * 4;
      image.data[offset] = gray;
      image.data[offset + 1] = gray;
      image.data[offset + 2] = gray;
      image.data[offset + 3] = 255;
    }
    const offscreen = document.createElement('canvas');
    offscreen.width = slice.cols;
    offscreen.height = slice.rows;
    offscreen.getContext('2d').putImageData(image, 0, 0);
    const scale = Math.min(width / slice.cols, height / slice.rows) * viewer.zoom;
    const drawW = slice.cols * scale;
    const drawH = slice.rows * scale;
    context.imageSmoothingEnabled = false;
    context.drawImage(
      offscreen,
      (width - drawW) / 2 + viewer.pan.x,
      (height - drawH) / 2 + viewer.pan.y,
      drawW,
      drawH,
    );
    return undefined;
  }, [slice, drawLevel, drawWidth, viewer.zoom, viewer.pan]);

  function step(delta) {
    const order = ['axial', 'coronal', 'sagittal'];
    const current = Math.max(0, order.indexOf(viewer.plane));
    const next = order[(current + delta + order.length) % order.length];
    dispatch({ type: 'viewer', patch: { plane: next } });
  }

  const letters = LETTERS[viewer.plane];
  const spacing = results?.spacingMM;
  const thickness = Array.isArray(spacing) ? spacing[2] : null;
  const indexLabel = slice ? `${slice.index} / ${slice.count}` : UNMEASURED;

  return (
    <div>
      <div className="toolbar">
        {['axial', 'coronal', 'sagittal'].map((plane) => (
          <button
            key={plane}
            type="button"
            aria-pressed={viewer.plane === plane}
            onClick={() => dispatch({ type: 'viewer', patch: { plane } })}
          >
            {plane}
          </button>
        ))}
      </div>
      <div
        className="viewport"
        ref={hostRef}
        onContextMenu={(event) => event.preventDefault()}
        tabIndex={0}
        aria-label="Coupe CT"
      >
        <canvas ref={canvasRef} />
        {!slice && (
          <div className="empty-note">
            <p>Aucune coupe exportée. Les mesures restent « {UNMEASURED} ».</p>
          </div>
        )}
        <p className="corner tl">
          Fenêtre / niveau (HU), affichage
          <br />
          {formatMeasurement(viewer.windowWidth, { digits: 0 })} / {formatMeasurement(viewer.windowLevel, { digits: 0 })}
        </p>
        <p className="corner tr">
          Coupe {indexLabel}
          <br />
          Épaisseur {formatMeasurement(thickness, { digits: 2, unit: 'mm' })}
        </p>
        <p className="corner bl">Zoom {formatMeasurement(viewer.zoom, { digits: 2, unit: '×' })}</p>
        <p className="corner br">{scaleLabel(slice)}</p>
        <span className="orient n">{letters.n}</span>
        <span className="orient s">{letters.s}</span>
        <span className="orient w">{letters.w}</span>
        <span className="orient e">{letters.e}</span>
      </div>
      <ColorbarSVG
        label="Échelle d'affichage"
        unit="HU"
        stops={grayStops}
        minLabel={formatMeasurement(range.low, { digits: 0 })}
        maxLabel={formatMeasurement(range.high, { digits: 0 })}
      />
    </div>
  );
}

function scaleLabel(slice) {
  if (!slice?.spacingMM || slice.spacingMM.length < 2) {
    return `Échelle ${UNMEASURED}`;
  }
  return `Échelle ${formatMeasurement(slice.spacingMM[1], { digits: 2, unit: 'mm/colonne' })}`;
}
