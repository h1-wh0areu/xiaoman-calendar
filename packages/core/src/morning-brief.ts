import type { Conflict, Event } from './types';
import { DOMAIN_COLORS } from './types';

export interface BriefItem {
  event: Event;
  color: string;
  badge: string;
  badgeTone: 'ready' | 'decision' | 'conflict';
}

export interface MorningBrief {
  title: string;
  subtitle: string;
  conflictBanner?: { count: number; summary: string; conflictId: string };
  items: BriefItem[];
  closing: string;
}

function badgeFor(e: Event): { badge: string; badgeTone: BriefItem['badgeTone'] } {
  if (e.prepStatus === 'conflict') return { badge: '!', badgeTone: 'conflict' };
  if (e.prepStatus === 'decision') return { badge: '决策', badgeTone: 'decision' };
  if (e.prepStatus === 'ready' || e.prepStatus === 'pending_sign') {
    return { badge: '备', badgeTone: 'ready' };
  }
  return { badge: '备', badgeTone: 'ready' };
}

function formatSubtitle(date: Date, count: number): string {
  const week = ['日', '一', '二', '三', '四', '五', '六'][date.getDay()];
  return `${date.getMonth() + 1}月${date.getDate()}日 周${week} · 今天 ${count} 条日程`;
}

export function buildMorningBrief(
  events: Event[],
  conflicts: Conflict[],
  date = new Date(),
): MorningBrief {
  const dayStart = new Date(date);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(dayStart);
  dayEnd.setDate(dayEnd.getDate() + 1);

  const todays = events
    .filter((e) => {
      const t = Date.parse(e.start);
      return t >= dayStart.getTime() && t < dayEnd.getTime();
    })
    .sort((a, b) => Date.parse(a.start) - Date.parse(b.start));

  const t0 = conflicts.filter((c) => c.stage === 'T-0');
  const banner =
    t0.length > 0
      ? {
          count: t0.length,
          summary: t0[0]!.label + (t0[0]!.stage === 'T-0' ? '（T-0 决策）' : ''),
          conflictId: t0[0]!.id,
        }
      : conflicts.length > 0
        ? {
            count: conflicts.length,
            summary: conflicts[0]!.label,
            conflictId: conflicts[0]!.id,
          }
        : undefined;

  return {
    title: '早安 · 今日值班报告',
    subtitle: formatSubtitle(date, todays.length),
    conflictBanner: banner
      ? {
          count: banner.count,
          summary: banner.summary,
          conflictId: banner.conflictId,
        }
      : undefined,
    items: todays.map((event) => {
      const { badge, badgeTone } = badgeFor(event);
      return {
        event,
        color: DOMAIN_COLORS[event.domain],
        badge,
        badgeTone,
      };
    }),
    closing: '其余的，我都备好了。',
  };
}
