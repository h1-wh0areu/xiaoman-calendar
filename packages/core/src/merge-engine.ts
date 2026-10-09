import type { OpLogEntry } from './types';

export interface Mergeable {
  id: string;
  updatedAt: string;
  source?: string;
  [key: string]: unknown;
}

export interface MergeResult<T extends Mergeable> {
  items: T[];
  winners: Array<{ id: string; reason: string }>;
}

/**
 * Last-write-wins with optional source priority (higher wins ties).
 */
export function mergeByLww<T extends Mergeable>(
  local: T[],
  remote: T[],
  sourcePriority: Record<string, number> = {},
): MergeResult<T> {
  const map = new Map<string, T>();
  const winners: Array<{ id: string; reason: string }> = [];

  const consider = (item: T, reason: string) => {
    const prev = map.get(item.id);
    if (!prev) {
      map.set(item.id, item);
      winners.push({ id: item.id, reason });
      return;
    }
    const pt = Date.parse(prev.updatedAt);
    const it = Date.parse(item.updatedAt);
    if (it > pt) {
      map.set(item.id, item);
      winners.push({ id: item.id, reason: 'newer' });
      return;
    }
    if (it === pt) {
      const ps = sourcePriority[prev.source ?? ''] ?? 0;
      const is = sourcePriority[item.source ?? ''] ?? 0;
      if (is > ps) {
        map.set(item.id, item);
        winners.push({ id: item.id, reason: 'source-priority' });
      }
    }
  };

  for (const l of local) consider(l, 'local');
  for (const r of remote) consider(r, 'remote');

  return { items: [...map.values()], winners };
}

export function applyOps<T extends Mergeable>(
  base: T[],
  ops: OpLogEntry[],
  apply: (items: T[], op: OpLogEntry) => T[],
): T[] {
  const sorted = [...ops].sort((a, b) => a.lamport - b.lamport);
  return sorted.reduce((acc, op) => apply(acc, op), base);
}
