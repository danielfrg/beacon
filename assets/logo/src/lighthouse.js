import * as THREE from 'three';
import { toon } from './toon.js';
import { MODEL } from './config.js';

// Tower proportions.
const BASE_Y = -2.55; // bottom of the tower
const HEIGHT = 3.6;
const R_BOTTOM = 1.06;
const R_TOP = 0.72;
const BANDS = 5; // alternating body / band colour, starting with body at the bottom

const radiusAt = (y) => R_BOTTOM + (R_TOP - R_BOTTOM) * (y - BASE_Y) / HEIGHT;

// Builds the lighthouse and returns the group plus its materials, so a
// colourway can be applied without rebuilding geometry.
export function buildLighthouse() {
  const materials = {
    body: toon(),
    band: toon(),
    trim: toon(),
    roof: toon(),
    lamp: toon({ flat: true }),
  };

  const group = new THREE.Group();
  const add = (geometry, material, x, y, z = 0) => {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    group.add(mesh);
    return mesh;
  };

  // Tower: stacked frustums.
  for (let i = 0; i < BANDS; i++) {
    const a = BASE_Y + HEIGHT * i / BANDS;
    const b = BASE_Y + HEIGHT * (i + 1) / BANDS;
    add(new THREE.CylinderGeometry(radiusAt(b), radiusAt(a), b - a, 40), i % 2 ? materials.band : materials.body, 0, (a + b) / 2);
  }

  const top = BASE_Y + HEIGHT;
  add(new THREE.CylinderGeometry(1.42, 1.5, 0.38, 40), materials.trim, 0, BASE_Y - 0.19); // base
  add(new THREE.BoxGeometry(0.38, 0.62, 0.2), materials.trim, 0, BASE_Y + 0.31, radiusAt(BASE_Y + 0.3) - 0.02); // door
  add(new THREE.CylinderGeometry(1.12, 1.0, 0.24, 40), materials.trim, 0, top + 0.12); // gallery
  add(new THREE.CylinderGeometry(0.58, 0.58, 0.86, 32), materials.lamp, 0, top + 0.67); // lantern
  for (const x of [-0.26, 0.26]) add(new THREE.BoxGeometry(0.08, 0.86, 0.08), materials.trim, x, top + 0.67, 0.54); // window bars
  add(new THREE.CylinderGeometry(0.72, 0.72, 0.13, 32), materials.trim, 0, top + 1.16); // cap
  add(new THREE.ConeGeometry(0.8, 0.78, 32), materials.roof, 0, top + 1.61); // roof
  add(new THREE.SphereGeometry(0.14, 20, 12), materials.trim, 0, top + 2.06); // knob

  group.rotation.x = MODEL.tilt;
  group.position.y = MODEL.offsetY;
  group.scale.setScalar(MODEL.scale);

  return { group, materials };
}

export function applyColourway(materials, colourway, tile) {
  materials.body.uniforms.uColor.value.set(colourway.body);
  materials.band.uniforms.uColor.value.set(colourway.band);
  materials.trim.uniforms.uColor.value.set(colourway.trim);
  materials.roof.uniforms.uColor.value.set(colourway.roof);
  materials.lamp.uniforms.uColor.value.set(tile.lamp);
}
