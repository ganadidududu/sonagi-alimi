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

export function weatherCondition(pty: number, sky: number | undefined): WeatherCondition {
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
  /** Raining already — the push is suppressed and the copy drops the countdown. */
  isOngoing: boolean;
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

function isWet(slot: HourlySlot): boolean {
  return slot.condition === "shower" || slot.condition === "rain";
}

/** Minutes from now to the top of `hour` — the real countdown to the rain. */
function minutesUntilHour(hour: number, now: Date): number {
  let diff = (hour - currentHourKST(now)) * 60 - currentMinuteKST(now);
  if (diff <= 0) diff += 24 * 60;
  return Math.max(diff, 1);
}

/**
 * Mirrors `KMAParsing.evaluateAlert` in Swift EXACTLY (same window rule, same
 * dedupKey format) so a device's local dedup state and the server's agree on
 * what counts as "the same event" — see `NotificationPreferences` in the app.
 *
 * Reports the whole contiguous rain run (an all-day rain used to always read
 * "2시간") and counts down to the actual start rather than the next o'clock.
 * `minutesUntil === 0` encodes "already raining".
 */
export function evaluateAlert(slots: HourlySlot[], now: Date = new Date()): AlertResult | null {
  if (slots.length === 0) return null;

  const horizon = Math.min(2, slots.length - 1);
  let firstIdx = -1;
  for (let i = 0; i <= horizon; i++) {
    if (isWet(slots[i])) { firstIdx = i; break; }
  }
  if (firstIdx < 0) return null;

  let lastIdx = firstIdx;
  while (lastIdx + 1 < slots.length && isWet(slots[lastIdx + 1])) lastIdx++;
  const openEnded = lastIdx === slots.length - 1;

  const first = slots[firstIdx];
  const isShower = first.condition === "shower";
  const startHour = hourValueFromLabel(first.hourLabel) ?? currentHourKST(now);
  const endHour = (hourValueFromLabel(slots[lastIdx].hourLabel) ?? startHour) + 1;

  const isOngoing = firstIdx === 0;
  const minutesUntil = isOngoing ? 0 : minutesUntilHour(startHour, now);

  let windowText: string;
  if (isOngoing && openEnded) windowText = "당분간 계속";
  else if (isOngoing) windowText = `지금부터 ${koreanHour(endHour)}까지`;
  else if (openEnded) windowText = `${koreanHour(startHour)}부터 계속`;
  else windowText = koreanHourRange(startHour, endHour);

  const level: AlertLevel = isShower
    ? { type: "shower", windowText, minutesUntil }
    : { type: "rain", windowText, minutesUntil };

  const dedupKey = `${isShower ? "shower" : "rain"}-${formatDateKST(now)}-${startHour}`;
  return { level, dedupKey, isOngoing };
}
