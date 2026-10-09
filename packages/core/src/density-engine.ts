import type { Event } from './types';

export interface WeekDensity {
  weekStart: string;
  count: number;
  overloaded: boolean;
  suggestMove: number;
}

function startOfWeek(d: Date): Date {
  const x = new Date(d);
  const day = x.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  x.setDate(x.getDate() + diff);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function computeDensity(
  events: Event[],
  overloadThreshold = 12,
): WeekDensity[] {
  const map = new Map<string, number>();
  for (const e of events) {
    const ws = startOfWeek(new Date(e.start)).toISOString().slice(0, 10);
    map.set(ws, (map.get(ws) ?? 0) + 1);
  }
  return [...map.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([weekStart, count]) => ({
      weekStart,
      count,
      overloaded: count >= overloadThreshold,
      suggestMove: count >= overloadThreshold ? Math.max(1, count - overloadThreshold + 2) : 0,
    }));
}

export function densityInsight(weeks: WeekDensity[]): string | null {
  const hit = weeks.find((w) => w.overloaded);
  if (!hit) return null;
  const d = new Date(hit.weekStart);
  const month = d.getMonth() + 1;
  const weekOfMonth = Math.ceil(d.getDate() / 7);
  return `密度热力：${month}月第${weekOfMonth}周过载，建议移出 ${hit.suggestMove} 项 →`;
}
