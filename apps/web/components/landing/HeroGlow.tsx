'use client';

export default function HeroGlow() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
      {/* Orbiting gradient blobs */}
      <div className="hero-blob hero-blob--primary" />
      <div className="hero-blob hero-blob--accent" />
      <div className="hero-blob hero-blob--secondary" />

      {/* Film grain overlay */}
      <svg className="absolute inset-0 w-full h-full opacity-[0.018] mix-blend-multiply dark:mix-blend-soft-light">
        <filter id="hero-grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.65" numOctaves="3" stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#hero-grain)" />
      </svg>
    </div>
  );
}
