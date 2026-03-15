"use client";

import { useRef, useMemo, useState } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Text } from "@react-three/drei";
import * as THREE from "three";
import { getCountryPosition, generateArc, COUNTRY_COORDS } from "@/lib/geo";

// --- Types ---
interface GlobeNode {
  id: string;
  type: "sovereign" | "org" | "lead";
  label: string;
  country: string;
  tier: string;
  agents?: number;
}

interface GlobeConnection {
  from: string;
  to: string;
  type: "mesh" | "outreach";
  strength: number;
}

interface GlobeData {
  nodes: GlobeNode[];
  connections: GlobeConnection[];
}

// --- Constants ---
const GLOBE_RADIUS = 1.6;
const NODE_COLORS: Record<string, string> = {
  sovereign: "#00ff41",
  org: "#00aaff",
  lead: "#ffaa00",
  prospect: "#ff6600",
};
const TIER_COLORS: Record<string, string> = {
  sovereign: "#00ff41",
  fully_verified: "#00ff41",
  registry_verified: "#00aaff",
  domain_verified: "#ffff00",
  unverified: "#666666",
  prospect: "#ff6600",
};

// --- Globe wireframe sphere ---
function GlobeMesh() {
  const meshRef = useRef<THREE.Mesh>(null);

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta * 0.02;
    }
  });

  return (
    <mesh ref={meshRef}>
      <sphereGeometry args={[GLOBE_RADIUS, 48, 48]} />
      <meshBasicMaterial
        color="#0a0a0a"
        wireframe={false}
        transparent
        opacity={0.9}
      />
      {/* Wireframe overlay */}
      <mesh>
        <sphereGeometry args={[GLOBE_RADIUS + 0.002, 24, 24]} />
        <meshBasicMaterial
          color="#1a1a1a"
          wireframe
          transparent
          opacity={0.3}
        />
      </mesh>
      {/* Latitude/longitude grid */}
      <mesh>
        <sphereGeometry args={[GLOBE_RADIUS + 0.004, 36, 18]} />
        <meshBasicMaterial
          color="#222222"
          wireframe
          transparent
          opacity={0.15}
        />
      </mesh>
    </mesh>
  );
}

// --- Atmosphere glow ---
function Atmosphere() {
  return (
    <mesh>
      <sphereGeometry args={[GLOBE_RADIUS + 0.08, 48, 48]} />
      <meshBasicMaterial
        color="#00ff41"
        transparent
        opacity={0.03}
        side={THREE.BackSide}
      />
    </mesh>
  );
}

// --- Node point on globe ---
function NodePoint({
  node,
  onClick,
}: {
  node: GlobeNode;
  onClick: (n: GlobeNode) => void;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const position = useMemo(
    () => getCountryPosition(node.country, GLOBE_RADIUS + 0.01),
    [node.country]
  );

  const color = TIER_COLORS[node.tier] || NODE_COLORS[node.type] || "#ffffff";
  const size = node.type === "sovereign" ? 0.04 : node.type === "org" ? 0.025 : 0.015;

  useFrame((state) => {
    if (meshRef.current) {
      const scale = 1 + Math.sin(state.clock.elapsedTime * 2 + position[0] * 10) * 0.15;
      meshRef.current.scale.setScalar(scale);
    }
  });

  return (
    <group position={position}>
      {/* Glow ring */}
      <mesh>
        <ringGeometry args={[size * 1.5, size * 2.5, 16]} />
        <meshBasicMaterial
          color={color}
          transparent
          opacity={0.2}
          side={THREE.DoubleSide}
        />
      </mesh>
      {/* Core point */}
      <mesh
        ref={meshRef}
        onClick={() => onClick(node)}
        onPointerOver={(e) => {
          e.stopPropagation();
          document.body.style.cursor = "pointer";
        }}
        onPointerOut={() => {
          document.body.style.cursor = "default";
        }}
      >
        <sphereGeometry args={[size, 8, 8]} />
        <meshBasicMaterial color={color} />
      </mesh>
    </group>
  );
}

// --- Arc connection between two nodes ---
function ArcConnection({
  from,
  to,
  connection,
}: {
  from: GlobeNode;
  to: GlobeNode;
  connection: GlobeConnection;
}) {
  const lineRef = useRef<THREE.Line>(null);
  const startPos = useMemo(
    () => getCountryPosition(from.country, GLOBE_RADIUS + 0.01),
    [from.country]
  );
  const endPos = useMemo(
    () => getCountryPosition(to.country, GLOBE_RADIUS + 0.01),
    [to.country]
  );

  const arcPoints = useMemo(
    () => generateArc(startPos, endPos, 64, 0.2 + connection.strength * 0.3),
    [startPos, endPos, connection.strength]
  );

  const geometry = useMemo(() => {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(arcPoints, 3));
    return geo;
  }, [arcPoints]);

  const color = connection.type === "mesh" ? "#00ff41" : "#ff6600";
  const opacity = 0.15 + connection.strength * 0.4;

  useFrame((state) => {
    if (lineRef.current) {
      const mat = lineRef.current.material as THREE.LineBasicMaterial;
      mat.opacity = opacity + Math.sin(state.clock.elapsedTime * 1.5) * 0.1;
    }
  });

  return (
    <line ref={lineRef} geometry={geometry}>
      <lineBasicMaterial color={color} transparent opacity={opacity} />
    </line>
  );
}

