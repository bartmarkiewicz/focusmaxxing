import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/insights/presentation/pages/insights_page.dart';
import 'package:focusmaxxing/features/shield/presentation/pages/shield_page.dart';
import 'package:focusmaxxing/features/timer/presentation/pages/timer_page.dart';
import 'package:provider/provider.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
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
            if (index == 2) {
              try {
                unawaited(context.read<InsightsNotifier>().refresh());
              } on ProviderNotFoundException {
                // Allowed when running in isolated widget tests lacking InsightsNotifier
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
