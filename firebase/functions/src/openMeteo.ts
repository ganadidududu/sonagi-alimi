import { logger } from "firebase-functions";

/**
 * Open-Meteo adapter for the daily consensus forecast (F3). One call returns
 * BOTH global models we vote with — ECMWF and ICON — keyed by a model suffix on
 * each field. No API key, free, redistribution-allowed; that's why it's here
 * and AccuWeather/WeatherKit aren't (commercial redistribution is barred).
 */

export type OmModel = "ecmwf_ifs025" | "icon_seamless";
export const OM_MODELS: OmModel[] = ["ecmwf_ifs025", "icon_seamless"];

/** One model's view of one day. `null` fields mean that model didn't cover it. */
export interface OmDay {
  date: string; // "YYYY-MM-DD" KST
  precipProbabilityMax: number | null;
  precipSum: number | null;
  weatherCode: number | null;
  tempMax: number | null;
  tempMin: number | null;
}

export type OmForecast = Record<OmModel, OmDay[]>;

const DAILY_FIELDS = [
  "precipitation_probability_max",
  "precipitation_sum",
  "weather_code",
  "temperature_2m_max",
  "temperature_2m_min",
];

/**
 * Fetches 3-day daily forecasts for both models at one coordinate. Returns null
 * on any failure — the consensus layer falls back to KMA-only, so a dead
 * Open-Meteo must never take the daily screen down with it.
 */
export async function fetchOpenMeteo(lat: number, lon: number): Promise<OmForecast | null> {
  const url =
    "https://api.open-meteo.com/v1/forecast" +
    `?latitude=${lat.toFixed(4)}&longitude=${lon.toFixed(4)}` +
    `&daily=${DAILY_FIELDS.join(",")}` +
    `&models=${OM_MODELS.join(",")}` +
    "&timezone=Asia%2FSeoul&forecast_days=3";

  try {
    const res = await fetch(url);
    if (!res.ok) {
      logger.warn(`Open-Meteo HTTP ${res.status} at ${lat},${lon}`);
      return null;
    }
    const json = (await res.json()) as any;
    const daily = json?.daily;
    if (!daily || !Array.isArray(daily.time)) {
      logger.warn(`Open-Meteo malformed body at ${lat},${lon}`);
      return null;
    }
    return parseDaily(daily);
  } catch (err) {
    logger.error(`Open-Meteo fetch failed at ${lat},${lon}`, err);
    return null;
  }
}

/** Splits the suffixed fields (`..._ecmwf_ifs025`) into per-model day arrays. */
export function parseDaily(daily: any): OmForecast {
  const dates: string[] = daily.time;
  const out = {} as OmForecast;

  for (const model of OM_MODELS) {
    const pick = (field: string, i: number): number | null => {
      const arr = daily[`${field}_${model}`];
      const v = Array.isArray(arr) ? arr[i] : undefined;
      return typeof v === "number" ? v : null;
    };
    out[model] = dates.map((date, i) => ({
      date,
      precipProbabilityMax: pick("precipitation_probability_max", i),
      precipSum: pick("precipitation_sum", i),
      weatherCode: pick("weather_code", i),
      tempMax: pick("temperature_2m_max", i),
      tempMin: pick("temperature_2m_min", i),
    }));
  }
  return out;
}

/**
 * A model "says rain" for a day when its max precip probability clears 60%, or
 * its accumulated precip clears 1 mm (catches low-probability-but-wet days).
 * Mirrors the KMA normalisation in `consensus.ts`. Returns null when the model
 * has no data for that day (so it abstains from the vote rather than voting no).
 */
export function omSaysRain(day: OmDay): boolean | null {
  if (day.precipProbabilityMax == null && day.precipSum == null) return null;
  const pop = day.precipProbabilityMax ?? 0;
  const sum = day.precipSum ?? 0;
  return pop >= 60 || sum >= 1.0;
}
