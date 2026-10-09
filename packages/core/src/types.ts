export type Domain =
  | 'work'
  | 'family'
  | 'document'
  | 'birthday'
  | 'study'
  | 'health';

export type PrepStatus =
  | 'ready'
  | 'pending_sign'
  | 'decision'
  | 'conflict'
  | 'none';

export type PrivacyLevel = 'L0' | 'L1' | 'L2' | 'L3';
export type TrustLevel = 'L1' | 'L2' | 'L3' | 'L4';
export type StorageMode = 'A' | 'B' | 'C';
export type ConflictStage = 'T-14' | 'T-3' | 'T-0';
export type CommitmentStatus = 'open' | 'done' | 'overdue';

export interface Event {
  id: string;
  title: string;
  start: string; // ISO
  end: string;
  domain: Domain;
  source: string;
  importance: number; // 1-5
  prepStatus: PrepStatus;
  privacyLevel: PrivacyLevel;
  aiEligible: boolean;
  location?: string;
  starred?: boolean;
  note?: string;
  personIds?: string[];
}

export interface ConflictOption {
  id: string;
  lean: string;
  bullets: string[];
  scripts?: string[];
  basis?: string;
  needsSignOff: boolean;
  tone: 'primary' | 'secondary';
}

export interface Conflict {
  id: string;
  eventAId: string;
  eventBId: string;
  label: string;
  confidence: number;
  stage: ConflictStage;
  options: ConflictOption[];
}

export interface PersonCard {
  id: string;
  name: string;
  traits: string[];
  lastObjection?: string;
  relationHint?: string;
}

export interface Commitment {
  id: string;
  who: string;
  what: string;
  dueAt: string;
  status: CommitmentStatus;
  linkedEventId?: string;
  draftLink?: string;
}

export interface DocumentRecord {
  id: string;
  type: string;
  title: string;
  expiryAt: string;
  holderName: string;
  localImageRef?: string;
  daysLeft: number;
}

export interface MedReminder {
  id: string;
  elderName: string;
  drug: string;
  dose: string;
  scheduleLabel: string;
  confirmState: 'pending' | 'confirmed' | 'missed' | 'escalated';
  voiceLocalRef?: string;
}

export interface BirthdayPlan {
  id: string;
  personName: string;
  dateLabel: string;
  script: string;
  gifts: Array<{ tier: string; title: string; reason: string; affiliate?: boolean }>;
  celebrateDefault: string;
  celebrateBackup: string;
  memoryBasis: string[];
}

export interface ReminderOffset {
  eventType: string;
  offsets: string[];
}

export interface OpLogEntry {
  id: string;
  actorId: string;
  op: string;
  entityType: string;
  entityId: string;
  payload: unknown;
  lamport: number;
  updatedAt: string;
}

export const DOMAIN_COLORS: Record<Domain, string> = {
  work: '#3B82F6',
  family: '#F59A23',
  document: '#E5484D',
  birthday: '#E879A9',
  study: '#22A06B',
  health: '#8B5CF6',
};

export const DOMAIN_LABELS: Record<Domain, string> = {
  work: '工作',
  family: '家庭',
  document: '证件',
  birthday: '生日',
  study: '学习',
  health: '健康',
};
