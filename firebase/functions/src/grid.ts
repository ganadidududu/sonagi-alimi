/**
 * KMA Lambert Conformal Conic grid → WGS84 lat/lon (the inverse of
 * `GridConverter.toGrid` in the app). The server caches everything by
 * `(nx, ny)`, but Open-Meteo needs lat/lon — so we recover the grid cell's
 * centre coordinate to query it. A 5 km cell is well within any global model's
 * resolution, so the centre is a fine representative point.
 *
 * Constants match the app exactly (Plan FR-01): Re=6371.00877, grid=5.0,
 * slat1=30, slat2=60, olon=126, olat=38, xo=43, yo=136.
 */
const RE = 6371.00877;
const GRID = 5.0;
const SLAT1 = 30.0;
const SLAT2 = 60.0;
const OLON = 126.0;
const OLAT = 38.0;
const XO = 43;
const YO = 136;

const DEGRAD = Math.PI / 180.0;
const RADDEG = 180.0 / Math.PI;

export interface LatLon {
  lat: number;
  lon: number;
}

export function gridToLatLon(nx: number, ny: number): LatLon {
  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD;
  const slat2 = SLAT2 * DEGRAD;
  const olon = OLON * DEGRAD;
  const olat = OLAT * DEGRAD;

  let sn =
    Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = (Math.pow(sf, sn) * Math.cos(slat1)) / sn;
  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = (re * sf) / Math.pow(ro, sn);

  const xn = nx - XO;
  const yn = ro - ny + YO;
  let ra = Math.sqrt(xn * xn + yn * yn);
  if (sn < 0) ra = -ra;
  let alat = Math.pow((re * sf) / ra, 1.0 / sn);
  alat = 2.0 * Math.atan(alat) - Math.PI * 0.5;

  let theta: number;
  if (Math.abs(xn) <= 0.0) {
    theta = 0.0;
  } else if (Math.abs(yn) <= 0.0) {
    theta = Math.PI * 0.5;
    if (xn < 0) theta = -theta;
  } else {
    theta = Math.atan2(xn, yn);
  }
  const alon = theta / sn + olon;

  return { lat: alat * RADDEG, lon: alon * RADDEG };
}
