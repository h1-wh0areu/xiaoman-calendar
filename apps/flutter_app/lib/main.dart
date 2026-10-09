import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'screens/detail_screens.dart';
import 'screens/home_screen.dart';
import 'screens/tabs.dart';
import 'screens/timeline_screen.dart';
import 'theme.dart';
import 'widgets/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XiaomanApp());
}

class XiaomanApp extends StatelessWidget {
  const XiaomanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: '小满 · 日程分身',
        debugShowCheckedModeBanner: false,
        theme: buildXmTheme(),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          if (name.startsWith('/conflicts/')) {
            return MaterialPageRoute(
              builder: (_) => ConflictScreen(id: name.split('/').last),
            );
          }
          if (name.startsWith('/events/') && name.endsWith('/cheat-sheet')) {
            final id = name.split('/')[2];
            return MaterialPageRoute(builder: (_) => CheatSheetScreen(eventId: id));
          }
          if (name.startsWith('/sign-off/')) {
            return MaterialPageRoute(
              builder: (_) => SignOffScreen(id: name.split('/').last),
            );
          }
          if (name.startsWith('/family/med/')) {
            return MaterialPageRoute(
              builder: (_) => MedScreen(id: name.split('/').last),
            );
          }
          if (name.startsWith('/life/birthday/')) {
            return MaterialPageRoute(
              builder: (_) => BirthdayScreen(id: name.split('/').last),
            );
          }
          if (name.startsWith('/docs/') && name.endsWith('/alert')) {
            final id = name.split('/')[2];
            return MaterialPageRoute(builder: (_) => DocumentAlertScreen(id: id));
          }
          if (name == '/clipboard') {
            return MaterialPageRoute(builder: (_) => const ClipboardSheet());
          }
          if (name == '/sync') {
            return MaterialPageRoute(builder: (_) => const SyncScreen());
          }
          return MaterialPageRoute(builder: (_) => const RootPage());
        },
        home: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<AppState>().tabIndex;
    final pages = const [
      HomeScreen(),
      TimelineScreen(),
      AvatarTab(),
      FamilyTab(),
      MeTab(),
    ];
    return AppShell(child: pages[tab]);
  }
}
