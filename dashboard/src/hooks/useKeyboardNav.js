import { useEffect } from 'react';

export function useKeyboardNav(enabled, handlers) {
  useEffect(() => {
    if (!enabled) {
      return undefined;
    }
    const onKeyDown = (event) => {
      const key = event.key;
      if (key === 'ArrowRight' || key === 'ArrowDown') {
        handlers.onNext?.(event);
      } else if (key === 'ArrowLeft' || key === 'ArrowUp') {
        handlers.onPrevious?.(event);
      } else if (key === 'o' || key === 'O') {
        handlers.onToggleOverlay?.(event);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [enabled, handlers]);
}
