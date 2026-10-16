import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/insights/presentation/pages/insights_page.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/pages/shield_page.dart';
import 'package:focusmaxxing/features/timer/presentation/pages/timer_page.dart';
import 'package:provider/provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  late int _currentIndex;

  static const List<Widget> _pages = [
    TimerPage(),
    ShieldPage(),
    InsightsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final shieldNotifier = context.read<ShieldNotifier?>();
      if (shieldNotifier != null) {
        unawaited(shieldNotifier.checkPermissions());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 1) {
              final shieldNotifier = context.read<ShieldNotifier?>();
              if (shieldNotifier != null) {
                unawaited(shieldNotifier.refresh());
              }
            } else if (index == 2) {
              final insightsNotifier = context.read<InsightsNotifier?>();
              if (insightsNotifier != null) {
                unawaited(insightsNotifier.refresh());
              }
            }
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Shield',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
