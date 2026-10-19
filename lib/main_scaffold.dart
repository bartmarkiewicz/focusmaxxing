import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/insights/presentation/pages/insights_page.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/pages/shield_page.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/pages/timer_page.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_input_dialog.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

/// Root scaffold hosting the bottom navigation bar and handling AppWidget deep links.
class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.widgetLaunchUriFuture,
    this.widgetLaunchUriStream,
  });

  /// The active navigation tab index at startup.
  final int initialIndex;

  /// Optional future for test injection of widget cold-launch URIs.
  final Future<Uri?>? widgetLaunchUriFuture;

  /// Optional stream for test injection of widget click event URIs.
  final Stream<Uri?>? widgetLaunchUriStream;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  late int _currentIndex;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  bool _isHandlingLockIn = false;

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
    _initializeWidgetDeepLinking();
  }

  void _initializeWidgetDeepLinking() {
    final future = widget.widgetLaunchUriFuture ??
        (!kIsWeb && (Platform.isAndroid || Platform.isIOS)
            ? HomeWidget.initiallyLaunchedFromHomeWidget()
            : null);

    if (future != null) {
      unawaited(
        future.then((uri) {
          if (mounted && uri != null) {
            _handleWidgetLaunchUri(uri);
          }
        }).catchError((_) {}),
      );
    }

    final stream = widget.widgetLaunchUriStream ??
        (!kIsWeb && (Platform.isAndroid || Platform.isIOS)
            ? HomeWidget.widgetClicked
            : null);

    if (stream != null) {
      _widgetClickSubscription = stream.listen(
        (uri) {
          if (mounted && uri != null) {
            _handleWidgetLaunchUri(uri);
          }
        },
        onError: (Object error) {
          developer.log(
            'Error receiving widget clicked event: $error',
            name: 'MainScaffold',
          );
        },
      );
    }
  }

  void _handleWidgetLaunchUri(Uri uri) {
    final isLockInUri = uri.scheme == 'focusmaxxing' &&
        (uri.host == 'lockin' || uri.path.contains('lockin'));

    if (isLockInUri) {
      unawaited(_triggerQuickLockIn());
    }
  }

  Future<void> _triggerQuickLockIn() async {
    if (_isHandlingLockIn) return;
    _isHandlingLockIn = true;

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }

    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final timerNotifier = context.read<TimerNotifier>();
        if (timerNotifier.status != TimerStatus.idle) {
          return;
        }

        final durationMinutes =
            (timerNotifier.targetDurationSeconds / 60).round();
        final selectedGoal = await GoalInputDialog.show(
          context,
          durationMinutes: durationMinutes,
          initialGoal: timerNotifier.currentTaskGoal,
        );

        if (!mounted || selectedGoal == null || selectedGoal.trim().isEmpty) {
          return;
        }
        await timerNotifier.startFocusSession(selectedGoal);
      } finally {
        if (mounted) {
          _isHandlingLockIn = false;
        }
      }
    });
  }

  @override
  void dispose() {
    unawaited(_widgetClickSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final timerNotifier = context.read<TimerNotifier?>();
      timerNotifier?.syncWithWallClock();

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
