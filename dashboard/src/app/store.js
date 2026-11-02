import { createContext, createElement, useContext, useEffect, useReducer } from 'react';
import { parseCsv, publicData } from '../utils/paths.js';
import { WINDOW_PRESETS } from '../utils/windowLevel.js';

const AppStateContext = createContext(null);

const initialState = {
  loadState: 'idle',
  error: null,
  status: null,
  results: null,
  validation: [],
  batch: [],
  denoise: null,
  slices: { axial: null, coronal: null, sagittal: null },
  viewer: {
    plane: 'axial',
    index: 0,
    preset: 'os',
    windowWidth: WINDOW_PRESETS.os.width,
    windowLevel: WINDOW_PRESETS.os.level,
    zoom: 1,
    pan: { x: 0, y: 0 },
    showAxes: false,
  },
};

function reducer(state, action) {
  switch (action.type) {
    case 'load-start':
      return { ...state, loadState: 'loading', error: null };
    case 'load-success':
      return { ...state, loadState: 'ready', error: null, ...action.payload };
    case 'load-error':
      return { ...state, loadState: 'error', error: action.error };
    case 'viewer':
      return { ...state, viewer: { ...state.viewer, ...action.patch } };
    default:
      return state;
  }
}

async function readOptional(url, kind) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return null;
    }
    if (kind === 'csv') {
      return parseCsv(await response.text());
    }
    return await response.json();
  } catch {
    return null;
  }
}

export function AppStateProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  useEffect(() => {
    let cancelled = false;
    dispatch({ type: 'load-start' });
    (async () => {
      try {
        const statusResponse = await fetch(publicData('status.json'));
        if (!statusResponse.ok) {
          throw new Error('status.json introuvable');
        }
        const status = await statusResponse.json();
        const results = await readOptional(publicData('results.json'), 'json');
        const usableResults = results && results.executed === true && results.version === status.version
          ? results
          : null;
        const [validation, batch, denoise] = await Promise.all([
          readOptional(publicData('validation.csv'), 'csv'),
          readOptional(publicData('batch.csv'), 'csv'),
          readOptional(publicData('denoise.json'), 'json'),
        ]);
        const slices = { axial: null, coronal: null, sagittal: null };
        if (usableResults?.sliceArrays) {
          await Promise.all(['axial', 'coronal', 'sagittal'].map(async (plane) => {
            const relative = usableResults.sliceArrays[plane];
            if (!relative) {
              return;
            }
            slices[plane] = await readOptional(publicData(relative.replace(/^slices\//, 'slices/')), 'json');
          }));
        }
        if (!cancelled) {
          const preview = usableResults?.slicePreview;
          dispatch({
            type: 'load-success',
            payload: {
              status,
              results: usableResults,
              validation: validation || [],
              batch: batch || [],
              denoise: denoise && denoise.executed === true ? denoise : null,
              slices,
              viewer: {
                ...initialState.viewer,
                windowWidth: preview?.widthHU ?? initialState.viewer.windowWidth,
                windowLevel: preview?.levelHU ?? initialState.viewer.windowLevel,
              },
            },
          });
        }
      } catch (error) {
        if (!cancelled) {
          dispatch({ type: 'load-error', error: error.message || 'Lecture impossible' });
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return createElement(AppStateContext.Provider, { value: { state, dispatch } }, children);
}

export function useAppState() {
  const context = useContext(AppStateContext);
  if (!context) {
    throw new Error('useAppState must be used inside AppStateProvider');
  }
  return context;
}
