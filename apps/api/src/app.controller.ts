import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  buildMorningBrief,
  computeDensity,
  densityInsight,
  parseClipboard,
} from '@xiaoman/core';
import { v4 as uuid } from 'uuid';
import { AuthGuard } from './auth.guard';
import type { Event, SignOffTicket } from './domain';
import { seedDemo } from './seed';
import { db, nextLamport } from './store';

const DEV_CODE = '000000';

@Controller()
export class AppController {
  @Post('auth/sms/send')
  sendSms(@Body() body: { phone?: string }) {
    if (!body.phone) return { ok: false, message: 'phone required' };
    return { ok: true, message: '验证码已发送（开发环境固定 000000）' };
  }

  @Post('auth/sms/verify')
  verify(@Body() body: { phone?: string; code?: string }) {
    if (!body.phone || body.code !== DEV_CODE) {
      return { ok: false, message: '验证码错误' };
    }
    let user = db.users.find((u) => u.phone === body.phone);
    if (!user) {
      user = {
        id: uuid(),
        phone: body.phone,
        trustLevel: 'L1',
        storageMode: 'A',
        personaSliders: { family: 50, work: 50, friends: 50 },
        displayName: '新用户',
      };
      db.users.push(user);
    }
    const accessToken = `tok_${uuid()}`;
    db.tokens.set(accessToken, user.id);
    return { ok: true, accessToken, user };
  }

  @Get('health')
  health() {
    return { ok: true, service: 'xiaoman-api', events: db.events.length };
  }

  @Post('dev/reseed')
  reseed() {
    seedDemo();
    return { ok: true, events: db.events.length, conflicts: db.conflicts.length };
  }

  @UseGuards(AuthGuard)
  @Get('me')
  me(@Req() req: { userId: string }) {
    return db.users.find((u) => u.id === req.userId);
  }

  @UseGuards(AuthGuard)
  @Patch('me')
  patchMe(
    @Req() req: { userId: string },
    @Body()
    body: Partial<{
      storageMode: 'A' | 'B' | 'C';
      personaSliders: { family: number; work: number; friends: number };
      displayName: string;
    }>,
  ) {
    const user = db.users.find((u) => u.id === req.userId)!;
    Object.assign(user, body);
    return user;
  }

  @UseGuards(AuthGuard)
  @Get('brief/morning')
  morning(@Query('date') date?: string) {
    const d = date ? new Date(date) : new Date('2026-10-09T08:00:00+08:00');
    return buildMorningBrief(db.events, db.conflicts, d);
  }

  @UseGuards(AuthGuard)
  @Get('events')
  listEvents() {
    return db.events;
  }

  @UseGuards(AuthGuard)
  @Get('events/:id')
  getEvent(@Param('id') id: string) {
    return db.events.find((e) => e.id === id) ?? { error: 'not found' };
  }

  @UseGuards(AuthGuard)
  @Post('events')
  createEvent(@Body() body: Partial<Event>) {
    const event: Event = {
      id: body.id ?? uuid(),
      title: body.title ?? '未命名日程',
      start: body.start ?? new Date().toISOString(),
      end: body.end ?? new Date(Date.now() + 3600000).toISOString(),
      domain: body.domain ?? 'work',
      source: body.source ?? 'local',
      importance: body.importance ?? 3,
      prepStatus: body.prepStatus ?? 'none',
      privacyLevel: body.privacyLevel ?? 'L1',
      aiEligible: body.aiEligible ?? true,
      location: body.location,
      starred: body.starred,
      note: body.note,
      personIds: body.personIds,
    };
    db.events.push(event);
    db.ops.push({
      id: uuid(),
      actorId: 'u-demo',
      op: 'upsert',
      entityType: 'event',
      entityId: event.id,
      payload: event,
      lamport: nextLamport(),
      updatedAt: new Date().toISOString(),
    });
    return event;
  }

  @UseGuards(AuthGuard)
  @Post('events/from-clipboard')
  fromClipboard(@Body() body: { text?: string }) {
    const parsed = parseClipboard(body.text ?? '');
    if (!parsed) return { ok: false, message: '未识别到日程信息' };
    // privacy: do not store original text
    return { ok: true, draft: parsed };
  }

