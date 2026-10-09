import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int months = 3;

  Future<void> _load(int m) async {
    final state = context.read<AppState>();
    final tl = await state.api.get('/timeline?months=$m') as Map<String, dynamic>;
    state.timeline = (tl['items'] as List?) ?? [];
    state.timelineInsight = tl['insight'] as String?;
    setState(() => months = m);
    state.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text('时间线 · 未来', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final m in [1, 3, 6, 12])
              ChoiceChip(
                label: Text(m == 12 ? '1年' : '$m月'),
                selected: months == m,
                onSelected: (_) => _load(m),
                selectedColor: XmColors.primarySoft,
                labelStyle: TextStyle(
                  color: months == m ? XmColors.primary : XmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (state.timelineInsight != null) ...[
          const SizedBox(height: 12),
          Text(state.timelineInsight!,
              style: const TextStyle(color: XmColors.conflict, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 16),
        for (final raw in state.timeline)
          _TimelineTile(event: Map<String, dynamic>.from(raw as Map)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _Legend(color: XmColors.work, label: '工作'),
            _Legend(color: XmColors.family, label: '家庭'),
            _Legend(color: XmColors.document, label: '证件'),
            _Legend(color: XmColors.birthday, label: '生日'),
            _Legend(color: XmColors.study, label: '学习'),
            _Legend(color: XmColors.health, label: '健康'),
          ],
        ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final domain = event['domain'] as String? ?? 'work';
    final start = DateTime.parse(event['start'] as String).toLocal();
    final label =
        '${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}  ${event['title']}';
    String? tag;
    if (domain == 'document') {
      tag = event['id'] == 'e-passport' ? 'T-90' : 'T-30';
    } else if (event['id'] == 'e-exam') {
      tag = 'T-14';
    } else if (event['prepStatus'] == 'ready') {
      tag = '√备';
    }

    return InkWell(
      onTap: () {
        if (domain == 'document') {
          final id = event['id'] == 'e-passport' ? 'doc-passport' : 'doc-license';
          Navigator.of(context).pushNamed('/docs/$id/alert');
        } else if (event['id'] == 'e-mom-bday') {
          Navigator.of(context).pushNamed('/life/birthday/bp-mom');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: XmColors.domain(domain), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tag.startsWith('T') ? const Color(0xFFFFEBEE) : XmColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag,
                    style: TextStyle(
                      color: tag.startsWith('T') ? XmColors.danger : XmColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: XmColors.textSecondary)),
      ],
    );
  }
}
