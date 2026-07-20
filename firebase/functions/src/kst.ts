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

/**
 * `getVilageFcst` base_time: published 8 times a day at 02/05/08/11/14/17/20/23,
 * usable ~10 minutes later. Mirrors `KMABaseTime.vilageFcst()` in the app.
 * Before 02:10 the newest release is yesterday's 23:00 one.
 */
export function vilageFcstBaseTime(now: Date): { date: string; time: string } {
  const k = toKstShifted(now);
  const minutesNow = k.getUTCHours() * 60 + k.getUTCMinutes();
  const slots = [2, 5, 8, 11, 14, 17, 20, 23];
  const available = slots.filter((h) => minutesNow >= h * 60 + 10);

  if (available.length === 0) {
    const y = new Date(k.getTime() - 24 * 60 * 60 * 1000);
    const date = `${y.getUTCFullYear()}${pad(y.getUTCMonth() + 1)}${pad(y.getUTCDate())}`;
    return { date, time: "2300" };
  }
  const hour = available[available.length - 1];
  const date = `${k.getUTCFullYear()}${pad(k.getUTCMonth() + 1)}${pad(k.getUTCDate())}`;
  return { date, time: `${pad(hour)}00` };
}

export function isWithinDndWindow(now: Date): boolean {
  const h = currentHourKST(now);
  return h >= 22 || h < 7;
}
