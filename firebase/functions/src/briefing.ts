import { KmaFcstItem } from "./alertEvaluator";
import { currentHourKST, currentMinuteKST, formatDateKST } from "./kst";

/**
 * The morning briefing answers one question before the user leaves the house:
 * "do I need an umbrella today?".
 *
 * It can't be a locally-scheduled notification — the text depends on a forecast
 * that isn't known until the moment it fires — so the scheduled function sends
 * it as a push at the user's chosen KST time.
 *
 * Unlike the shower alert this reads `getVilageFcst` rather than
 * `getUltraSrtFcst`: at 07:30 the ultra-short forecast only reaches ~13:30,
 * which would miss an afternoon downpour entirely.
 */

/** Wet sky codes in `PTY` — 0 is "none", 3/7 are snow, the rest are rain-ish. */
function isWetPty(pty: number): boolean {
  return pty > 0;
}

interface DaySlot {
  hour: number;
  pty: number;
  pop: number;
}

/** Today's slots from `getVilageFcst`, in hour order. */
export function todaySlots(items: KmaFcstItem[], now: Date = new Date()): DaySlot[] {
  const today = formatDateKST(now);
  const byTime = new Map<string, Map<string, string>>();
  for (const item of items) {
    if (item.fcstDate !== today || !item.fcstTime) continue;
    if (!byTime.has(item.fcstTime)) byTime.set(item.fcstTime, new Map());
    byTime.get(item.fcstTime)!.set(item.category, item.fcstValue ?? "");
  }
  return Array.from(byTime.keys())
    .sort()
    .map((time) => ({
      hour: Number(time.slice(0, 2)),
      pty: Number(byTime.get(time)!.get("PTY") ?? "0"),
      pop: Number(byTime.get(time)!.get("POP") ?? "0"),
    }));
}

function koreanHour(hour24: number): string {
  const h = ((hour24 % 24) + 24) % 24;
  const period = h < 12 ? "오전" : "오후";
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${period} ${hour12}시`;
}

export interface Briefing {
  title: string;
  body: string;
}

/**
 * Only counts hours from now on — nobody leaving at 07:30 needs to hear about
 * the drizzle that fell at 03:00. Returns null when there's nothing to fetch a
 * forecast for (no remaining slots today).
 */
export function buildBriefing(items: KmaFcstItem[], now: Date = new Date()): Briefing | null {
  const fromHour = currentHourKST(now);
  const slots = todaySlots(items, now).filter((s) => s.hour >= fromHour);
  if (slots.length === 0) return null;

  const wet = slots.filter((s) => isWetPty(s.pty));
  const maxPop = slots.reduce((m, s) => Math.max(m, s.pop), 0);

  if (wet.length > 0) {
    const start = wet[0].hour;
    // The run may be broken up across the day; report first..last wet hour so
    // "오후 2시~오후 6시" covers the span the user actually has to plan around.
    const end = wet[wet.length - 1].hour + 1;
    let span: string;
    if (end >= 24) {
      // Wrapping past midnight would render as "오전 12시", which reads as noon
      // to most people — say "…부터" and let the day end it.
      span = `${koreanHour(start)}부터`;
    } else if (start === end - 1) {
      span = koreanHour(start);
    } else {
      span = `${koreanHour(start)}~${koreanHour(end)}`;
    }
    return {
      title: "☂️ 오늘은 우산 챙기세요",
      body: `${span} 비가 올 예정이에요 · 강수확률 최고 ${maxPop}%`,
    };
  }

  // No wet slot, but a high POP still deserves a hedge rather than a flat "no".
  if (maxPop >= 60) {
    return {
      title: "🌦 우산이 있으면 안심이에요",
      body: `비 예보는 없지만 강수확률이 최고 ${maxPop}%까지 올라가요`,
    };
  }

  return {
    title: "☀️ 오늘은 우산 없이도 괜찮아요",
    body: `종일 비 소식이 없어요 · 강수확률 최고 ${maxPop}%`,
  };
}

/**
 * True when `now` is the first 10-minute scheduler tick at or after the user's
 * chosen time. `lastSentDate` (KST `yyyyMMdd`) makes it fire once a day even if
 * the schedule runs late or retries.
 */
export function isBriefingDue(
  briefingHour: number,
  briefingMinute: number,
  lastSentDate: string | undefined,
  now: Date = new Date()
): boolean {
  if (lastSentDate === formatDateKST(now)) return false;
  const nowMinutes = currentHourKST(now) * 60 + currentMinuteKST(now);
  const dueMinutes = briefingHour * 60 + briefingMinute;
  // Only within the tick window — without the upper bound a device that missed
  // its slot (offline, added later in the day) would be pinged immediately at
  // whatever hour it happened to come back.
  return nowMinutes >= dueMinutes && nowMinutes < dueMinutes + 10;
}
