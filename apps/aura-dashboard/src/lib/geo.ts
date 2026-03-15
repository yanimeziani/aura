/** Approximate lat/lng centroids for ISO 3166-1 alpha-2 country codes. */
export const COUNTRY_COORDS: Record<string, [number, number]> = {
  AF: [33.9, 67.7], AL: [41.2, 20.2], DZ: [28.0, 1.7], AR: [-38.4, -63.6],
  AU: [-25.3, 133.8], AT: [47.5, 14.6], BD: [23.7, 90.4], BE: [50.5, 4.5],
  BR: [-14.2, -51.9], BG: [42.7, 25.5], CA: [56.1, -106.3], CL: [-35.7, -71.5],
  CN: [35.9, 104.2], CO: [4.6, -74.1], HR: [45.1, 15.2], CZ: [49.8, 15.5],
  DK: [56.3, 9.5], EG: [26.8, 30.8], EE: [58.6, 25.0], FI: [61.9, 25.7],
  FR: [46.2, 2.2], DE: [51.2, 10.4], GR: [39.1, 21.8], HK: [22.4, 114.1],
  HU: [47.2, 19.5], IN: [20.6, 79.0], ID: [-0.8, 113.9], IE: [53.4, -8.2],
  IL: [31.0, 34.9], IT: [41.9, 12.6], JP: [36.2, 138.3], KE: [-0.02, 37.9],
  KR: [35.9, 127.8], LV: [56.9, 24.1], LT: [55.2, 23.9], LU: [49.8, 6.1],
  MY: [4.2, 101.9], MX: [23.6, -102.6], MA: [31.8, -7.1], NL: [52.1, 5.3],
  NZ: [-40.9, 174.9], NG: [9.1, 8.7], NO: [60.5, 8.5], PK: [30.4, 69.3],
  PE: [-9.2, -75.0], PH: [12.9, 121.8], PL: [51.9, 19.1], PT: [39.4, -8.2],
  RO: [45.9, 25.0], RU: [61.5, 105.3], SA: [23.9, 45.1], SG: [1.4, 103.8],
  SK: [48.7, 19.7], SI: [46.2, 14.5], ZA: [-30.6, 22.9], ES: [40.5, -3.7],
  SE: [60.1, 18.6], CH: [46.8, 8.2], TW: [23.7, 121.0], TH: [15.9, 100.9],
  TR: [38.9, 35.2], UA: [48.4, 31.2], AE: [23.4, 53.8], GB: [55.4, -3.4],
  US: [37.1, -95.7], VN: [14.1, 108.3], QC: [52.0, -72.0],
};

/** Convert lat/lng to 3D position on a sphere. */
export function latLngToVector3(
  lat: number,
  lng: number,
  radius: number
): [number, number, number] {
  const phi = (90 - lat) * (Math.PI / 180);
  const theta = (lng + 180) * (Math.PI / 180);
  const x = -(radius * Math.sin(phi) * Math.cos(theta));
  const z = radius * Math.sin(phi) * Math.sin(theta);
  const y = radius * Math.cos(phi);
  return [x, y, z];
}

/** Get coordinates for a country code, with fallback. */
export function getCountryPosition(
  countryCode: string,
  radius: number
): [number, number, number] {
  const coords = COUNTRY_COORDS[countryCode.toUpperCase()] || [0, 0];
  return latLngToVector3(coords[0], coords[1], radius);
}

/** Generate a great-circle arc between two points on a sphere. */
export function generateArc(
  start: [number, number, number],
  end: [number, number, number],
  segments: number = 64,
  altitude: number = 0.3
): Float32Array {
  const points = new Float32Array(segments * 3);

  for (let i = 0; i < segments; i++) {
    const t = i / (segments - 1);

    // Spherical interpolation (slerp-like)
    const x = start[0] * (1 - t) + end[0] * t;
    const y = start[1] * (1 - t) + end[1] * t;
    const z = start[2] * (1 - t) + end[2] * t;

    // Normalize to sphere surface
    const len = Math.sqrt(x * x + y * y + z * z);
    const arcHeight = 1 + altitude * Math.sin(t * Math.PI);

    points[i * 3] = (x / len) * arcHeight;
    points[i * 3 + 1] = (y / len) * arcHeight;
    points[i * 3 + 2] = (z / len) * arcHeight;
  }

  return points;
}