  @UseGuards(AuthGuard)
  @Get('timeline')
  timeline(@Query('months') months = '3') {
    const m = Number(months) || 3;
    const now = new Date('2026-10-09T00:00:00+08:00');
    const end = new Date(now);
    end.setMonth(end.getMonth() + m);
    const items = db.events
      .filter((e) => {
        const t = Date.parse(e.start);
        return t >= now.getTime() && t <= end.getTime() && (e.starred || e.importance >= 4);
      })
      .sort((a, b) => Date.parse(a.start) - Date.parse(b.start));
    const weeks = computeDensity(db.events);
    return { items, insight: densityInsight(weeks), months: m };
  }

  @UseGuards(AuthGuard)
  @Get('conflicts')
  conflicts() {
    return db.conflicts;
  }

  @UseGuards(AuthGuard)
  @Get('conflicts/:id')
  conflict(@Param('id') id: string) {
    return db.conflicts.find((c) => c.id === id) ?? { error: 'not found' };
  }

  @UseGuards(AuthGuard)
  @Post('conflicts/:id/choose')
  choose(
    @Param('id') id: string,
    @Body() body: { optionId?: string },
  ) {
    const conflict = db.conflicts.find((c) => c.id === id);
    if (!conflict) return { error: 'not found' };
    const option = conflict.options.find((o) => o.id === body.optionId);
    if (!option) return { error: 'option not found' };

    if (option.needsSignOff) {
      const ticket: SignOffTicket = {
        id: uuid(),
        content: (option.scripts ?? option.bullets).join('\n'),
        toneScore: 0.86,
        memoryRefs: option.basis ? [option.basis] : [],
        status: 'pending',
        conflictId: conflict.id,
        optionId: option.id,
        createdAt: new Date().toISOString(),
      };
      db.signOffs.push(ticket);
      return { ok: true, needsSignOff: true, ticket };
    }
    return { ok: true, needsSignOff: false, applied: option };
  }

  @UseGuards(AuthGuard)
  @Get('sign-off/:id')
  getSignOff(@Param('id') id: string) {
    return db.signOffs.find((s) => s.id === id) ?? { error: 'not found' };
  }

  @UseGuards(AuthGuard)
  @Post('sign-off/:id/approve')
  approveSignOff(
    @Param('id') id: string,
    @Body() body: { handwrittenNote?: string },
  ) {
    const ticket = db.signOffs.find((s) => s.id === id);
    if (!ticket) return { error: 'not found' };
    ticket.status = 'approved';
    ticket.handwrittenNote = body.handwrittenNote;
    return { ok: true, ticket, message: '已签发并执行（Mock）' };
  }

  @UseGuards(AuthGuard)
  @Post('sign-off/:id/reject')
  rejectSignOff(@Param('id') id: string) {
    const ticket = db.signOffs.find((s) => s.id === id);
    if (!ticket) return { error: 'not found' };
    ticket.status = 'rejected';
    return { ok: true, ticket };
  }

  @UseGuards(AuthGuard)
  @Get('events/:id/cheat-sheet')
  cheatSheet(@Param('id') id: string) {
    const event = db.events.find((e) => e.id === id);
    if (!event) return { error: 'not found' };
    if (!event.aiEligible) {
      return {
        event,
        blocked: true,
        message: '企业域日程仅时间占位，不进入 AI 管道',
      };
    }
    const people = db.people.filter((p) => event.personIds?.includes(p.id));
    const commitments = db.commitments.filter((c) => c.linkedEventId === id);
    return {
      event,
      title: '会前小抄 · 20分钟后',
      people,
      commitments,
      strategy: '先讲成本测算结果，再谈排期让步空间。',
      dataNote: '数据来源：日历订阅+你上传的纪要 · 不读取聊天',
    };
  }

  @UseGuards(AuthGuard)
  @Get('commitments')
  commitments() {
    return db.commitments;
  }

  @UseGuards(AuthGuard)
  @Get('families')
  families() {
    return db.families;
  }

  @UseGuards(AuthGuard)
  @Post('families/:id/claims/:claimId/claim')
  claim(
    @Param('id') id: string,
    @Param('claimId') claimId: string,
    @Body() body: { name?: string },
  ) {
    const fam = db.families.find((f) => f.id === id);
    const claim = fam?.claims.find((c) => c.id === claimId);
    if (!claim) return { error: 'not found' };
    claim.claimant = body.name ?? '我';
    return { ok: true, claim };
  }

  @UseGuards(AuthGuard)
  @Get('med-reminders')
  meds() {
    return db.meds;
  }

