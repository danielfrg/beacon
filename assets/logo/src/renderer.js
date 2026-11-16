import * as THREE from 'three';
import { buildLighthouse, applyColourway } from './lighthouse.js';
import { COLOURWAYS, TILES, SHADOW_LIGHT, SHADOW_PLANE_Z, RENDER_SIZE, TILE_SHAPE } from './config.js';

THREE.ColorManagement.enabled = false; // hex in = hex out, so flat colours stay exact

// One offscreen renderer that draws the model (with its cast shadow) on a
// transparent background. The tile itself is drawn in 2D by `drawTile`.
export function createIconRenderer(size = RENDER_SIZE) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(size, size, false);
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.setClearColor(0x000000, 0);

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-5, 5, 5, -5, 0.1, 50);
  camera.position.set(0, 0, 20);
  camera.lookAt(0, 0, 0);

  const sun = new THREE.DirectionalLight(0xffffff, 1);
  sun.position.copy(new THREE.Vector3(...SHADOW_LIGHT).normalize().multiplyScalar(15));
  sun.castShadow = true;
  Object.assign(sun.shadow.camera, { left: -8, right: 8, top: 8, bottom: -8, near: 1, far: 40 });
  sun.shadow.mapSize.set(4096, 4096);
  sun.shadow.bias = -0.0005;
  scene.add(sun, sun.target);

  // Invisible plane behind the model that only shows the shadow.
  const catcher = new THREE.Mesh(new THREE.PlaneGeometry(30, 30), new THREE.ShadowMaterial());
  catcher.position.z = SHADOW_PLANE_Z;
  catcher.receiveShadow = true;
  scene.add(catcher);

  const { group, materials } = buildLighthouse();
  scene.add(group);

  // Returns a 2D canvas with the model render for this colourway and theme.
  function render(colourwayKey, theme) {
    const tile = TILES[theme];
    applyColourway(materials, COLOURWAYS[colourwayKey], tile);
    catcher.material.color.set(tile.shadow[0]);
    catcher.material.opacity = tile.shadow[1];
    renderer.render(scene, camera);
    const out = document.createElement('canvas');
    out.width = out.height = size;
    out.getContext('2d').drawImage(renderer.domElement, 0, 0);
    return out;
  }

  return { render, scene, camera, renderer };
}

// Draws the slab (bottom edge in `side`, face on top) and the model clipped to the face.
export function drawTile(canvas, modelCanvas, theme, cssSize, { slab = true } = {}) {
  const tile = TILES[theme];
  const px = Math.round(cssSize * Math.min(3, window.devicePixelRatio || 1));
  canvas.width = canvas.height = px;
  const ctx = canvas.getContext('2d');
  const radius = px * TILE_SHAPE.radius;
  const depth = Math.round(px * TILE_SHAPE.depth);
  slab = slab && depth > 0;
  const faceSize = px - depth;

  ctx.clearRect(0, 0, px, px);
  if (slab) {
    ctx.fillStyle = tile.side;
    ctx.beginPath(); ctx.roundRect(0, 0, px, px, radius); ctx.fill();
  }
  ctx.save();
  ctx.fillStyle = tile.face;
  ctx.beginPath(); ctx.roundRect(0, 0, px, faceSize, radius); ctx.fill(); ctx.clip();
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(downscale(modelCanvas, faceSize), (px - faceSize) / 2, 0, faceSize, faceSize);
  ctx.restore();
}

// Full-bleed square for the real app icon (iOS applies its own corner mask, so
// the square has no transparency). If TILE_SHAPE.depth is set, a slab edge sits
// along the bottom with rounded corners that line up with the iOS mask.
export function drawAppIcon(canvas, modelCanvas, theme, px) {
  const tile = TILES[theme];
  canvas.width = canvas.height = px;
  const ctx = canvas.getContext('2d');
  const radius = px * TILE_SHAPE.radius;
  const depth = Math.round(px * TILE_SHAPE.depth);
  const faceSize = px - depth;

  ctx.fillStyle = tile.face;
  ctx.fillRect(0, 0, px, px);
  if (depth > 0) {
    ctx.fillStyle = tile.side;
    ctx.fillRect(0, px / 2, px, px / 2);
    ctx.fillStyle = tile.face;
    ctx.beginPath(); ctx.roundRect(0, 0, px, faceSize, radius); ctx.fill();
  }
  ctx.save();
  ctx.beginPath(); ctx.rect(0, 0, px, faceSize); ctx.clip();
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(downscale(modelCanvas, faceSize), (px - faceSize) / 2, 0, faceSize, faceSize);
  ctx.restore();
}

// Halve in steps for a clean downscale.
function downscale(src, target) {
  let s = src;
  while (s.width / 2 >= target) {
    const c = document.createElement('canvas');
    c.width = c.height = s.width / 2;
    const cx = c.getContext('2d');
    cx.imageSmoothingQuality = 'high';
    cx.drawImage(s, 0, 0, c.width, c.height);
    s = c;
  }
  return s;
}
