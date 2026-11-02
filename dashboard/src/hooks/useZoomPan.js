import { useEffect } from 'react';

export function useZoomPan(ref, { zoom, onZoom, onPan }) {
  useEffect(() => {
    const node = ref.current;
    if (!node) {
      return undefined;
    }
    let dragging = false;
    let lastX = 0;
    let lastY = 0;

    const onWheel = (event) => {
      if (!event.ctrlKey) {
        return;
      }
      event.preventDefault();
      const next = event.deltaY < 0 ? zoom * 1.08 : zoom / 1.08;
      onZoom(Math.min(6, Math.max(0.4, next)));
    };

    const onPointerDown = (event) => {
      if (event.button !== 0) {
        return;
      }
      dragging = true;
      lastX = event.clientX;
      lastY = event.clientY;
      node.setPointerCapture(event.pointerId);
    };

    const onPointerMove = (event) => {
      if (!dragging) {
        return;
      }
      onPan(event.clientX - lastX, event.clientY - lastY);
      lastX = event.clientX;
      lastY = event.clientY;
    };

    const onPointerUp = () => {
      dragging = false;
    };

    node.addEventListener('wheel', onWheel, { passive: false });
    node.addEventListener('pointerdown', onPointerDown);
    node.addEventListener('pointermove', onPointerMove);
    node.addEventListener('pointerup', onPointerUp);
    return () => {
      node.removeEventListener('wheel', onWheel);
      node.removeEventListener('pointerdown', onPointerDown);
      node.removeEventListener('pointermove', onPointerMove);
      node.removeEventListener('pointerup', onPointerUp);
    };
  }, [ref, zoom, onZoom, onPan]);
}
