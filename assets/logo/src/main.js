import './style.css';
import { createIconRenderer, drawTile } from './renderer.js';
import { COLOURWAYS, DEFAULT_COLOURWAY } from './config.js';

const THEMES = ['light', 'dark'];

const hero = document.getElementById('hero');
hero.innerHTML = THEMES.map((t) => `
  <figure>
    <canvas id="hero-${t}" class="hero-icon" aria-label="${COLOURWAYS[DEFAULT_COLOURWAY].name} icon, ${t}"></canvas>
    <figcaption>${t === 'light' ? 'Light · cream tile' : 'Dark · night tile'}</figcaption>
  </figure>`).join('');

const grid = document.getElementById('grid');
grid.innerHTML = Object.entries(COLOURWAYS).map(([key, c]) => `
  <article class="card">
    <h3>${c.name}</h3>
    <p class="note">${c.note}</p>
    <div class="pair">
      ${THEMES.map((t) => `<canvas data-way="${key}" data-theme="${t}" data-size="160"></canvas>`).join('')}
    </div>
    <div class="homes">
      ${THEMES.map((t) => `<div class="home ${t}">
        <canvas data-way="${key}" data-theme="${t}" data-size="56" style="width:56px;height:56px"></canvas>
        <canvas data-way="${key}" data-theme="${t}" data-size="38" style="width:38px;height:38px"></canvas>
      </div>`).join('')}
    </div>
  </article>`).join('');

const icons = createIconRenderer();

function renderAll() {
  for (const way of Object.keys(COLOURWAYS)) {
    for (const theme of THEMES) {
      const model = icons.render(way, theme);
      document.querySelectorAll(`canvas[data-way="${way}"][data-theme="${theme}"]`)
        .forEach((c) => drawTile(c, model, theme, +c.dataset.size));
      if (way === DEFAULT_COLOURWAY) drawTile(document.getElementById(`hero-${theme}`), model, theme, 340);
    }
  }
}

renderAll();

// Re-render in place when config or model files change during `npm run dev`.
if (import.meta.hot) import.meta.hot.accept(() => location.reload());
