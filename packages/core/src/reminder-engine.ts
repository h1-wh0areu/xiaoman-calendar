export interface ReminderRule {
  eventType: string;
  offsets: string[];
}

/** PRD §3.17 defaults */
export const DEFAULT_REMINDER_RULES: ReminderRule[] = [
  { eventType: 'critical_meeting', offsets: ['T-1d', 'T-1h', 'T-20m'] },
  { eventType: 'meeting', offsets: ['T-20m'] },
  { eventType: 'document', offsets: ['T-90d', 'T-30d', 'T-7d'] },
  { eventType: 'birthday', offsets: ['T-14d', 'T-7d', 'T-1d', 'D0-09:00'] },
  { eventType: 'medication', offsets: ['on-time'] },
  { eventType: 'exam', offsets: ['T-14d', 'T-7d', 'T-1d', 'D0'] },
  { eventType: 'travel', offsets: ['T-1d', 'T-3h'] },
  { eventType: 'payment', offsets: ['T-3d', 'D0'] },
];

const SAFETY_TYPES = new Set(['medication', 'document_overdue', 'conflict_t0']);

export function offsetsFor(eventType: string, rules = DEFAULT_REMINDER_RULES): string[] {
  return rules.find((r) => r.eventType === eventType)?.offsets ?? ['T-20m'];
}

/** Adaptive nudge: if user always opens late, add earlier offset */
export function adaptOffsets(
  offsets: string[],
  avgOpenLeadMinutes: number,
): string[] {
  if (avgOpenLeadMinutes >= 0 && avgOpenLeadMinutes < 30 && !offsets.includes('T-2h')) {
    return ['T-2h', ...offsets];
  }
  return offsets;
}

export interface ReminderItem {
  id: string;
  eventId: string;
  eventType: string;
  title: string;
  fireAtHint: string;
  safety: boolean;
}

/** Batch non-safety reminders in same hour window */
export function batchReminders(items: ReminderItem[]): Array<{
  batchId: string;
  titles: string[];
  items: ReminderItem[];
}> {
  const safety = items.filter((i) => i.safety || SAFETY_TYPES.has(i.eventType));
  const normal = items.filter((i) => !i.safety && !SAFETY_TYPES.has(i.eventType));
  const batches: Array<{ batchId: string; titles: string[]; items: ReminderItem[] }> = [];

  for (const s of safety) {
    batches.push({ batchId: `safe-${s.id}`, titles: [s.title], items: [s] });
  }

  if (normal.length) {
    const byHint = new Map<string, ReminderItem[]>();
    for (const n of normal) {
      const list = byHint.get(n.fireAtHint) ?? [];
      list.push(n);
      byHint.set(n.fireAtHint, list);
    }
    for (const [hint, group] of byHint) {
      batches.push({
        batchId: `batch-${hint}`,
        titles: group.map((g) => g.title),
        items: group,
      });
    }
  }
  return batches;
}
