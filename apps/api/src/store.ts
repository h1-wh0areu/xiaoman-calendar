import type {
  BirthdayPlan,
  Commitment,
  Conflict,
  DocumentRecord,
  Event,
  MedReminder,
  PersonCard,
  SignOffTicket,
  OpLogEntry,
} from './domain';

export interface UserRecord {
  id: string;
  phone: string;
  trustLevel: 'L1' | 'L2' | 'L3' | 'L4';
  storageMode: 'A' | 'B' | 'C';
  personaSliders: { family: number; work: number; friends: number };
  displayName: string;
}

export interface FamilyMember {
  userId: string;
  name: string;
  role: string;
}

export interface FamilyGroup {
  id: string;
  name: string;
  members: FamilyMember[];
  claims: Array<{ id: string; title: string; claimant?: string }>;
}

export interface SyncSource {
  id: string;
  name: string;
  connected: boolean;
  lastSyncAt?: string;
}

export interface Db {
  users: UserRecord[];
  tokens: Map<string, string>; // token -> userId
  events: Event[];
  conflicts: Conflict[];
  commitments: Commitment[];
  people: PersonCard[];
  documents: DocumentRecord[];
  meds: MedReminder[];
  birthdayPlans: BirthdayPlan[];
  signOffs: SignOffTicket[];
  families: FamilyGroup[];
  syncSources: SyncSource[];
  ops: OpLogEntry[];
  lamport: number;
}

export const db: Db = {
  users: [],
  tokens: new Map(),
  events: [],
  conflicts: [],
  commitments: [],
  people: [],
  documents: [],
  meds: [],
  birthdayPlans: [],
  signOffs: [],
  families: [],
  syncSources: [],
  ops: [],
  lamport: 0,
};

export function nextLamport(): number {
  db.lamport += 1;
  return db.lamport;
}
