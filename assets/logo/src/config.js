// Everything you are likely to tune lives here: colours, tile, light, framing.

// Icon tiles. `face` is the top of the slab, `side` its visible bottom edge,
// `shadow` is the colour and opacity of the cast shadow over the face.
export const TILES = {
  light: { face: '#ebe4da', side: '#dfd3c1', shadow: ['#b89c74', 0.24], lamp: '#fbb300' },
  dark: { face: '#232a3d', side: '#171c2b', shadow: ['#05070d', 0.38], lamp: '#ffc21a' },
};

// Colourways for the lighthouse itself.
export const COLOURWAYS = {
  coral: { name: 'Coral', note: 'Red and white stripes, navy trim. The classic.', body: '#ffffff', band: '#f25b4f', trim: '#24365c', roof: '#f25b4f' },
  blue: { name: 'Blue', note: 'A saturated blue with white bands and a yellow lamp.', body: '#ffffff', band: '#168fd3', trim: '#0e5f99', roof: '#168fd3' },
  lilac: { name: 'Lilac', note: 'Soft lavender tower, deeper violet trim. Quietest of the three.', body: '#c7a9ee', band: '#ffffff', trim: '#6c4bb5', roof: '#9a76e0' },
};

export const DEFAULT_COLOURWAY = 'coral';

// Shading light: decides which faces are lit and which take the darker tone.
export const SHADE_LIGHT = [2.2, 3.0, 5];
// How dark the shaded side is, as a multiplier per channel (slightly cool).
export const SHADE_TINT = [0.8, 0.83, 0.9];
// Faces whose normal·light is above this are lit; below it they are shaded.
export const SHADE_THRESHOLD = 0.42;

// Shadow light: steeper than the shading light so the cast shadow is a short offset down-left.
export const SHADOW_LIGHT = [1.3, 1.7, 5];
// Distance of the invisible shadow-catching plane behind the model.
export const SHADOW_PLANE_Z = -1.35;

// Framing.
export const MODEL = {
  tilt: 0.16, // radians forward, so the tops of the rings show
  scale: 1.08,
  offsetY: -0.15,
};

// Tile geometry as fractions of the icon size.
export const TILE_SHAPE = {
  radius: 0.2237, // iOS-like corner radius
  depth: 0, // visible slab edge at the bottom (0 = flat tile; try 0.055 for a thick slab)
};

export const RENDER_SIZE = 1024;
