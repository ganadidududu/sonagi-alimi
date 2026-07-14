import { test } from "node:test";
import assert from "node:assert/strict";
import { evaluateAlert, HourlySlot } from "./alertEvaluator";

function slot(hourLabel: string, condition: HourlySlot["condition"]): HourlySlot {
  return { hourLabel, condition };
}

function kst(y: number, m: number, d: number, h: number, min: number): Date {
  // Construct as if the wall-clock time were KST, then subtract the +9h
  // offset `alertEvaluator`'s helpers re-apply internally.
  return new Date(Date.UTC(y, m - 1, d, h, min) - 9 * 60 * 60 * 1000);
}

test("no alert when next two slots are dry", () => {
  const slots = [slot("지금", "cloudy"), slot("15시", "cloudy"), slot("16시", "sunny")];
  assert.equal(evaluateAlert(slots, kst(2026, 7, 8, 14, 30)), null);
});

test("shower detected in upcoming window", () => {
  const slots = [slot("지금", "cloudy"), slot("15시", "shower"), slot("16시", "shower")];
  const result = evaluateAlert(slots, kst(2026, 7, 8, 14, 30));
  assert.ok(result);
  assert.equal(result!.level.type, "shower");
});

test("rain takes the rain branch, not shower", () => {
  const slots = [slot("지금", "cloudy"), slot("15시", "rain"), slot("16시", "cloudy")];
  const result = evaluateAlert(slots, kst(2026, 7, 8, 14, 30));
  assert.equal(result!.level.type, "rain");
});

test("now-slot precipitation alone does not trigger (only upcoming counts)", () => {
  const slots = [slot("지금", "shower"), slot("15시", "sunny"), slot("16시", "sunny")];
  assert.equal(evaluateAlert(slots, kst(2026, 7, 8, 14, 30)), null);
});

test("dedup key is stable within the same hour, differs by day", () => {
  const slots = [slot("지금", "cloudy"), slot("15시", "shower")];
  const a = evaluateAlert(slots, kst(2026, 7, 8, 14, 5))!;
  const b = evaluateAlert(slots, kst(2026, 7, 8, 14, 55))!;
  assert.equal(a.dedupKey, b.dedupKey);

  const nextDay = evaluateAlert(slots, kst(2026, 7, 9, 14, 30))!;
  assert.notEqual(a.dedupKey, nextDay.dedupKey);
});
