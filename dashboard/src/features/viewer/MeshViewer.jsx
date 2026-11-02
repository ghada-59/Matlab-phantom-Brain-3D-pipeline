import { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import { formatMeasurement, isMeasured, UNMEASURED } from '../../utils/format.js';
import { publicData } from '../../utils/paths.js';

export default function MeshViewer({ results, showAxes }) {
  const hostRef = useRef(null);
  const [phase, setPhase] = useState(results?.stl ? 'loading' : 'missing');
  const [extent, setExtent] = useState(null);

  useEffect(() => {
    const host = hostRef.current;
    if (!host || !results?.stl) {
      setPhase('missing');
      setExtent(null);
      return undefined;
    }
    let disposed = false;
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#1c1916');
    const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 10000);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    const key = new THREE.DirectionalLight(0xffffff, 0.95);
    key.position.set(2, 3, 4);
    scene.add(key);
    host.appendChild(renderer.domElement);

    const resize = () => {
      const width = host.clientWidth || 640;
      const height = host.clientHeight || 420;
      renderer.setSize(width, height, false);
      camera.aspect = width / Math.max(height, 1);
      camera.updateProjectionMatrix();
    };
    resize();
    window.addEventListener('resize', resize);

    const loader = new STLLoader();
    loader.load(publicData(results.stl), (geometry) => {
      if (disposed) {
        geometry.dispose();
        return;
      }
      geometry.computeVertexNormals();
      geometry.computeBoundingBox();
      const material = new THREE.MeshStandardMaterial({
        color: '#E8DCC8',
        roughness: 0.62,
        metalness: 0.02,
      });
      const mesh = new THREE.Mesh(geometry, material);
      const center = new THREE.Vector3();
      geometry.boundingBox.getCenter(center);
      mesh.position.sub(center);
      scene.add(mesh);
      if (showAxes && hasAxes(results)) {
        scene.add(axisLines(results, center));
      }
      const size = new THREE.Vector3();
      geometry.boundingBox.getSize(size);
      setExtent([size.x, size.y, size.z]);
      const radius = Math.max(size.x, size.y, size.z, 1);
      camera.position.set(radius, radius * 0.65, radius * 1.7);
      controls.target.set(0, 0, 0);
      controls.update();
      setPhase('ready');
    }, undefined, () => {
      if (!disposed) {
        setPhase('missing');
      }
    });

    let frame = 0;
    const animate = () => {
      frame = requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    };
    animate();

    return () => {
      disposed = true;
      cancelAnimationFrame(frame);
      window.removeEventListener('resize', resize);
      controls.dispose();
      renderer.dispose();
      if (renderer.domElement.parentNode === host) {
        host.removeChild(renderer.domElement);
      }
    };
  }, [results, showAxes]);

  return (
    <div className="viewport" ref={hostRef} aria-label="Maillage 3D">
      {phase !== 'ready' && (
        <div className="empty-note">
          <p>
            {phase === 'loading'
              ? 'Chargement du STL…'
              : `Maillage non exporté. bone.stl n'a pas été produit. Étendue ${UNMEASURED}.`}
          </p>
        </div>
      )}
      {phase === 'ready' && (
        <p className="corner bl">
          Étendue (mm) {extent
            ? extent.map((value) => formatMeasurement(value, { digits: 1 })).join(' × ')
            : UNMEASURED}
        </p>
      )}
    </div>
  );
}

function hasAxes(results) {
  const directions = results.axisDirections;
  const lengths = results.measurements?.semiAxesMM;
  return Array.isArray(directions)
    && directions.length === 3
    && directions.every((row) => Array.isArray(row) && row.length === 3 && row.every(isMeasured))
    && isMeasured(lengths);
}

function axisLines(results, bboxCenter) {
  const group = new THREE.Group();
  const lengths = results.measurements.semiAxesMM;
  const directions = results.axisDirections;
  const centroid = results.centroidMM;
  const origin = isMeasured(centroid)
    ? new THREE.Vector3(centroid[0], centroid[1], centroid[2]).sub(bboxCenter)
    : new THREE.Vector3();
  const material = new THREE.LineBasicMaterial({ color: '#B8502F' });
  for (let axis = 0; axis < 3; axis += 1) {
    const direction = new THREE.Vector3(directions[0][axis], directions[1][axis], directions[2][axis]);
    if (direction.lengthSq() === 0) {
      continue;
    }
    direction.normalize();
    const offset = direction.multiplyScalar(lengths[axis]);
    const geometry = new THREE.BufferGeometry().setFromPoints([
      origin.clone().sub(offset),
      origin.clone().add(offset),
    ]);
    group.add(new THREE.Line(geometry, material));
  }
  return group;
}
