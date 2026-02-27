'use client';

import { useMemo } from 'react';

const GLYPHS = ['💵', '💰', '🪙', '💎', '📈', '💸', '🏦', '💳'];

interface Particle {
  id: number;
  glyph: string;
  left: number;
  delay: number;
  duration: number;
  size: number;
  drift: number;
  startRotation: number;
}

function seededRandom(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807 + 0) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

export default function MoneyRain({ count = 18 }: { count?: number }) {
  const particles = useMemo<Particle[]>(() => {
    const rand = seededRandom(42);
    return Array.from({ length: count }, (_, i) => ({
      id: i,
      glyph: GLYPHS[Math.floor(rand() * GLYPHS.length)],
      left: rand() * 100,
      delay: rand() * -20,
      duration: 14 + rand() * 12,
      size: 14 + rand() * 10,
      drift: -30 + rand() * 60,
      startRotation: rand() * 360,
    }));
  }, [count]);

  return (
    <div
      className="absolute inset-0 overflow-hidden pointer-events-none"
      aria-hidden="true"
    >
      {particles.map((p) => (
        <span
          key={p.id}
          className="absolute opacity-[0.06] money-particle"
          style={{
            left: `${p.left}%`,
            fontSize: `${p.size}px`,
            animationDelay: `${p.delay}s`,
            animationDuration: `${p.duration}s`,
            '--drift': `${p.drift}px`,
            '--start-rot': `${p.startRotation}deg`,
          } as React.CSSProperties}
        >
          {p.glyph}
        </span>
      ))}
    </div>
  );
}
