import type { Conflict, ConflictOption, Event } from './types';

const CONFIDENCE_THRESHOLD = 0.72;

function overlaps(a: Event, b: Event): boolean {
  const as = Date.parse(a.start);
  const ae = Date.parse(a.end);
  const bs = Date.parse(b.start);
  const be = Date.parse(b.end);
  return as < be && bs < ae;
}

function crossDomainBoost(a: Event, b: Event): number {
  if (a.domain === b.domain) return -0.35; // same-domain overlaps are often intentional blocks
  const pair = new Set([a.domain, b.domain]);
  if (pair.has('work') && pair.has('family')) return 0.15;
  if (pair.has('work') && pair.has('birthday')) return 0.18;
  return 0.08;
}

function baseConfidence(a: Event, b: Event): number {
  const importance = (a.importance + b.importance) / 10;
  // low-importance same-domain noise must stay under threshold (宁可漏报)
  return Math.min(0.98, Math.max(0, 0.5 + importance + crossDomainBoost(a, b)));
}

function defaultOptions(a: Event, b: Event): ConflictOption[] {
  const familyish = [a, b].find((e) => e.domain === 'family' || e.domain === 'birthday');
  const workish = [a, b].find((e) => e.domain === 'work');
  const preferFamily = familyish ?? a;
  const preferWork = workish ?? b;

  return [
    {
      id: 'opt-a',
      lean: `倾向${preferFamily.title}`,
      bullets: [
        `给对方的请假/改约话术（已备好）`,
        `建议替代人同步结论`,
        `补偿：另约时间单独汇报/陪伴`,
      ],
      scripts: [`不好意思，当天有重要家庭安排，能否改期或请同事代我？`],
      basis: '依据：你过去对家庭关键日程到场率更高（可调整）',
      needsSignOff: true,
      tone: 'primary',
    },
    {
      id: 'opt-b',
      lean: '两头兼顾',
      bullets: [
        `调整${preferFamily.title}时段，错峰参加${preferWork.title}`,
        '分身已查路线可行性（Mock）',
      ],
      needsSignOff: false,
      tone: 'secondary',
    },
  ];
}

export interface DetectConflictsInput {
  events: Event[];
  now?: Date;
  /** days ahead to scan */
  horizonDays?: number;
}

export function detectConflicts(input: DetectConflictsInput): Conflict[] {
  const { events, now = new Date(), horizonDays = 14 } = input;
  const horizon = now.getTime() + horizonDays * 86400000;
  const candidates = events.filter((e) => {
    const t = Date.parse(e.start);
    return t >= now.getTime() - 3600000 && t <= horizon;
  });

  const out: Conflict[] = [];
  for (let i = 0; i < candidates.length; i++) {
    for (let j = i + 1; j < candidates.length; j++) {
      const a = candidates[i]!;
      const b = candidates[j]!;
      if (!overlaps(a, b)) continue;
      const confidence = baseConfidence(a, b);
      if (confidence < CONFIDENCE_THRESHOLD) continue;

      const start = new Date(Math.min(Date.parse(a.start), Date.parse(b.start)));
      const days = Math.floor((start.getTime() - now.getTime()) / 86400000);
      const stage = days <= 0 ? 'T-0' : days <= 3 ? 'T-3' : 'T-14';

      out.push({
        id: `c-${a.id}-${b.id}`,
        eventAId: a.id,
        eventBId: b.id,
        label: `${a.title} × ${b.title}`,
        confidence,
        stage,
        options: defaultOptions(a, b),
      });
    }
  }
  return out.sort((x, y) => y.confidence - x.confidence);
}

export { CONFIDENCE_THRESHOLD };
