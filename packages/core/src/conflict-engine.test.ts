import { describe, expect, it } from 'vitest';
import { CONFIDENCE_THRESHOLD, detectConflicts } from './conflict-engine';
import type { Event } from './types';

const base = (over: Partial<Event> & Pick<Event, 'id' | 'title' | 'start' | 'end' | 'domain'>): Event => ({
  source: 'local',
  importance: 4,
  prepStatus: 'none',
  privacyLevel: 'L1',
  aiEligible: true,
  ...over,
});

describe('detectConflicts', () => {
  it('detects cross-domain overlap with high confidence', () => {
    const events = [
      base({
        id: 'a',
        title: '项目评审',
        start: '2026-10-09T15:00:00+08:00',
        end: '2026-10-09T16:00:00+08:00',
        domain: 'work',
      }),
      base({
        id: 'b',
        title: '家长会',
        start: '2026-10-09T15:30:00+08:00',
        end: '2026-10-09T16:30:00+08:00',
        domain: 'family',
        importance: 5,
      }),
    ];
    const now = new Date('2026-10-09T08:00:00+08:00');
    const conflicts = detectConflicts({ events, now });
    expect(conflicts.length).toBe(1);
    expect(conflicts[0]!.confidence).toBeGreaterThanOrEqual(CONFIDENCE_THRESHOLD);
    expect(conflicts[0]!.stage).toBe('T-0');
    expect(conflicts[0]!.options.length).toBe(2);
  });

  it('does not push low-confidence conflicts', () => {
    const events = [
      base({
        id: 'a',
        title: '低优 A',
        start: '2026-10-10T10:00:00+08:00',
        end: '2026-10-10T10:30:00+08:00',
        domain: 'study',
        importance: 1,
      }),
      base({
        id: 'b',
        title: '低优 B',
        start: '2026-10-10T10:15:00+08:00',
        end: '2026-10-10T10:45:00+08:00',
        domain: 'study',
        importance: 1,
      }),
    ];
    const now = new Date('2026-10-09T08:00:00+08:00');
    const conflicts = detectConflicts({ events, now });
    expect(conflicts.every((c) => c.confidence >= CONFIDENCE_THRESHOLD)).toBe(true);
    // same domain + low importance may fall under threshold
    expect(conflicts.length).toBe(0);
  });
});
