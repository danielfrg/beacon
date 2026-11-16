import { createIconRenderer, drawAppIcon } from './renderer.js';
import { DEFAULT_COLOURWAY } from './config.js';

const params = new URLSearchParams(location.search);
const theme = params.get('theme') || 'light';
const size = Number(params.get('size') || 1024);
const colourway = params.get('colourway') || DEFAULT_COLOURWAY;

const canvas = document.getElementById('icon');
canvas.style.width = canvas.style.height = `${size}px`;
const icons = createIconRenderer();

function iconFor(t) {
  const c = document.createElement('canvas');
  drawAppIcon(c, icons.render(colourway, t), t, size);
  return c;
}

const ctx = canvas.getContext('2d');
canvas.width = canvas.height = size;
if (theme === 'auto') {
  // Settings preview for "Automatic": light in the top-left half, dark in the bottom-right.
  ctx.drawImage(iconFor('light'), 0, 0);
  ctx.save();
  ctx.beginPath(); ctx.moveTo(size, 0); ctx.lineTo(size, size); ctx.lineTo(0, size); ctx.closePath(); ctx.clip();
  ctx.drawImage(iconFor('dark'), 0, 0);
  ctx.restore();
} else {
  ctx.drawImage(iconFor(theme), 0, 0);
}
document.body.dataset.ready = 'true';
