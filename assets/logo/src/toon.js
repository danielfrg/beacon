import * as THREE from 'three';
import { SHADE_LIGHT, SHADE_TINT, SHADE_THRESHOLD } from './config.js';

const LIGHT = new THREE.Vector3(...SHADE_LIGHT).normalize();

// Two-tone material: the full colour where a surface faces the light, a darker
// cooler tone everywhere else. `flat` skips shading (used for the lit lantern).
export function toon({ flat = false } = {}) {
  return new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color() },
      uLight: { value: LIGHT },
      uTint: { value: new THREE.Vector3(...SHADE_TINT) },
      uThreshold: { value: SHADE_THRESHOLD },
      uFlat: { value: flat ? 1 : 0 },
    },
    vertexShader: /* glsl */ `
      varying vec3 vNormal;
      void main() {
        vNormal = normalize(mat3(modelMatrix) * normal);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: /* glsl */ `
      uniform vec3 uColor;
      uniform vec3 uLight;
      uniform vec3 uTint;
      uniform float uThreshold;
      uniform float uFlat;
      varying vec3 vNormal;
      void main() {
        float d = dot(normalize(vNormal), uLight);
        vec3 shaded = uColor * uTint;
        vec3 color = (uFlat > 0.5 || d > uThreshold) ? uColor : shaded;
        gl_FragColor = vec4(color, 1.0);
      }
    `,
  });
}
