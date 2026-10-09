export type {
  BirthdayPlan,
  Commitment,
  Conflict,
  ConflictOption,
  DocumentRecord,
  Event,
  MedReminder,
  OpLogEntry,
  PersonCard,
  PrepStatus,
  Domain,
} from '@xiaoman/core';

export interface SignOffTicket {
  id: string;
  content: string;
  toneScore: number;
  memoryRefs: string[];
  handwrittenNote?: string;
  status: 'pending' | 'approved' | 'rejected';
  conflictId?: string;
  optionId?: string;
  createdAt: string;
}