// --- Pulse ring at sovereign location ---
function SovereignPulse({ country }: { country: string }) {
  const ringRef = useRef<THREE.Mesh>(null);
  const position = useMemo(
    () => getCountryPosition(country, GLOBE_RADIUS + 0.015),
    [country]
  );

  useFrame((state) => {
    if (ringRef.current) {
      const t = (state.clock.elapsedTime % 2) / 2;
      ringRef.current.scale.setScalar(1 + t * 3);
      const mat = ringRef.current.material as THREE.MeshBasicMaterial;
      mat.opacity = 0.4 * (1 - t);
    }
  });

  return (
    <mesh ref={ringRef} position={position}>
      <ringGeometry args={[0.04, 0.06, 32]} />
      <meshBasicMaterial
        color="#00ff41"
        transparent
        opacity={0.4}
        side={THREE.DoubleSide}
      />
    </mesh>
  );
}

// --- Country dot markers (background reference) ---
function CountryDots() {
  const dots = useMemo(() => {
    return Object.entries(COUNTRY_COORDS).map(([code, [lat, lng]]) => ({
      code,
      position: getCountryPosition(code, GLOBE_RADIUS + 0.005),
    }));
  }, []);

  return (
    <>
      {dots.map((dot) => (
        <mesh key={dot.code} position={dot.position}>
          <sphereGeometry args={[0.006, 4, 4]} />
          <meshBasicMaterial color="#1a3a1a" transparent opacity={0.4} />
        </mesh>
      ))}
    </>
  );
}

// --- Main scene ---
function GlobeScene({
  data,
  onNodeSelect,
}: {
  data: GlobeData;
  onNodeSelect: (n: GlobeNode | null) => void;
}) {
  const nodeMap = useMemo(() => {
    const map = new Map<string, GlobeNode>();
    for (const n of data.nodes) map.set(n.id, n);
    return map;
  }, [data.nodes]);

  const sovereign = data.nodes.find((n) => n.type === "sovereign");

  return (
    <>
      <ambientLight intensity={0.1} />
      <pointLight position={[5, 5, 5]} intensity={0.3} color="#00ff41" />

      <GlobeMesh />
      <Atmosphere />
      <CountryDots />

      {sovereign && <SovereignPulse country={sovereign.country} />}

      {data.nodes.map((node) => (
        <NodePoint key={node.id} node={node} onClick={onNodeSelect} />
      ))}

      {data.connections.map((conn, i) => {
        const fromNode = nodeMap.get(conn.from);
        const toNode = nodeMap.get(conn.to);
        if (!fromNode || !toNode) return null;
        if (fromNode.country === toNode.country) return null;
        return (
          <ArcConnection
            key={`${conn.from}-${conn.to}-${i}`}
            from={fromNode}
            to={toNode}
            connection={conn}
          />
        );
      })}

      <OrbitControls
        enablePan={false}
        minDistance={2.5}
        maxDistance={6}
        autoRotate
        autoRotateSpeed={0.3}
        enableDamping
        dampingFactor={0.05}
      />
    </>
  );
}

// --- Exported component ---
export default function PlanetaryGlobe({ data }: { data: GlobeData }) {
  const [selected, setSelected] = useState<GlobeNode | null>(null);

  return (
    <div className="relative w-full h-full">
      <Canvas
        camera={{ position: [0, 0, 4], fov: 45 }}
        style={{ background: "black" }}
        gl={{ antialias: true, alpha: true }}
      >
        <GlobeScene data={data} onNodeSelect={setSelected} />
      </Canvas>

      {/* HUD overlay */}
      <div className="absolute top-4 left-4 pointer-events-none">
        <h2 className="text-terminal text-xs font-bold uppercase tracking-widest">
          Planetary Outreach
        </h2>
        <div className="mt-2 space-y-1 text-[10px] opacity-50">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-terminal" />
            Sovereign / Verified
          </div>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-blue-400" />
            Registry Verified
          </div>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-orange-400" />
            Prospects / Leads
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="absolute top-4 right-4 pointer-events-none text-right">
        <div className="text-[10px] opacity-50 uppercase space-y-1">
          <div>
            Nodes:{" "}
            <span className="text-terminal font-bold">{data.nodes.length}</span>
          </div>
          <div>
            Connections:{" "}
            <span className="text-terminal font-bold">
              {data.connections.length}
            </span>
          </div>
        </div>
      </div>

      {/* Selected node info */}
      {selected && (
        <div className="absolute bottom-4 left-4 border-2 border-white/30 bg-black/90 p-4 max-w-xs pointer-events-auto">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="text-sm font-bold uppercase">{selected.label}</h3>
              <p className="text-[10px] opacity-50 uppercase mt-1">
                {selected.country} // {selected.type} // {selected.tier}
              </p>
              {selected.agents !== undefined && selected.agents > 0 && (
                <p className="text-[10px] text-terminal mt-1">
                  {selected.agents} agent{selected.agents !== 1 ? "s" : ""}
                </p>
              )}
            </div>
            <button
              onClick={() => setSelected(null)}
              className="text-xs opacity-50 hover:opacity-100"
            >
              [X]
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
