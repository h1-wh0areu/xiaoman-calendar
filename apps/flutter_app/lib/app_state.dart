import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  bool seniorMode = false;
  int tabIndex = 0;
  bool offline = false;

  Map<String, dynamic>? brief;
  List<dynamic> timeline = [];
  String? timelineInsight;
  Map<String, dynamic>? avatarStats;
  List<dynamic> families = [];
  Map<String, dynamic>? me;

  Future<void> bootstrap() async {
    final ok = await api.login('13800138000');
    if (!ok) {
      offline = true;
      notifyListeners();
      return;
    }
    await refreshHome();
  }

  Future<void> refreshHome() async {
    brief = Map<String, dynamic>.from(await api.get('/brief/morning?date=2026-10-09') as Map);
    final tl = await api.get('/timeline?months=3') as Map<String, dynamic>;
    timeline = (tl['items'] as List?) ?? [];
    timelineInsight = tl['insight'] as String?;
    avatarStats = Map<String, dynamic>.from(await api.get('/avatar/stats') as Map);
    families = (await api.get('/families') as List?) ?? [];
    me = Map<String, dynamic>.from(await api.get('/me') as Map);
    notifyListeners();
  }

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  void toggleSenior() {
    seniorMode = !seniorMode;
    notifyListeners();
  }
}
