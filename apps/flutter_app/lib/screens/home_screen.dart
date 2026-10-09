import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brief = context.watch<AppState>().brief;
    if (brief == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = (brief['items'] as List?) ?? [];
    final banner = brief['conflictBanner'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(brief['title'] as String? ?? '早安 · 今日值班报告',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(brief['subtitle'] as String? ?? '',
            style: const TextStyle(color: XmColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        const Divider(color: XmColors.border),
        if (banner != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Navigator.of(context).pushNamed('/conflicts/${banner['conflictId']}'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: XmColors.conflict),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠ ${banner['count']} 个雷',
                      style: const TextStyle(
                          color: XmColors.conflict, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${banner['summary']} →',
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final raw in items)
          _EventRow(item: Map<String, dynamic>.from(raw as Map)),
        const SizedBox(height: 20),
        const Divider(color: XmColors.border),
        const SizedBox(height: 16),
        Text(brief['closing'] as String? ?? '其余的，我都备好了。',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final event = Map<String, dynamic>.from(item['event'] as Map);
    final color = Color(int.parse((item['color'] as String).replaceFirst('#', '0xFF')));
    final badge = item['badge'] as String? ?? '';
    final tone = item['badgeTone'] as String? ?? 'ready';
    final start = DateTime.parse(event['start'] as String).toLocal();
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () {
        if (event['id'] == 'e-review') {
          Navigator.of(context).pushNamed('/events/e-review/cheat-sheet');
        } else if (event['id'] == 'e-med') {
          Navigator.of(context).pushNamed('/family/med/med-dad');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            SizedBox(width: 48, child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
              child: Text(event['title'] as String? ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            _Badge(label: badge, tone: tone),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});
  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final decision = tone == 'decision' || tone == 'conflict';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: decision ? const Color(0xFFFFF3E0) : XmColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tone == 'ready' ? '✓$label' : label,
        style: TextStyle(
          color: decision ? XmColors.conflict : XmColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
