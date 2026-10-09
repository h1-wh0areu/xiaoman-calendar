import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class CheatSheetScreen extends StatefulWidget {
  const CheatSheetScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<CheatSheetScreen> createState() => _CheatSheetScreenState();
}

class _CheatSheetScreenState extends State<CheatSheetScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    final res = await api.get('/events/${widget.eventId}/cheat-sheet') as Map<String, dynamic>;
    setState(() => data = res);
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final people = (data!['people'] as List?) ?? [];
    final commitments = (data!['commitments'] as List?) ?? [];
    final event = Map<String, dynamic>.from(data!['event'] as Map);
    final start = DateTime.parse(event['start'] as String).toLocal();
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('会前小抄')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(data!['title'] as String? ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('$time ${event['title']} · ${event['location'] ?? ''}',
              style: const TextStyle(color: XmColors.textSecondary)),
          const Divider(height: 28),
          _Card(
            title: '参会人物卡',
            child: Column(
              children: [
                for (final p in people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p['name']}：${(p['traits'] as List?)?.join(' · ') ?? ''}${p['lastObjection'] ?? ''}${p['relationHint'] ?? ''}',
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (commitments.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: XmColors.conflict),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠ 待兑现承诺',
                      style: TextStyle(color: XmColors.conflict, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '上次评审你答应王总：${commitments.first['what']} -> 附草稿',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _Card(
            title: '一句话策略',
            titleColor: XmColors.primary,
            child: Text(data!['strategy'] as String? ?? '', style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 16),
          Text(data!['dataNote'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: XmColors.textSecondary)),
        ],
      ),
    );
  }
}

class ConflictScreen extends StatefulWidget {
  const ConflictScreen({super.key, required this.id});
  final String id;

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<AppState>().api.get('/conflicts/${widget.id}') as Map<String, dynamic>;
    setState(() => data = res);
  }

  Future<void> _choose(String optionId) async {
    final api = context.read<AppState>().api;
    final res = await api.post('/conflicts/${widget.id}/choose', {'optionId': optionId});
    if (!mounted) return;
    if (res['needsSignOff'] == true) {
      final ticketId = (res['ticket'] as Map)['id'];
      Navigator.of(context).pushNamed('/sign-off/$ticketId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已选择方案B（无需签发）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['error'] != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final options = (data!['options'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('冲突仲裁')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('冲突仲裁 · 需要你决定',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: XmColors.danger),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✕ ${data!['stage']} 冲突',
                    style: const TextStyle(color: XmColors.danger, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(data!['label'] as String? ?? '', style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final raw in options)
            _OptionCard(
              option: Map<String, dynamic>.from(raw as Map),
              onTap: () => _choose(raw['id'] as String),
            ),
          const SizedBox(height: 16),
          const Center(
            child: Text('建议权在AI，决定权在你。',
                style: TextStyle(fontWeight: FontWeight.w600, color: XmColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.onTap});
  final Map<String, dynamic> option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = option['tone'] == 'primary';
    final bullets = (option['bullets'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: XmColors.bgMuted, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('方案${primary ? 'A' : 'B'} · ${option['lean']}',
              style: TextStyle(
                color: primary ? XmColors.primary : XmColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              )),
          const SizedBox(height: 8),
          for (final b in bullets) Text('· $b', style: const TextStyle(height: 1.45)),
          if (option['basis'] != null) ...[
            const SizedBox(height: 8),
            Text(option['basis'] as String,
                style: const TextStyle(fontSize: 12, color: XmColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: primary
                ? FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(backgroundColor: XmColors.primary),
                    child: const Text('一键执行（需签发）'),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(foregroundColor: XmColors.success),
                    child: const Text('选择方案B'),
                  ),
          ),
        ],
      ),
    );
  }
}

class SignOffScreen extends StatefulWidget {
  const SignOffScreen({super.key, required this.id});
  final String id;

  @override
  State<SignOffScreen> createState() => _SignOffScreenState();
}

class _SignOffScreenState extends State<SignOffScreen> {
  Map<String, dynamic>? ticket;
  final noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<AppState>().api.get('/sign-off/${widget.id}') as Map<String, dynamic>;
    setState(() => ticket = res);
  }

  @override
  Widget build(BuildContext context) {
    if (ticket == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('签发台')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('对外内容需你签发', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('语气相似度 ${(ticket!['toneScore'] as num?)?.toStringAsFixed(2) ?? '-'}',
                style: const TextStyle(color: XmColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: XmColors.bgMuted, borderRadius: BorderRadius.circular(12)),
              child: Text(ticket!['content'] as String? ?? '', style: const TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '手写补充区（注入真人内容）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await context.read<AppState>().api.post('/sign-off/${widget.id}/reject');
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('驳回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await context.read<AppState>().api.post('/sign-off/${widget.id}/approve', {
                        'handwrittenNote': noteCtrl.text,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('已签发并执行')));
                        Navigator.popUntil(context, (r) => r.isFirst);
                      }
                    },
                    child: const Text('签发'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.titleColor});
  final String title;
  final Widget child;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: XmColors.bgMuted, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w700, color: titleColor ?? XmColors.text)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class MedScreen extends StatefulWidget {
  const MedScreen({super.key, required this.id});
  final String id;

  @override
  State<MedScreen> createState() => _MedScreenState();
}

class _MedScreenState extends State<MedScreen> {
  Map<String, dynamic>? med;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppState>().api.get('/med-reminders') as List;
    setState(() {
      med = Map<String, dynamic>.from(
        list.cast<Map>().firstWhere((m) => m['id'] == widget.id, orElse: () => list.first as Map),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (med == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('服药守护')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${med!['elderName']} · ${med!['drug']}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${med!['scheduleLabel']} · ${med!['dose']}',
                style: const TextStyle(color: XmColors.textSecondary)),
            const SizedBox(height: 20),
            _step('① App/小程序语音播报', med!['confirmState'] != 'pending'),
            _step('② 5分钟未确认 → 电话外呼（播放子女录音）', false),
            _step('③ 仍未确认 → 静默通知子女', med!['confirmState'] == 'escalated'),
            const SizedBox(height: 12),
            Text('当前状态：${med!['confirmState']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await context.read<AppState>().api.post('/med-reminders/${widget.id}/confirm');
                await _load();
              },
              child: const Text('模拟老人按 1 确认'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await context.read<AppState>().api.post('/med-reminders/${widget.id}/escalate');
                await _load();
              },
              child: const Text('模拟未接听升级'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String text, bool done) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? XmColors.success : XmColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key, required this.id});
  final String id;

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  Map<String, dynamic>? plan;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.get('/birthday-plans/${widget.id}').then((v) {
      setState(() => plan = Map<String, dynamic>.from(v as Map));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final gifts = (plan!['gifts'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('生日方案')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${plan!['personName']} · ${plan!['dateLabel']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _Card(title: '祝福话术', child: Text(plan!['script'] as String? ?? '', style: const TextStyle(height: 1.5))),
          const SizedBox(height: 12),
          _Card(
            title: '礼物建议',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in gifts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('【${g['tier']}】${g['title']} — ${g['reason']}${g['affiliate'] == true ? '（合作）' : ''}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: '庆祝方案',
            child: Text('默认：${plan!['celebrateDefault']}\n保底：${plan!['celebrateBackup']}'),
          ),
          const SizedBox(height: 12),
          Text('记忆依据：${((plan!['memoryBasis'] as List?) ?? []).join(' · ')}',
              style: const TextStyle(fontSize: 12, color: XmColors.textSecondary)),
        ],
      ),
    );
  }
}

class DocumentAlertScreen extends StatefulWidget {
  const DocumentAlertScreen({super.key, required this.id});
  final String id;

  @override
  State<DocumentAlertScreen> createState() => _DocumentAlertScreenState();
}

class _DocumentAlertScreenState extends State<DocumentAlertScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.get('/documents/${widget.id}/alert').then((v) {
      setState(() => data = Map<String, dynamic>.from(v as Map));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final doc = Map<String, dynamic>.from(data!['document'] as Map);
    final guide = Map<String, dynamic>.from(data!['guide'] as Map);
    return Scaffold(
      appBar: AppBar(title: const Text('证件预警')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${doc['title']} · 剩余 ${doc['daysLeft']} 天',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: XmColors.danger)),
          const SizedBox(height: 8),
          Text('到期日 ${doc['expiryAt']} · 持有人 ${doc['holderName']}',
              style: const TextStyle(color: XmColors.textSecondary)),
          const SizedBox(height: 16),
          _Card(
            title: '办理指引',
            child: Text(
              '去哪办：${guide['where']}\n带什么：${(guide['bring'] as List).join('、')}\n能否线上：${guide['online'] == true ? '是' : '否'}\n预计耗时：${guide['etaHours']} 小时\n费用：${guide['feeRange']}\n更新：${guide['updatedAt']}',
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await context.read<AppState>().api.post('/documents/${widget.id}/schedule', {});
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已生成办理日程')));
              }
            },
            child: const Text('一键生成办理日程'),
          ),
        ],
      ),
    );
  }
}

class ClipboardSheet extends StatefulWidget {
  const ClipboardSheet({super.key});

  @override
  State<ClipboardSheet> createState() => _ClipboardSheetState();
}

class _ClipboardSheetState extends State<ClipboardSheet> {
  final ctrl = TextEditingController(text: '下周三下午3点会议室A项目评审');
  Map<String, dynamic>? draft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('剪贴板识别')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '粘贴文本（仅本地解析，原文不上云）',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final res = await context.read<AppState>().api.post('/events/from-clipboard', {
                  'text': ctrl.text,
                });
                setState(() => draft = res['draft'] as Map<String, dynamic>?);
              },
              child: const Text('识别'),
            ),
            if (draft != null) ...[
              const SizedBox(height: 16),
              _Card(
                title: '预填卡片',
                child: Text(
                  '标题：${draft!['title']}\n时间：${draft!['startHint']}\n地点：${draft!['location']}\n置信度：${draft!['confidence']}',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await context.read<AppState>().api.post('/events', {
                    'title': draft!['title'],
                    'start': '2026-10-15T15:00:00+08:00',
                    'end': '2026-10-15T16:00:00+08:00',
                    'location': draft!['location'],
                    'domain': 'work',
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('已一键建档')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('一键确认生成日程'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
