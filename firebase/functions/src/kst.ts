/**
 * KST has no DST, so a fixed +9h offset is safe — shift the instant, then
 * read its UTC fields back as if they were the KST wall-clock fields.
 */
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

function toKstShifted(now: Date): Date {
  return new Date(now.getTime() + KST_OFFSET_MS);
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

export function formatDateKST(now: Date): string {
  const k = toKstShifted(now);
  return `${k.getUTCFullYear()}${pad(k.getUTCMonth() + 1)}${pad(k.getUTCDate())}`;
}

export function currentHourKST(now: Date): number {
  return toKstShifted(now).getUTCHours();
}

export function currentMinuteKST(now: Date): number {
  return toKstShifted(now).getUTCMinutes();
}

/** `getUltraSrtFcst` base_time: half-hourly (`HH30`), safe 45 min after the hour. */
export function ultraSrtFcstBaseTime(now: Date): { date: string; time: string } {
  let k = toKstShifted(now);
  if (k.getUTCMinutes() < 45) {
    k = new Date(k.getTime() - 60 * 60 * 1000);
  }
  const date = `${k.getUTCFullYear()}${pad(k.getUTCMonth() + 1)}${pad(k.getUTCDate())}`;
  return { date, time: `${pad(k.getUTCHours())}30` };
}

export function isWithinDndWindow(now: Date): boolean {
  const h = currentHourKST(now);
  return h >= 22 || h < 7;
}
