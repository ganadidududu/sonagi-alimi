import { currentHourKST, currentMinuteKST, formatDateKST } from "./kst";

/** Mirrors `KMAItem` in the iOS app — one row from `getUltraSrtFcst`. */
export interface KmaFcstItem {
  category: string;
  fcstDate?: string;
  fcstTime?: string;
  fcstValue?: string;
}

export type WeatherCondition = "sunny" | "partly" | "cloudy" | "rain" | "shower";

export interface HourlySlot {
  hourLabel: string;
  condition: WeatherCondition;
}

function weatherCondition(pty: number, sky: number | undefined): WeatherCondition {
  if (pty === 4) return "shower";
  if (pty === 1 || pty === 2 || pty === 5 || pty === 6 || pty === 7) return "rain";
  if (sky === 3) return "partly";
  if (sky === 4) return "cloudy";
  return "sunny";
}

/** Same 7-slot, "지금 first" grouping as `KMAParsing.parseHourlySlots` in Swift. */
export function parseHourlySlots(items: KmaFcstItem[]): HourlySlot[] {
  const byTime = new Map<string, Map<string, string>>();
  for (const item of items) {
    if (!item.fcstDate || !item.fcstTime) continue;
    const key = item.fcstDate + item.fcstTime;
    if (!byTime.has(key)) byTime.set(key, new Map());
    byTime.get(key)!.set(item.category, item.fcstValue ?? "");
  }

  const orderedKeys = Array.from(byTime.keys()).sort().slice(0, 7);
  const slots: HourlySlot[] = [];
  orderedKeys.forEach((key, index) => {
    const categories = byTime.get(key)!;
    const ptyRaw = categories.get("PTY");
    if (ptyRaw === undefined) return;
    const pty = Number(ptyRaw);
    const skyRaw = categories.get("SKY");
    const sky = skyRaw !== undefined ? Number(skyRaw) : undefined;
    const hour = Number(key.slice(8, 10));
    const hourLabel = index === 0 ? "지금" : `${hour}시`;
    slots.push({ hourLabel, condition: weatherCondition(pty, sky) });
  });
  return slots;
}

export type AlertLevel =
  | { type: "shower"; windowText: string; minutesUntil: number }
  | { type: "rain"; windowText: string; minutesUntil: number };

export interface AlertResult {
  level: AlertLevel;
  dedupKey: string;
}

function hourValueFromLabel(label: string): number | undefined {
  const n = Number(label.replace("시", ""));
  return Number.isNaN(n) ? undefined : n;
}

function koreanHour(hour24: number): string {
  const h = ((hour24 % 24) + 24) % 24;
  const period = h < 12 ? "오전" : "오후";
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${period} ${hour12}시`;
}

function koreanHourRange(startHour: number, endHour: number): string {
  return `${koreanHour(startHour)}~${koreanHour(endHour)}`;
}

/**
 * Mirrors `KMAParsing.evaluateAlert` in Swift EXACTLY (same window rule, same
 * dedupKey format) so a device's local dedup state and the server's agree on
 * what counts as "the same event" — see `NotificationPreferences` in the app.
 */
export function evaluateAlert(slots: HourlySlot[], now: Date = new Date()): AlertResult | null {
  const upcoming = slots.slice(1, 3);
  const firstRain = upcoming.find((s) => s.condition === "shower" || s.condition === "rain");
  if (!firstRain) return null;

  const isShower = firstRain.condition === "shower";
  const startHour = hourValueFromLabel(firstRain.hourLabel) ?? currentHourKST(now);
  const endHour = startHour + upcoming.filter((s) => s.condition === "shower" || s.condition === "rain").length;
  const windowText = koreanHourRange(startHour, endHour);
  const minutesUntil = Math.max(60 - currentMinuteKST(now), 1);

  const level: AlertLevel = isShower
    ? { type: "shower", windowText, minutesUntil }
    : { type: "rain", windowText, minutesUntil };

  const dedupKey = `${isShower ? "shower" : "rain"}-${formatDateKST(now)}-${startHour}`;
  return { level, dedupKey };
}
