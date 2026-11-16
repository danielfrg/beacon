# Beacon logo

The app icon is a small three.js model of a lighthouse, rendered with a flat
two-tone shader and a hard shadow onto a cream (light) or navy (dark) tile.

```sh
pnpm install
pnpm dev         # preview page with every colourway, light and dark
pnpm export      # render the app icons into ../../Beacon/Assets.xcassets
```

`pnpm export` renders `export.html` in headless Chrome (set `CHROME` if it
isn't in the default macOS location) and writes the 1024px icons for
`AppIcon` (light and dark), `AppIconLight` and `AppIconDark`, plus the 240px
Settings previews (`IconLight`, `IconDark`, and the diagonal split for
`IconAuto`). Pass `--colourway=blue` to export another colourway.

## Where things are

- `src/config.js`: colours, tiles, light direction, shadow and framing. Most tuning happens here.
- `src/lighthouse.js`: the model (tower bands, base, door, gallery, lantern, roof).
- `src/toon.js`: the two-tone shader (lit colour vs. a darker, cooler tone).
- `src/renderer.js`: the offscreen three.js renderer and the 2D tile compositing.
- `src/main.js`: the preview page.
- `src/export.js`, `export.html`, `scripts/export.mjs`: the icon export.
