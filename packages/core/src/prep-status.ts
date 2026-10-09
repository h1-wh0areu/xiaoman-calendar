import type { Event, PrepStatus } from './types';

export function resolvePrepLabel(status: PrepStatus): string {
  switch (status) {
    case 'ready':
      return '√备';
    case 'pending_sign':
      return '待签发';
    case 'decision':
      return '决策';
    case 'conflict':
      return '!';
    default:
      return '';
  }
}

export function markConflicts(events: Event[], conflictEventIds: Set<string>): Event[] {
  return events.map((e) =>
    conflictEventIds.has(e.id) ? { ...e, prepStatus: 'conflict' as const } : e,
  );
}
