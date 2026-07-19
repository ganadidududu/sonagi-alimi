import { KmaFcstItem, WeatherCondition, weatherCondition, parseHourlySlots, evaluateAlert } from "./alertEvaluator";

/**
 * Server-side twin of `WeatherRepository.updateWidgetSnapshot` in the iOS app.
 * The scheduled function computes this from the SAME `getUltraSrtFcst` data it
 * already fetches per grid, stores it in Firestore, and the lock-screen widget
 * reads it via `getWidgetWeather` — so the widget stays fresh without every
 * device hitting KMA (which would blow the 10k/day quota). The line1/line2/
 * a11y wording must match the Swift version exactly.
 */
export interface WidgetSnapshotFields {
  kind: "shower" | "rain" | "calm";
  line1: string;
  line2: string;
  accessibilityLabel: string;
  weatherCondition: string;
}

const CONDITION_LABEL: Record<WeatherCondition, string> = {
  sunny: "맑음",
  partly: "구름 조금",
  cloudy: "흐림",
  rain: "비",
  shower: "소나기",
};

/** "오후 3시~오후 4시" -> "오후 3시~4시" (matches widgetCompactWindowText). */
function compactWindow(windowText: string): string {
  const parts = windowText.split("~");
  if (parts.length !== 2) return windowText;
  for (const period of ["오전 ", "오후 "]) {
    if (parts[0].startsWith(period) && parts[1].startsWith(period)) {
      return parts[0] + "~" + parts[1].slice(period.length);
    }
  }
  return windowText;
}

function line2Text(windowText: string, minutesUntil: number): string {
  const compact = compactWindow(windowText);
  return minutesUntil > 60 ? compact : `${compact} · ${minutesUntil}분 후`;
}

function a11yWindow(windowText: string): string {
  const parts = windowText.split("~");
  if (parts.length !== 2) return windowText;
  const end = parts[1].replace("오전 ", "").replace("오후 ", "");
  return `${parts[0]}부터 ${end}까지`;
}

function minutesPrefix(minutesUntil: number): string {
  return minutesUntil > 60 ? "" : `${minutesUntil}분 후 `;
}

/** Earliest fcst slot's current temp + sky/pty condition, for the calm state. */
function firstSlot(items: KmaFcstItem[]): { temp: number; condition: WeatherCondition } {
  const byTime = new Map<string, Map<string, string>>();
  for (const it of items) {
    if (!it.fcstDate || !it.fcstTime) continue;
    const k = it.fcstDate + it.fcstTime;
    if (!byTime.has(k)) byTime.set(k, new Map());
    byTime.get(k)!.set(it.category, it.fcstValue ?? "");
  }
  const keys = Array.from(byTime.keys()).sort();
  if (keys.length === 0) return { temp: 0, condition: "cloudy" };
  const cats = byTime.get(keys[0])!;
  const pty = Number(cats.get("PTY") ?? "0");
  const skyRaw = cats.get("SKY");
  const sky = skyRaw !== undefined ? Number(skyRaw) : undefined;
  const t1h = cats.get("T1H");
  const temp = t1h !== undefined ? Math.round(Number(t1h)) : 0;
  return { temp, condition: weatherCondition(pty, sky) };
}

// ---- Home-screen widget (systemMedium): current + 6 slots + alert ----

export interface HomeSlot {
  hourLabel: string;
  temperature: number;
  precipProbability: number;
  condition: string; // WeatherCondition rawValue
}

export interface HomeFields {
  currentTemp: number;
  currentCondition: string;
  alert: { kind: "shower" | "rain"; startText: string; minutesUntil: number } | null;
  slots: HomeSlot[];
}

/** Server twin of `WeatherRepository.updateHomeWidgetSnapshot` — 6 hourly slots
 * (hour/temp/precip/condition) + current + optional alert. `locationName` is NOT
 * included (server only knows the grid); the widget keeps its last local name. */
export function buildHomeFields(items: KmaFcstItem[], now: Date = new Date()): HomeFields {
  const byTime = new Map<string, Map<string, string>>();
  for (const it of items) {
    if (!it.fcstDate || !it.fcstTime) continue;
    const k = it.fcstDate + it.fcstTime;
    if (!byTime.has(k)) byTime.set(k, new Map());
    byTime.get(k)!.set(it.category, it.fcstValue ?? "");
  }
  const keys = Array.from(byTime.keys()).sort().slice(0, 6);
  const slots: HomeSlot[] = keys.map((key, i) => {
    const cats = byTime.get(key)!;
    const pty = Number(cats.get("PTY") ?? "0");
    const skyRaw = cats.get("SKY");
    const sky = skyRaw !== undefined ? Number(skyRaw) : undefined;
    const temp = Math.round(Number(cats.get("T1H") ?? "0"));
    const pop = Math.round(Number(cats.get("POP") ?? "0"));
    const hour = Number(key.slice(8, 10));
    return {
      hourLabel: i === 0 ? "지금" : `${hour}시`,
      temperature: temp,
      precipProbability: pop,
      condition: weatherCondition(pty, sky),
    };
  });

  const alert = evaluateAlert(parseHourlySlots(items), now);
  const alertOut = alert
    ? { kind: alert.level.type, startText: compactWindow(alert.level.windowText), minutesUntil: alert.level.minutesUntil }
    : null;

  const current = slots[0];
  return {
    currentTemp: current?.temperature ?? 0,
    currentCondition: current?.condition ?? "cloudy",
    alert: alertOut,
    slots,
  };
}

export function buildWidgetSnapshot(items: KmaFcstItem[], now: Date = new Date()): WidgetSnapshotFields {
  const slots = parseHourlySlots(items);
  const alert = evaluateAlert(slots, now);

  if (alert) {
    const isShower = alert.level.type === "shower";
    return {
      kind: isShower ? "shower" : "rain",
      line1: isShower ? "소나기 임박" : "비 예정",
      line2: line2Text(alert.level.windowText, alert.level.minutesUntil),
      accessibilityLabel:
        `${minutesPrefix(alert.level.minutesUntil)}${a11yWindow(alert.level.windowText)} ` +
        `${isShower ? "소나기가" : "비가"} 예상됩니다`,
      weatherCondition: isShower ? "shower" : "rain",
    };
  }

  const { temp, condition } = firstSlot(items);
  const label = CONDITION_LABEL[condition];
  return {
    kind: "calm",
    line1: "비 걱정 없어요",
    line2: `${temp}° · ${label}`,
    accessibilityLabel: `오늘 강수확률이 낮아 비 걱정이 없습니다. 현재 기온 ${temp}도, ${label}`,
    weatherCondition: condition,
  };
}
