import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const tabs = [
    (Icons.calendar_today_outlined, '日程'),
    (Icons.timeline, '时间线'),
    (Icons.smart_toy_outlined, '分身'),
    (Icons.home_outlined, '家庭'),
    (Icons.person_outline, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1100;
    final scale = state.seniorMode ? 1.2 : 1.0;

    final navDestinations = [
      for (var i = 0; i < tabs.length; i++)
        NavigationDestination(
          icon: Icon(tabs[i].$1),
          label: tabs[i].$2,
          selectedIcon: Icon(tabs[i].$1, color: XmColors.primary),
        ),
    ];

    final body = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );

    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: state.tabIndex,
              onDestinationSelected: state.setTab,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in tabs)
                  NavigationRailDestination(icon: Icon(t.$1), label: Text(t.$2)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tabIndex,
        onDestinationSelected: state.setTab,
        destinations: navDestinations,
      ),
    );
  }
}
