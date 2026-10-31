import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_breather_view.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_lock_view.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';

export 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HardLockOverlayWidget(),
    ),
  );
}

class HardLockOverlayWidget extends StatefulWidget {
  const HardLockOverlayWidget({
    super.key,
    this.dataStream,
    this.onClose,
    this.onCancelSession,
    this.onEmergencyPass,
    this.initialGoal = 'Deep Work',
    this.initialRemainingSeconds = 1500,
    this.initialIsBreak = false,
    this.initialIsMaximumFocus = false,
    this.initialIsScheduled = false,
    this.initialScheduleTimeRange = '',
    this.initialEmergencyPassAvailable = true,
    this.breatherDuration = const Duration(seconds: 60),
  });

  final Stream<dynamic>? dataStream;
  final Future<void> Function()? onClose;
  final Future<void> Function()? onCancelSession;

  /// Requests a temporary shield pass; resolves to whether it was granted.
  final Future<bool> Function()? onEmergencyPass;
  final String initialGoal;
  final int initialRemainingSeconds;
  final bool initialIsBreak;
  final bool initialIsMaximumFocus;
  final bool initialIsScheduled;
  final String initialScheduleTimeRange;
  final bool initialEmergencyPassAvailable;
  final Duration breatherDuration;

  @override
  State<HardLockOverlayWidget> createState() => _HardLockOverlayWidgetState();
}

class _HardLockOverlayWidgetState extends State<HardLockOverlayWidget> {
  late final OverlayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OverlayController(
      dataStream: widget.dataStream,
      onClose: widget.onClose,
      onCancelSession: widget.onCancelSession,
      onEmergencyPass: widget.onEmergencyPass,
      initialGoal: widget.initialGoal,
      initialRemainingSeconds: widget.initialRemainingSeconds,
      initialIsBreak: widget.initialIsBreak,
      initialIsMaximumFocus: widget.initialIsMaximumFocus,
      initialIsScheduled: widget.initialIsScheduled,
      initialScheduleTimeRange: widget.initialScheduleTimeRange,
      initialEmergencyPassAvailable: widget.initialEmergencyPassAvailable,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isBreatherActive =
            _controller.breatherStage != OverlayBreatherStage.none;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {},
          child: Scaffold(
            backgroundColor: OverlayTheme.surfaceColor,
            extendBody: !isBreatherActive,
            extendBodyBehindAppBar: !isBreatherActive,
            body: SizedBox.expand(
              child: ColoredBox(
                color: OverlayTheme.surfaceColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: isBreatherActive
                        ? OverlayBreatherView(
                            stage: _controller.breatherStage,
                            breatherDuration: widget.breatherDuration,
                            emergencyPassAvailable:
                                _controller.emergencyPassAvailable,
                            onBreatherComplete: _controller.completeBreather,
                            onReadyToFocus: _controller.handleReturn,
                            onEmergencyPass: _controller.handleEmergencyPass,
                          )
                        : OverlayLockView(controller: _controller),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
