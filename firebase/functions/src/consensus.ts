import { KmaFcstItem } from "./alertEvaluator";
import { OmForecast, OM_MODELS, omSaysRain } from "./openMeteo";
import { formatDateKST } from "./kst";

/**
 * Server-side 3-source daily consensus (F3). KMA (the only domestic model) +
 * ECMWF + ICON vote on whether each day is wet; numbers are averaged, not
 * voted. Runs in the scheduler next to the existing KMA fetch and is cached per
 * grid, so the app and widgets read one agreed answer and Open-Meteo is hit
 * once per neighbourhood, not once per user.
 *
 * See design: docs/02-design/features/consensus-forecast.design.md
 */

export type ConsensusLevel = "unanimous" | "majority" | "single";

export interface SourceView {
  source: "kma" | "ecmwf" | "icon";
  saysRain: boolean;
  tempMax: number | null;
  precipProbability: number | null;
}

export interface ConsensusDay {
  date: string; // YYYYMMDD KST
  willRain: boolean; // majority verdict
  level: ConsensusLevel; // unanimous(3/3) | majority(2/3) | single(fallback)
  rainVotes: number; // e.g. 2 (out of `voteCount`)
  voteCount: number; // sources that actually voted (2 or 3)
  tempMax: number | null; // average across available sources
  tempMin: number | null;
  precipProbability: number | null; // average across available sources
  sources: SourceView[]; // per-source detail for the tap-through sheet
}

// ---- KMA vilage → per-day reduction ----

interface KmaDay {
  date: string;
  saysRain: boolean;
  tempMax: number | null;
  tempMin: number | null;
  precipProbability: number | null;
}

/** Group `getVilageFcst` items by KST date and reduce each to the F3 fields. */
export function kmaDailies(items: KmaFcstItem[]): KmaDay[] {
  const byDate = new Map<string, KmaFcstItem[]>();
  for (const it of items) {
    if (!it.fcstDate) continue;
    if (!byDate.has(it.fcstDate)) byDate.set(it.fcstDate, []);
    byDate.get(it.fcstDate)!.push(it);
  }

  return Array.from(byDate.keys())
    .sort()
    .map((date) => {
      const rows = byDate.get(date)!;
      const nums = (cat: string) =>
        rows.filter((r) => r.category === cat).map((r) => Number(r.fcstValue)).filter((n) => !Number.isNaN(n));

      const pty = nums("PTY");
      const pop = nums("POP");
      const tmp = nums("TMP");
      const tmx = nums("TMX");
      const tmn = nums("TMN");

      // Domestic normalisation, mirroring the app: a wet PTY anywhere in the
      // day, or a daytime POP that clears 60%.
      const maxPop = pop.length ? Math.max(...pop) : 0;
      const saysRain = pty.some((v) => v > 0) || maxPop >= 60;

      return {
        date,
        saysRain,
        tempMax: tmx.length ? tmx[0] : tmp.length ? Math.max(...tmp) : null,
        tempMin: tmn.length ? tmn[0] : tmp.length ? Math.min(...tmp) : null,
        precipProbability: pop.length ? maxPop : null,
      };
    });
}

// ---- Merge KMA + Open-Meteo into the consensus ----

function avg(values: (number | null)[]): number | null {
  const nums = values.filter((v): v is number => v != null);
  if (nums.length === 0) return null;
  return Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 10) / 10;
}

/** KST "YYYY-MM-DD" (Open-Meteo) ↔ "YYYYMMDD" (KMA). */
function omDateToKma(d: string): string {
  return d.replace(/-/g, "");
}

/**
 * Builds up to 3 consensus days. `om` may be null (Open-Meteo down) — then every
 * day degrades to `single` on KMA alone, and the daily screen still renders.
 * KMA is the spine: we iterate its days and match the others in.
 */
export function buildConsensus(
  kmaItems: KmaFcstItem[],
  om: OmForecast | null,
  now: Date = new Date()
): ConsensusDay[] {
  const kma = kmaDailies(kmaItems).filter((d) => d.date >= formatDateKST(now));
  const days = kma.slice(0, 3);

  return days.map((k) => {
    const sources: SourceView[] = [
      { source: "kma", saysRain: k.saysRain, tempMax: k.tempMax, precipProbability: k.precipProbability },
    ];

    if (om) {
      for (const model of OM_MODELS) {
        const day = om[model].find((d) => omDateToKma(d.date) === k.date);
        if (!day) continue;
        const vote = omSaysRain(day);
        if (vote == null) continue; // model abstains
        sources.push({
          source: model === "ecmwf_ifs025" ? "ecmwf" : "icon",
          saysRain: vote,
          tempMax: day.tempMax,
          precipProbability: day.precipProbabilityMax,
        });
      }
    }

    const voteCount = sources.length;
    const rainVotes = sources.filter((s) => s.saysRain).length;
    const willRain = rainVotes * 2 > voteCount; // strict majority
    const level: ConsensusLevel =
      voteCount < 3 ? "single" : rainVotes === 0 || rainVotes === 3 ? "unanimous" : "majority";

    return {
      date: k.date,
      willRain,
      level,
      rainVotes,
      voteCount,
      tempMax: avg(sources.map((s) => s.tempMax)),
      tempMin: k.tempMin, // only KMA reports a domestic min; keep it simple
      precipProbability: avg(sources.map((s) => s.precipProbability)),
      sources,
    };
  });
}
