// Repeatability probe: differences were confined to emoji raster edges, with a
// maximum RGB channel delta of 9/255. Use a small perceptual threshold; allow no
// pixels above it. pixel-controls/ proves both noise acceptance and change detection.
export const visualPolicy = {
  animations: 'disabled', caret: 'hide', threshold: 0.04, maxDiffPixels: 0,
};
