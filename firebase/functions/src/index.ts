import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { evaluateAlert, parseHourlySlots, AlertResult, KmaFcstItem } from "./alertEvaluator";
import { ultraSrtFcstBaseTime, isWithinDndWindow } from "./kst";

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
  }
);

async function processGrid(
  gridKey: string,
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  serviceKey: string
): Promise<void> {
  const [nx, ny] = gridKey.split(",");
  const items = await fetchUltraSrtFcst(nx, ny, serviceKey);
  if (!items) return;

  const slots = parseHourlySlots(items);
  const alert = evaluateAlert(slots);
  if (!alert) return;

  await Promise.all(docs.map((doc) => notifyDevice(doc, alert)));
}

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
    ? `${alert.level.windowText}에 소나기가 지나가요. 약 ${alert.level.minutesUntil}분 뒤 시작 · 우산을 꼭 챙기세요 ☂️`
    : `${alert.level.windowText}에 비가 내려요. 약 ${alert.level.minutesUntil}분 뒤 시작 · 우산을 챙기세요 ☂️`;

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
