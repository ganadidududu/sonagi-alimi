import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { evaluateAlert, parseHourlySlots, AlertResult, KmaFcstItem } from "./alertEvaluator";
import { buildWidgetSnapshot, buildHomeFields, countdownText } from "./widgetSnapshot";
import { ultraSrtFcstBaseTime, vilageFcstBaseTime, isWithinDndWindow, formatDateKST } from "./kst";
import { buildBriefing, isBriefingDue } from "./briefing";
import { buildConsensus } from "./consensus";
import { fetchOpenMeteo } from "./openMeteo";
import { gridToLatLon } from "./grid";

admin.initializeApp();
const db = admin.firestore();

/** Set with: `firebase functions:secrets:set KMA_SERVICE_KEY` (paste the Decoding key). */
const KMA_SERVICE_KEY = defineSecret("KMA_SERVICE_KEY");

interface DeviceDoc {
  fcmToken?: string;
  nx?: number;
  ny?: number;
  notifMasterOn?: boolean;
  notifShowerOn?: boolean;
  notifRainOn?: boolean;
  notifDndOn?: boolean;
  lastNotifiedKey?: string;
  briefingOn?: boolean;
  briefingHour?: number;
  briefingMinute?: number;
  /** KST `yyyyMMdd` of the last briefing sent — one per day, per device. */
  lastBriefingDate?: string;
}

/**
 * Runs every 10 minutes. Groups devices by (nx, ny) so N devices in the same
 * neighborhood cost one KMA call, not N — mirrors the PRD's caching intent,
 * just server-side instead of per-client.
 */
export const checkWeatherAlerts = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "Asia/Seoul",
    secrets: [KMA_SERVICE_KEY],
    region: "asia-northeast3",
  },
  async () => {
    const devicesSnap = await db.collection("devices").get();
    if (devicesSnap.empty) return;

    const byGrid = new Map<string, FirebaseFirestore.QueryDocumentSnapshot[]>();
    for (const doc of devicesSnap.docs) {
      const { nx, ny } = doc.data() as DeviceDoc;
      if (nx == null || ny == null) continue;
      const key = `${nx},${ny}`;
      if (!byGrid.has(key)) byGrid.set(key, []);
      byGrid.get(key)!.push(doc);
    }

    const serviceKey = KMA_SERVICE_KEY.value();
    await Promise.all(
      Array.from(byGrid.entries()).map(([gridKey, docs]) => processGrid(gridKey, docs, serviceKey))
    );

    // Reuses the device snapshot above rather than re-querying Firestore.
    await sendDueBriefings(devicesSnap.docs, serviceKey);
  }
);

/**
 * "Do I need an umbrella today?", delivered at each user's own time. Grouped by
 * grid like the alerts so a neighbourhood costs one KMA call, and only for
 * devices actually due this tick — on most ticks that's nobody and we make no
 * calls at all.
 */
async function sendDueBriefings(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  serviceKey: string
): Promise<void> {
  const now = new Date();
  const due = docs.filter((doc) => {
    const d = doc.data() as DeviceDoc;
    if (!d.briefingOn || d.notifMasterOn === false || !d.fcmToken) return false;
    if (d.nx == null || d.ny == null) return false;
    return isBriefingDue(d.briefingHour ?? 7, d.briefingMinute ?? 30, d.lastBriefingDate, now);
  });
  if (due.length === 0) return;

  const byGrid = new Map<string, FirebaseFirestore.QueryDocumentSnapshot[]>();
  for (const doc of due) {
    const { nx, ny } = doc.data() as DeviceDoc;
    const key = `${nx},${ny}`;
    if (!byGrid.has(key)) byGrid.set(key, []);
    byGrid.get(key)!.push(doc);
  }

  await Promise.all(
    Array.from(byGrid.entries()).map(async ([gridKey, gridDocs]) => {
      const [nx, ny] = gridKey.split(",");
      const items = await fetchVilageFcst(nx, ny, serviceKey);
      if (!items) return;
      const briefing = buildBriefing(items, now);
      if (!briefing) return;

      await Promise.all(
        gridDocs.map(async (doc) => {
          const { fcmToken } = doc.data() as DeviceDoc;
          try {
            await admin.messaging().send({
              token: fcmToken!,
              notification: { title: briefing.title, body: briefing.body },
              apns: { payload: { aps: { sound: "default" } } },
            });
            await doc.ref.update({ lastBriefingDate: formatDateKST(now) });
          } catch (err) {
            logger.error(`briefing send failed for device ${doc.id}`, err);
          }
        })
      );
    })
  );
}