  @UseGuards(AuthGuard)
  @Post('med-reminders/:id/confirm')
  confirmMed(@Param('id') id: string) {
    const med = db.meds.find((m) => m.id === id);
    if (!med) return { error: 'not found' };
    med.confirmState = 'confirmed';
    return { ok: true, med, channel: 'mock_outbound_keypress_1' };
  }

  @UseGuards(AuthGuard)
  @Post('med-reminders/:id/escalate')
  escalateMed(@Param('id') id: string) {
    const med = db.meds.find((m) => m.id === id);
    if (!med) return { error: 'not found' };
    med.confirmState = 'escalated';
    return { ok: true, med, notified: ['子女', '紧急联系人'] };
  }

  @UseGuards(AuthGuard)
  @Get('documents')
  documents() {
    return db.documents.map(({ localImageRef: _omit, ...rest }) => rest);
  }

  @UseGuards(AuthGuard)
  @Get('documents/:id/alert')
  docAlert(@Param('id') id: string) {
    const doc = db.documents.find((d) => d.id === id);
    if (!doc) return { error: 'not found' };
    return {
      document: {
        id: doc.id,
        type: doc.type,
        title: doc.title,
        expiryAt: doc.expiryAt,
        holderName: doc.holderName,
        daysLeft: doc.daysLeft,
      },
      stages: ['T-180', 'T-90', 'T-30', 'T-7'],
      guide: {
        where: '当地车管所 / 交管12123',
        bring: ['原件', '体检报告', '一寸照片'],
        online: true,
        etaHours: 2,
        feeRange: '10–50元',
        updatedAt: '2026-09-01',
      },
      cta: '一键生成办理日程',
    };
  }

  @UseGuards(AuthGuard)
  @Post('documents/:id/schedule')
  scheduleDoc(
    @Param('id') id: string,
    @Body() body: { start?: string },
  ) {
    const doc = db.documents.find((d) => d.id === id);
    if (!doc) return { error: 'not found' };
    const start = body.start ?? '2026-10-11T09:00:00+08:00';
    const event: Event = {
      id: uuid(),
      title: `办理${doc.title}：带旧证+体检报告+照片`,
      start,
      end: new Date(Date.parse(start) + 2 * 3600000).toISOString(),
      domain: 'document',
      source: 'local',
      importance: 4,
      prepStatus: 'ready',
      privacyLevel: 'L0',
      aiEligible: true,
    };
    db.events.push(event);
    return { ok: true, event };
  }

  @UseGuards(AuthGuard)
  @Get('birthday-plans/:id')
  birthday(@Param('id') id: string) {
    return db.birthdayPlans.find((b) => b.id === id) ?? { error: 'not found' };
  }

  @UseGuards(AuthGuard)
  @Get('sync/sources')
  syncSources() {
    return db.syncSources;
  }

  @UseGuards(AuthGuard)
  @Post('sync/run')
  syncRun() {
    for (const s of db.syncSources.filter((x) => x.connected)) {
      s.lastSyncAt = new Date().toISOString();
    }
    return { ok: true, sources: db.syncSources, message: 'Mock 增量同步完成' };
  }

  @UseGuards(AuthGuard)
  @Get('ops/since')
  opsSince(@Query('cursor') cursor?: string) {
    const c = Number(cursor ?? 0);
    const items = db.ops.filter((o) => o.lamport > c);
    return { items, cursor: db.lamport };
  }

  @UseGuards(AuthGuard)
  @Post('ops/push')
  opsPush(@Body() body: { ops?: unknown[] }) {
    return { ok: true, accepted: body.ops?.length ?? 0, cursor: db.lamport };
  }

  @UseGuards(AuthGuard)
  @Post('me/export')
  exportMe() {
    return {
      ok: true,
      formats: ['ical', 'json'],
      payload: { events: db.events, commitments: db.commitments },
    };
  }

  @UseGuards(AuthGuard)
  @Post('me/destroy')
  destroyMe(@Req() req: { userId: string }) {
    return {
      ok: true,
      message: '销毁请求已受理，云端+备份将于 30 天内物理删除并出具回执',
      userId: req.userId,
    };
  }

  @UseGuards(AuthGuard)
  @Get('avatar/stats')
  avatarStats() {
    return {
      trustLevel: 'L1',
      month: {
        cheatSheets: 12,
        delegates: 2,
        commitmentsClosed: 5,
        conflictsCaught: 3,
        medDays: 28,
        docIntercepts: 1,
        importantDays: 4,
      },
    };
  }
}
