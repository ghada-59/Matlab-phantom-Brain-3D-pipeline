// Sequential and diverging ramps used by the scientific views.
// CT slices stay grayscale. These ramps are not a rainbow scale.

export const sequentialStops = ['#FAF6EF', '#7FA3A1', '#2F6F73'];
export const divergingStops = ['#2166AC', '#F7F4EF', '#B2182B'];
export const grayStops = ['#141210', '#F4F1EA'];

export function cssGradient(stops) {
  return `linear-gradient(to right, ${stops.join(', ')})`;
}
