// Renders the app icons with headless Chrome and writes them into the Xcode asset catalog.
//
//   pnpm export                       # default colourway from src/config.js
//   pnpm export --colourway=blue
//
// Set CHROME to the Chrome/Chromium binary if it is not in the default macOS location.
// Previews are resized with `sips`, so this script runs on macOS.
import { build, preview } from 'vite';
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtempSync, rmSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const assets = resolve(root, '../../Beacon/Assets.xcassets');
const chrome = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const colourway = process.argv.find((a) => a.startsWith('--colourway='))?.split('=')[1] || '';

// [theme, size, outputs]
const TARGETS = [
  ['light', 1024, ['AppIcon.appiconset/icon-light.png', 'AppIconLight.appiconset/icon.png']],
  ['dark', 1024, ['AppIcon.appiconset/icon-dark.png', 'AppIconDark.appiconset/icon.png']],
  ['light', 240, ['IconLight.imageset/preview.png']],
  ['dark', 240, ['IconDark.imageset/preview.png']],
  ['auto', 240, ['IconAuto.imageset/preview.png']],
];

// Build and serve the production bundle: headless Chrome never finishes against the dev server.
await build({ root, logLevel: 'error' });
const server = await preview({ root, logLevel: 'error', preview: { port: 0 } });
const { port } = server.httpServer.address();
const work = mkdtempSync(join(tmpdir(), 'beacon-icon-'));

try {
  for (const [theme, size, outputs] of TARGETS) {
    // Render at 1024 and downscale with sips; Chrome windows can't go as small as 240.
    const shot = join(work, `${theme}.png`);
    const query = new URLSearchParams({ theme, size: '1024', ...(colourway && { colourway }) });
    // Async: a sync spawn would block the event loop, and with it the preview server Chrome is loading from.
    await promisify(execFile)(chrome, [
      '--headless', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--hide-scrollbars',
      '--force-device-scale-factor=1', '--window-size=1024,1024', '--virtual-time-budget=8000',
      `--screenshot=${shot}`, `http://localhost:${port}/export.html?${query}`,
    ], { timeout: 60_000 });
    if (size !== 1024) execFileSync('sips', ['-z', String(size), String(size), shot], { stdio: 'ignore' });
    for (const out of outputs) {
      copyFileSync(shot, join(assets, out));
      console.log(`wrote ${out} (${size}px, ${theme})`);
    }
  }
} finally {
  rmSync(work, { recursive: true, force: true });
  await server.close();
}
