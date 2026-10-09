import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class AvatarTab extends StatelessWidget {
  const AvatarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AppState>().avatarStats;
    final month = stats?['month'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('分身档案', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('信任等级 ${stats?['trustLevel'] ?? 'L1'} · L1代笔 → L2代发 → L3代办 → L4代陪',
            style: const TextStyle(color: XmColors.textSecondary)),
        const SizedBox(height: 16),
        _stat('会前小抄', month['cheatSheets']),
        _stat('代出席', month['delegates']),
        _stat('承诺闭环', month['commitmentsClosed']),
        _stat('冲突拦截', month['conflictsCaught']),
        _stat('服药守护天数', month['medDays']),
        _stat('证件拦截', month['docIntercepts']),
        _stat('重要日子到场', month['importantDays']),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/clipboard'),
          child: const Text('剪贴板 / 粘贴建日程'),
        ),
      ],
    );
  }

  Widget _stat(String k, Object? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text('${v ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, color: XmColors.primary)),
          ],
        ),
      );
}

class FamilyTab extends StatelessWidget {
  const FamilyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final families = context.watch<AppState>().families;
    if (families.isEmpty) return const Center(child: Text('暂无家庭组'));
    final fam = Map<String, dynamic>.from(families.first as Map);
    final claims = (fam['claims'] as List?) ?? [];
    final members = (fam['members'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(fam['name'] as String? ?? '家庭',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('成员：${members.map((m) => m['name']).join('、')}',
            style: const TextStyle(color: XmColors.textSecondary)),
        const SizedBox(height: 16),
        const Text('待认领', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final c in claims)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c['title'] as String? ?? ''),
            subtitle: Text(c['claimant'] == null ? '无人认领' : '已认领：${c['claimant']}'),
            trailing: c['claimant'] == null
                ? TextButton(
                    onPressed: () async {
                      await context.read<AppState>().api.post(
                            '/families/${fam['id']}/claims/${c['id']}/claim',
                            {'name': '我'},
                          );
                      await context.read<AppState>().refreshHome();
                    },
                    child: const Text('认领'),
                  )
                : null,
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed('/family/med/med-dad'),
          child: const Text('打开服药守护'),
        ),
      ],
    );
  }
}

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('我的', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${me?['displayName'] ?? ''} · ${me?['phone'] ?? ''}',
            style: const TextStyle(color: XmColors.textSecondary)),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('存储方案'),
          subtitle: Text('当前：方案 ${me?['storageMode'] ?? 'A'}（A云端 / B端到端加密 / C纯本地）'),
          trailing: DropdownButton<String>(
            value: me?['storageMode'] as String? ?? 'A',
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              await state.api.patch('/me', {'storageMode': v});
              await state.refreshHome();
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('银发模式'),
          value: state.seniorMode,
          onChanged: (_) => state.toggleSenior(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('同步源'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/sync'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('导出数据'),
          onTap: () async {
            await state.api.post('/me/export');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已导出 iCal+JSON')));
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('销毁分身', style: TextStyle(color: XmColors.danger)),
          onTap: () async {
            await state.api.post('/me/destroy');
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('销毁请求已受理（30天）')));
            }
          },
        ),
      ],
    );
  }
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<dynamic> sources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppState>().api.get('/sync/sources') as List;
    setState(() => sources = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日历同步源')),
      body: ListView(
        children: [
          for (final s in sources)
            ListTile(
              title: Text(s['name'] as String? ?? ''),
              subtitle: Text(s['connected'] == true ? '已连接 · ${s['lastSyncAt'] ?? ''}' : '未连接'),
              trailing: Icon(s['connected'] == true ? Icons.check_circle : Icons.link_off,
                  color: s['connected'] == true ? XmColors.success : XmColors.textSecondary),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
              onPressed: () async {
                await context.read<AppState>().api.post('/sync/run');
                await _load();
              },
              child: const Text('立即 Mock 同步'),
            ),
          ),
        ],
      ),
    );
  }
}