async function processGrid(
  gridKey: string,
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  serviceKey: string
): Promise<void> {
  const [nx, ny] = gridKey.split(",");
  const items = await fetchUltraSrtFcst(nx, ny, serviceKey);
  if (!items) return;

  // Cache the widget snapshot for this grid regardless of whether there's an
  // alert — the lock-screen widget reads it via `getWidgetWeather`, so it must
  // reflect the calm ("비 걱정 없어요") state too, not only rain events.
  const snapshot = buildWidgetSnapshot(items);
  const home = buildHomeFields(items);
  await db.collection("gridWeather").doc(`${nx}_${ny}`).set(
    { ...snapshot, home, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  // Daily 3-source consensus (F3). Independent of the alert path: it reads the
  // day forecast (getVilageFcst) + Open-Meteo (ECMWF·ICON) and caches the vote
  // so the app reads one agreed answer. Failure here must not block the alert.
  await updateConsensus(nx, ny, serviceKey);

  const slots = parseHourlySlots(items);
  const alert = evaluateAlert(slots);
  // Rain already falling → the widget still shows it, but no push: a
  // "곧 비가 와요" alert while the user is already in the rain is noise.
  if (!alert || alert.isOngoing) return;

  await Promise.all(docs.map((doc) => notifyDevice(doc, alert)));
}

/**
 * Computes and caches the daily consensus for one grid. KMA is the spine; if
 * Open-Meteo is down the vote degrades to KMA-only ("single") rather than
 * failing — the daily screen must never go blank. Cached under the same
 * `gridWeather/{nx}_{ny}` doc the widgets already use.
 */
async function updateConsensus(nx: string, ny: string, serviceKey: string): Promise<void> {
  try {
    const items = await fetchVilageFcst(nx, ny, serviceKey);
    if (!items) return; // no KMA day forecast → leave the previous cache as-is
    const { lat, lon } = gridToLatLon(Number(nx), Number(ny));
    const om = await fetchOpenMeteo(lat, lon);
    const consensus = buildConsensus(items, om);
    await db.collection("gridWeather").doc(`${nx}_${ny}`).set(
      { consensus, consensusUpdatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  } catch (err) {
    logger.error(`consensus update failed for grid ${nx},${ny}`, err);
  }
}

/**
 * Read endpoint the lock-screen widget calls (no Firebase SDK on the widget —
 * just a lightweight URLSession GET). Returns the cached snapshot for a grid.
 * KMA is never touched here; the scheduled function already populated it.
 */
export const getWidgetWeather = onRequest(
  { region: "asia-northeast3", cors: true, invoker: "public" },
  async (req, res) => {
    const nx = String(req.query.nx ?? "");
    const ny = String(req.query.ny ?? "");
    if (!/^\d+$/.test(nx) || !/^\d+$/.test(ny)) {
      res.status(400).json({ error: "nx and ny (integers) are required" });
      return;
    }
    const doc = await db.collection("gridWeather").doc(`${nx}_${ny}`).get();
    if (!doc.exists) {
      res.status(404).json({ error: "no cached weather for this grid yet" });
      return;
    }
    const d = doc.data()!;
    res.set("Cache-Control", "public, max-age=300");
    res.json({
      // lock-screen widget fields
      kind: d.kind,
      line1: d.line1,
      line2: d.line2,
      accessibilityLabel: d.accessibilityLabel,
      weatherCondition: d.weatherCondition,
      // home-screen widget fields (6 slots + current + alert)
      home: d.home ?? null,
      // daily 3-source consensus (F3) — null until the scheduler first fills it
      consensus: d.consensus ?? null,
    });
  }
);

async function fetchUltraSrtFcst(nx: string, ny: string, serviceKey: string): Promise<KmaFcstItem[] | null> {
  const { date, time } = ultraSrtFcstBaseTime(new Date());
  const url =
    "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtFcst" +
    `?serviceKey=${encodeURIComponent(serviceKey)}&dataType=JSON&numOfRows=1000&pageNo=1` +
    `&base_date=${date}&base_time=${time}&nx=${nx}&ny=${ny}`;

  try {
    const res = await fetch(url);
    if (!res.ok) {
      logger.warn(`KMA HTTP ${res.status} for grid ${nx},${ny}`);
      return null;
    }
    const json = (await res.json()) as any;
    if (json?.response?.header?.resultCode !== "00") {
      logger.warn(`KMA resultCode ${json?.response?.header?.resultCode} for grid ${nx},${ny}`);
      return null;
    }
    return (json?.response?.body?.items?.item ?? []) as KmaFcstItem[];
  } catch (err) {
    logger.error(`KMA fetch failed for grid ${nx},${ny}`, err);
    return null;
  }
}

/** Full-day forecast — the briefing needs hours the 6-hour ultra-short one can't reach. */
async function fetchVilageFcst(nx: string, ny: string, serviceKey: string): Promise<KmaFcstItem[] | null> {
  const { date, time } = vilageFcstBaseTime(new Date());
  const url =
    "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst" +
    `?serviceKey=${encodeURIComponent(serviceKey)}&dataType=JSON&numOfRows=1000&pageNo=1` +
    `&base_date=${date}&base_time=${time}&nx=${nx}&ny=${ny}`;

  try {
    const res = await fetch(url);
    if (!res.ok) {
      logger.warn(`KMA vilage HTTP ${res.status} for grid ${nx},${ny}`);
      return null;
    }
    const json = (await res.json()) as any;
    if (json?.response?.header?.resultCode !== "00") {
      logger.warn(`KMA vilage resultCode ${json?.response?.header?.resultCode} for grid ${nx},${ny}`);
      return null;
    }
    return (json?.response?.body?.items?.item ?? []) as KmaFcstItem[];
  } catch (err) {
    logger.error(`KMA vilage fetch failed for grid ${nx},${ny}`, err);
    return null;
  }
}

async function notifyDevice(doc: FirebaseFirestore.QueryDocumentSnapshot, alert: AlertResult): Promise<void> {
  const data = doc.data() as DeviceDoc;

  if (data.notifMasterOn === false) return;
  const isShower = alert.level.type === "shower";
  if (isShower && data.notifShowerOn === false) return;
  if (!isShower && data.notifRainOn === false) return;
  if (data.lastNotifiedKey === alert.dedupKey) return;
  if (data.notifDndOn && isWithinDndWindow(new Date())) return;
  if (!data.fcmToken) return;

  const title = isShower ? "🌦 소나기 알림" : "🌧 비 알림";
  const body = isShower
    ? `${alert.level.windowText} 소나기가 지나가요. 약 ${countdownText(alert.level.minutesUntil)} 뒤 시작 · 우산을 꼭 챙기세요 ☂️`
    : `${alert.level.windowText} 비가 내려요. 약 ${countdownText(alert.level.minutesUntil)} 뒤 시작 · 우산을 챙기세요 ☂️`;

  try {
    await admin.messaging().send({
      token: data.fcmToken,
      notification: { title, body },
      apns: { payload: { aps: { sound: "default" } } },
    });
    await doc.ref.update({
      lastNotifiedKey: alert.dedupKey,
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error(`FCM send failed for device ${doc.id}`, err);
  }
}
