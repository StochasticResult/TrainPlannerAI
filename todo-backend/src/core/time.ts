import * as chrono from "chrono-node";

export function parseHumanDate(input: string, baseDate: Date) {
  const results = chrono.parse(input, baseDate, { forwardDate: true });
  if (!results || results.length === 0) return null;
  const r = results[0];
  const d = r.date();
  const isoDate = d.toISOString();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return {
    date: `${y}-${m}-${day}`,
    time: `${hh}:${mm}`,
    datetime: `${y}-${m}-${day} ${hh}:${mm}`,
    iso: isoDate
  };
}

export function ensureTimeOrDefault(time: string | null | undefined, defaultHM = "09:00"): string {
  return time && /^\d{2}:\d{2}$/.test(time) ? time : defaultHM;
}

