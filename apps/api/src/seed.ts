import { detectConflicts } from '@xiaoman/core';
import { db } from './store';
import type { Event } from './domain';

/** Anchor demo day: 2026-10-09 (matches prototypes) */
const DAY = '2026-10-09';

export function seedDemo(): void {
  db.users = [
    {
      id: 'u-demo',
      phone: '13800138000',
      trustLevel: 'L1',
      storageMode: 'A',
      personaSliders: { family: 70, work: 55, friends: 60 },
      displayName: '小满用户',
    },
  ];
  db.tokens.clear();
  db.signOffs = [];
  db.ops = [];
  db.lamport = 0;

  const events: Event[] = [
    {
      id: 'e-morning',
      title: '晨会 · 小抄已备',
      start: `${DAY}T09:30:00+08:00`,
      end: `${DAY}T10:00:00+08:00`,
      domain: 'work',
      source: 'dingtalk',
      importance: 3,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
      location: '会议室B',
      personIds: ['p-wang', 'p-li'],
    },
    {
      id: 'e-lunch',
      title: '与母亲午餐 · 生日礼物已订',
      start: `${DAY}T12:00:00+08:00`,
      end: `${DAY}T13:30:00+08:00`,
      domain: 'birthday',
      source: 'local',
      importance: 4,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-review',
      title: '项目评审',
      start: `${DAY}T15:00:00+08:00`,
      end: `${DAY}T16:00:00+08:00`,
      domain: 'work',
      source: 'outlook',
      importance: 5,
      prepStatus: 'decision',
      privacyLevel: 'L1',
      aiEligible: true,
      location: '会议室A / 腾讯会议',
      starred: true,
      personIds: ['p-wang', 'p-li', 'p-chen'],
    },
    {
      id: 'e-parent',
      title: '家长会（冲突中）',
      start: `${DAY}T15:30:00+08:00`,
      end: `${DAY}T16:30:00+08:00`,
      domain: 'family',
      source: 'local',
      importance: 5,
      prepStatus: 'conflict',
      privacyLevel: 'L1',
      aiEligible: true,
      location: '实验小学',
    },
    {
      id: 'e-med',
      title: '服药提醒 · 爸（电话外呼）',
      start: `${DAY}T19:00:00+08:00`,
      end: `${DAY}T19:10:00+08:00`,
      domain: 'health',
      source: 'local',
      importance: 5,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-study',
      title: '复习计划 · 英语 40min',
      start: `${DAY}T21:00:00+08:00`,
      end: `${DAY}T21:40:00+08:00`,
      domain: 'study',
      source: 'local',
      importance: 3,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-dinner-work',
      title: '部门聚餐（王总组织）',
      start: '2026-11-14T19:00:00+08:00',
      end: '2026-11-14T21:00:00+08:00',
      domain: 'work',
      source: 'dingtalk',
      importance: 4,
      prepStatus: 'none',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-mom-bday',
      title: '妈妈生日晚宴',
      start: '2026-11-14T19:00:00+08:00',
      end: '2026-11-14T21:30:00+08:00',
      domain: 'birthday',
      source: 'local',
      importance: 5,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
      starred: true,
    },
    {
      id: 'e-launch',
      title: '项目上线',
      start: '2026-10-26T10:00:00+08:00',
      end: '2026-10-26T12:00:00+08:00',
      domain: 'work',
      source: 'feishu',
      importance: 5,
      prepStatus: 'none',
      privacyLevel: 'L1',
      aiEligible: true,
      starred: true,
    },
    {
      id: 'e-visit',
      title: '复诊·妈',
      start: '2026-10-12T09:00:00+08:00',
      end: '2026-10-12T10:00:00+08:00',
      domain: 'health',
      source: 'local',
      importance: 4,
      prepStatus: 'ready',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-license',
      title: '驾驶证到期·剩1个月',
      start: '2026-11-05T09:00:00+08:00',
      end: '2026-11-05T09:30:00+08:00',
      domain: 'document',
      source: 'local',
      importance: 5,
      prepStatus: 'none',
      privacyLevel: 'L0',
      aiEligible: true,
      starred: true,
    },
    {
      id: 'e-trip',
      title: '出差·深圳',
      start: '2026-11-20T08:00:00+08:00',
      end: '2026-11-20T20:00:00+08:00',
      domain: 'work',
      source: 'outlook',
      importance: 4,
      prepStatus: 'none',
      privacyLevel: 'L1',
      aiEligible: true,
    },
    {
      id: 'e-exam',
      title: '科目二考试',
      start: '2026-12-01T09:00:00+08:00',
      end: '2026-12-01T11:00:00+08:00',
      domain: 'study',
      source: 'local',
      importance: 5,
      prepStatus: 'none',
      privacyLevel: 'L1',
      aiEligible: true,
      starred: true,
      location: '西丽考场',
    },
    {
      id: 'e-passport',
      title: '护照有效期<6个月',
      start: '2026-12-24T09:00:00+08:00',
      end: '2026-12-24T09:30:00+08:00',
      domain: 'document',
      source: 'local',
      importance: 5,
      prepStatus: 'none',
      privacyLevel: 'L0',
      aiEligible: true,
      starred: true,
    },
    {
      id: 'e-bonus',
      title: '年终奖评审',
      start: '2026-12-31T14:00:00+08:00',
      end: '2026-12-31T16:00:00+08:00',
      domain: 'work',
      source: 'dingtalk',
      importance: 5,
      prepStatus: 'none',
      privacyLevel: 'L3',
      aiEligible: false,
      starred: true,
    },
  ];

  db.events = events;
  db.conflicts = detectConflicts({
    events,
    now: new Date(`${DAY}T08:00:00+08:00`),
    horizonDays: 45,
  }).map((c) => {
    if (c.eventAId === 'e-dinner-work' || c.eventBId === 'e-dinner-work') {
      return {
        ...c,
        id: 'c-nov14',
        label: '部门聚餐（王总组织） × 妈妈生日晚宴',
        stage: 'T-14' as const,
        options: [
          {
            id: 'opt-a',
            lean: '倾向生日宴',
            bullets: [
              '给王总的请假话术（已备好）',
              '建议替代人：小陈代你敬酒+同步结论',
              '补偿：周一单独汇报项目进展',
            ],
            scripts: ['王总，14号晚上家母寿宴，能否请假？小陈可代我敬酒并同步结论。'],
            basis: '依据：你过去3年家人生日均到场（可调整）',
            needsSignOff: true,
            tone: 'primary' as const,
          },
          {
            id: 'opt-b',
            lean: '两头兼顾',
            bullets: [
              '生日宴提前至17:30，聚餐20:30到场',
              '分身已查路线：车程38分钟，可行',
            ],
            needsSignOff: false,
            tone: 'secondary' as const,
          },
        ],
      };
    }
    if (c.eventAId === 'e-review' || c.eventBId === 'e-review') {
      return {
        ...c,
        id: 'c-today',
        label: '15:00 项目评审 撞 家长会',
        stage: 'T-0' as const,
      };
    }
    return c;
  });

  db.people = [
    {
      id: 'p-wang',
      name: '王总',
      traits: ['决策快', '反感超预算'],
    },
    {
      id: 'p-li',
      name: '李经理',
      traits: [],
      lastObjection: '上次异议：排期太紧',
    },
    {
      id: 'p-chen',
      name: '小陈',
      traits: [],
      relationHint: '你带的下属 · 可助攻',
    },
  ];

  db.commitments = [
    {
      id: 'cm-1',
      who: '你',
      what: '本周给出成本测算',
      dueAt: `${DAY}T18:00:00+08:00`,
      status: 'open',
      linkedEventId: 'e-review',
      draftLink: '/drafts/cost',
    },
  ];

  db.documents = [
    {
      id: 'doc-passport',
      type: 'passport',
      title: '护照',
      expiryAt: '2027-03-01',
      holderName: '本人',
      daysLeft: 144,
      localImageRef: 'local://docs/passport.enc',
    },
    {
      id: 'doc-license',
      type: 'driver_license',
      title: '驾驶证',
      expiryAt: '2026-11-05',
      holderName: '本人',
      daysLeft: 28,
      localImageRef: 'local://docs/license.enc',
    },
  ];

  db.meds = [
    {
      id: 'med-dad',
      elderName: '爸',
      drug: '降压药',
      dose: '1片',
      scheduleLabel: '每日 19:00',
      confirmState: 'pending',
      voiceLocalRef: 'local://voice/dad-med.m4a',
    },
  ];

  db.birthdayPlans = [
    {
      id: 'bp-mom',
      personName: '妈妈',
      dateLabel: '11月14日',
      script:
        '妈，又一年了。谢谢你一直把家撑得那么稳。今晚我想好好陪你吃顿饭——蛋糕我订好了，你只管开心。',
      gifts: [
        {
          tier: '心意档',
          title: '烘焙体验课',
          reason: '她去年提过想学烘焙',
          affiliate: true,
        },
        {
          tier: '体面档',
          title: '羊绒围巾',
          reason: '冬季实用，颜色偏她常穿的米杏',
        },
        {
          tier: '隆重档',
          title: '家庭周末短途',
          reason: '你上次说想带她出去走走',
        },
      ],
      celebrateDefault: '家里晚宴 + 蛋糕（已查附近可预订）',
      celebrateBackup: '餐厅包间（若家里忙不过来）',
      memoryBasis: ['爱好：烘焙', '忌口：不吃太甜（已纠错过一次）', '历史：去年围巾好评'],
    },
  ];

  db.families = [
    {
      id: 'fam-1',
      name: '我家',
      members: [
        { userId: 'u-demo', name: '我', role: 'admin' },
        { userId: 'u-dad', name: '爸', role: 'elder' },
        { userId: 'u-mom', name: '妈', role: 'elder' },
      ],
      claims: [
        { id: 'cl-1', title: '周六接娃放学', claimant: undefined },
        { id: 'cl-2', title: '妈生日订蛋糕', claimant: '我' },
      ],
    },
  ];

  db.syncSources = [
    { id: 'src-ding', name: '钉钉日程', connected: true, lastSyncAt: `${DAY}T07:00:00+08:00` },
    { id: 'src-outlook', name: 'Outlook', connected: true, lastSyncAt: `${DAY}T07:05:00+08:00` },
    { id: 'src-feishu', name: '飞书日历', connected: false },
    { id: 'src-google', name: 'Google 日历', connected: false },
  ];
}
