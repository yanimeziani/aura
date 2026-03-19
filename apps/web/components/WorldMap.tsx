'use client';

import React, { useEffect, useRef, useState } from 'react';

interface Region {
  id: string;
  owner_id: string;
  level: number;
  resources: number;
  fog_level: number;
  last_updated: number;
}

interface Delta {
  type: 'delta';
  region_id: string;
  field: string;
  old: string;
  new: string;
}

export default function WorldMap() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [regions, setRegions] = useState<Record<string, Region>>({});
  const [zoom, setZoom] = useState(1);

  useEffect(() => {
    // Initial State
    fetch('/api/world/state')
      .then((res) => res.json())
      .then((data) => {
        const mapped = data.regions.reduce((acc: any, r: Region) => {
          acc[r.id] = r;
          return acc;
        }, {});
        setRegions(mapped);
      });

    // SSE Stream
    const eventSource = new EventSource('/api/world/stream');
    eventSource.onmessage = (event) => {
      const delta: Delta = JSON.parse(event.data);
      if (delta.type === 'delta') {
        setRegions((prev) => ({
          ...prev,
          [delta.region_id]: {
            ...prev[delta.region_id],
            [delta.field]: delta.new,
            last_updated: Date.now() / 1000,
          },
        }));
      }
    };

    return () => eventSource.close();
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Basic Render Loop
    let animationFrameId: number;
    const render = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      
      // Draw Grid
      ctx.strokeStyle = '#222';
      ctx.lineWidth = 1;
      for (let x = 0; x < canvas.width; x += 50 * zoom) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, canvas.height);
        ctx.stroke();
      }
      for (let y = 0; y < canvas.height; y += 50 * zoom) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(canvas.width, y);
        ctx.stroke();
      }

      // Draw Regions
      Object.values(regions).forEach((region, i) => {
        const x = 100 + (i * 120 * zoom);
        const y = 100;
        const size = 80 * zoom;

        // Fog of War
        ctx.globalAlpha = 1 - region.fog_level;
        
        // Body
        ctx.fillStyle = region.id === 'versailles' ? '#ffd700' : '#444';
        ctx.fillRect(x, y, size, size);
        
        // Owner Border
        ctx.strokeStyle = region.owner_id === 'world_leaders' ? '#fff' : '#888';
        ctx.lineWidth = 2;
        ctx.strokeRect(x, y, size, size);

        // Labels
        ctx.globalAlpha = 1;
        ctx.fillStyle = '#fff';
        ctx.font = `${12 * zoom}px Inter, sans-serif`;
        ctx.fillText(region.id, x, y - 10);
        ctx.font = `${10 * zoom}px Inter, sans-serif`;
        ctx.fillText(`Owner: ${region.owner_id}`, x, y + size + 15);
      });

      animationFrameId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(animationFrameId);
  }, [regions, zoom]);

  return (
    <div className="relative w-full h-full bg-black rounded-xl overflow-hidden border border-white/10">
      <div className="absolute top-4 left-4 z-10 flex gap-2">
        <button 
          onClick={() => setZoom(z => Math.min(z + 0.1, 2))}
          className="px-3 py-1 bg-white/10 hover:bg-white/20 rounded text-white text-xs backdrop-blur-md"
        >
          Zoom In
        </button>
        <button 
          onClick={() => setZoom(z => Math.max(z - 0.1, 0.5))}
          className="px-3 py-1 bg-white/10 hover:bg-white/20 rounded text-white text-xs backdrop-blur-md"
        >
          Zoom Out
        </button>
      </div>
      <canvas 
        ref={canvasRef} 
        width={800} 
        height={600} 
        className="w-full h-full cursor-grab active:cursor-grabbing"
      />
      <div className="absolute bottom-4 right-4 text-[10px] text-white/40 uppercase tracking-widest">
        World State: Live Delta Stream Enabled
      </div>
    </div>
  );
}
