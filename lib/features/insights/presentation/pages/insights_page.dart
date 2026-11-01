import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/insights/presentation/widgets/session_history_list.dart';
import 'package:focusmaxxing/features/settings/presentation/pages/settings_page.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:provider/provider.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<InsightsNotifier>().loadInsights());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<InsightsNotifier>();
    final summary = notifier.dailySummary;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text(
          AppStrings.insightsTitle,
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        ),
        actions: [
          const Center(child: ProSupporterBadge()),
          IconButton(
            key: const Key('settings_button'),
            icon: Icon(Icons.settings_outlined, color: tokens.ink),
            tooltip: 'Settings',
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: InstrumentTokens.s8),
        ],
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        color: tokens.accent,
        backgroundColor: tokens.surface,
        child: _InsightsBody(
          notifier: notifier,
          summary: summary,
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  final InsightsNotifier notifier;
  final DailySummaryEntity? summary;

  const _InsightsBody({
    required this.notifier,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (notifier.isLoading && summary == null) {
      return const _InsightsLoadingView();
    }

    final errorMessage = notifier.errorMessage;
    if (errorMessage != null && summary == null) {
      return _InsightsErrorView(
        errorMessage: errorMessage,
        onRetry: notifier.refresh,
      );
    }

    return _InsightsContent(
      notifier: notifier,
      summary: summary,
    );
  }
}

class _InsightsLoadingView extends StatelessWidget {
  const _InsightsLoadingView();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InstrumentTokens.gutter),
        child: Text(
          'LOADING...',
          style: TextStyle(
            fontFamily: InstrumentTokens.fontMono,
            fontSize: 12,
            letterSpacing: 1.2,
            color: tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _InsightsErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _InsightsErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(InstrumentTokens.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'UNABLE TO LOAD INSIGHTS',
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontMono,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: tokens.danger,
                    ),
                  ),
                  const SizedBox(height: InstrumentTokens.s8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 14,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: InstrumentTokens.s20),
                  InstrumentButton.secondary(
                    label: 'Retry',
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightsContent extends StatelessWidget {
  final InsightsNotifier notifier;
  final DailySummaryEntity? summary;

  const _InsightsContent({
    required this.notifier,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = notifier.errorMessage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth >= 600;

        final readoutsWidget = _HeaderReadouts(
          todayMinutes: summary?.totalFocusMinutes ?? 0,
          sessions: notifier.recentSessions,
          streakDays: summary?.currentStreakDays ?? 0,
        );

        final chartWidget = _InstrumentBarChart(
          sessions: notifier.recentSessions,
        );

        final historyWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'RECENT SESSIONS'),
            const SizedBox(height: InstrumentTokens.s8),
            SessionHistoryList(sessions: notifier.recentSessions),
          ],
        );

        if (isExpanded) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(InstrumentTokens.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorMessage != null) ...[
                  _InlineErrorMessage(message: errorMessage),
                  const SizedBox(height: InstrumentTokens.s16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          readoutsWidget,
                          const SizedBox(height: InstrumentTokens.s20),
                          chartWidget,
                        ],
                      ),
                    ),
                    const SizedBox(width: InstrumentTokens.gutter),
                    Expanded(
                      flex: 6,
                      child: historyWidget,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.gutter,
            vertical: InstrumentTokens.s12,
          ),
          children: [
            if (errorMessage != null) ...[
              _InlineErrorMessage(message: errorMessage),
              const SizedBox(height: InstrumentTokens.s16),
            ],
            readoutsWidget,
            const SizedBox(height: InstrumentTokens.s20),
            chartWidget,
            const SizedBox(height: InstrumentTokens.s24),
            historyWidget,
            const SizedBox(height: InstrumentTokens.s32),
          ],
        );
      },
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  final String message;

  const _InlineErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InstrumentTokens.gutter,
        vertical: InstrumentTokens.s8,
      ),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.danger, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: InstrumentTokens.fontUi,
          fontSize: 13,
          color: tokens.danger,
        ),
      ),
    );
  }
}

/// Large mono readouts: Today 1h 40m · This week 9h 05m · Streak 6 days
class _HeaderReadouts extends StatelessWidget {
  final int todayMinutes;
  final List<SessionEntity> sessions;
  final int streakDays;

  const _HeaderReadouts({
    required this.todayMinutes,
    required this.sessions,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Calculate this week's minutes
    int thisWeekMinutes = 0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    for (final s in sessions) {
      final sDate = DateTime.fromMillisecondsSinceEpoch(s.startTimeEpochMs);
      if (sDate.isAfter(sevenDaysAgo)) {
        final sec = (s.actualDurationSeconds > 0 ||
                s.status == SessionStatus.cancelled)
            ? s.actualDurationSeconds
            : s.targetDurationSeconds;
        thisWeekMinutes += (sec / 60).round();
      }
    }
    // Fallback if todayMinutes is higher than calculated week (e.g. mock test data)
    if (todayMinutes > thisWeekMinutes) {
      thisWeekMinutes = todayMinutes;
    }

    final todayFormatted = _formatDuration(todayMinutes);
    final weekFormatted = _formatDuration(thisWeekMinutes);
    final streakText = '$streakDays ${streakDays == 1 ? "day" : "days"}';

    return Container(
      padding: const EdgeInsets.all(InstrumentTokens.gutter),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ReadoutItem(
                  label: 'TODAY',
                  value: todayFormatted,
                  isAccent: true,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: tokens.rule,
              ),
              Expanded(
                child: _ReadoutItem(
                  label: 'THIS WEEK',
                  value: weekFormatted,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: tokens.rule,
              ),
              Expanded(
                child: _ReadoutItem(
                  label: 'STREAK',
                  value: streakText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _ReadoutItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;

  const _ReadoutItem({
    required this.label,
    required this.value,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InstrumentTokens.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(height: InstrumentTokens.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontMono,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isAccent ? tokens.accent : tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 7-day bar chart drawn with CustomPainter.
/// Bars are ink at 0.8 opacity, today's bar is accent, 1dp baseline rule, mono M T W T F S S.
class _InstrumentBarChart extends StatefulWidget {
  final List<SessionEntity> sessions;

  const _InstrumentBarChart({required this.sessions});

  @override
  State<_InstrumentBarChart> createState() => _InstrumentBarChartState();
}

class _InstrumentBarChartState extends State<_InstrumentBarChart> {
  int _selectedPeriodIndex = 0; // 0: 7D, 1: 30D, 2: 1Y

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final daysData = _compute7DaysData(widget.sessions);

    return Container(
      padding: const EdgeInsets.all(InstrumentTokens.gutter),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: tokens.inkMuted,
                ),
              ),
              // Segmented control 7D 30D 1Y
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PeriodButton(
                    label: '7D',
                    isSelected: _selectedPeriodIndex == 0,
                    onTap: () => setState(() => _selectedPeriodIndex = 0),
                  ),
                  const SizedBox(width: InstrumentTokens.s4),
                  _PeriodButton(
                    label: '30D',
                    isSelected: _selectedPeriodIndex == 1,
                    onTap: () => setState(() => _selectedPeriodIndex = 1),
                  ),
                  const SizedBox(width: InstrumentTokens.s4),
                  _PeriodButton(
                    label: '1Y',
                    isSelected: _selectedPeriodIndex == 2,
                    onTap: () => setState(() => _selectedPeriodIndex = 2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: InstrumentTokens.s20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _BarChartPainter(
                days: daysData,
                tokens: tokens,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DayBarData> _compute7DaysData(List<SessionEntity> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <_DayBarData>[];

    const weekLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      int minutes = 0;
      for (final s in sessions) {
        final sDate = DateTime.fromMillisecondsSinceEpoch(s.startTimeEpochMs);
        if (AppDateUtils.isSameDay(date, sDate)) {
          final sec = (s.actualDurationSeconds > 0 ||
                  s.status == SessionStatus.cancelled)
              ? s.actualDurationSeconds
              : s.targetDurationSeconds;
          minutes += (sec / 60).round();
        }
      }
      final dayLetter = weekLetters[date.weekday - 1];
      result.add(_DayBarData(
        label: dayLetter,
        minutes: minutes,
        isToday: i == 0,
      ));
    }
    return result;
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? tokens.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(InstrumentTokens.r1),
          border: Border.all(
            color: isSelected ? tokens.ruleStrong : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: InstrumentTokens.fontMono,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? tokens.ink : tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _DayBarData {
  final String label;
  final int minutes;
  final bool isToday;

  const _DayBarData({
    required this.label,
    required this.minutes,
    required this.isToday,
  });
}

class _BarChartPainter extends CustomPainter {
  final List<_DayBarData> days;
  final InstrumentTokens tokens;

  _BarChartPainter({
    required this.days,
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    const labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;
    final baselineY = chartHeight;

    // Draw 1dp baseline rule
    final baselinePaint = Paint()
      ..color = tokens.ruleStrong
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    // Find max minutes
    int maxMinutes = 60; // minimum scale 60m
    for (final d in days) {
      if (d.minutes > maxMinutes) {
        maxMinutes = d.minutes;
      }
    }

    final barSlotWidth = size.width / days.length;
    const barWidth = 18.0;

    final barPaintDefault = Paint()
      ..color = tokens.ink.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final barPaintToday = Paint()
      ..color = tokens.accent
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      fontFamily: InstrumentTokens.fontMono,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: tokens.inkMuted,
    );

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final slotCenterX = i * barSlotWidth + barSlotWidth / 2;

      // Draw bar if minutes > 0
      final fraction = (day.minutes / maxMinutes).clamp(0.0, 1.0);
      final barH = fraction * (chartHeight - 8.0);

      if (barH > 0) {
        final left = slotCenterX - barWidth / 2;
        final top = baselineY - barH;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(left, top, barWidth, barH),
          topLeft: const Radius.circular(InstrumentTokens.r1),
          topRight: const Radius.circular(InstrumentTokens.r1),
        );
        canvas.drawRRect(rect, day.isToday ? barPaintToday : barPaintDefault);
      } else {
        // Subtle 2dp tick at baseline for days with 0 minutes
        final dotPaint = Paint()
          ..color = tokens.ruleStrong
          ..strokeWidth = 2.0;
        canvas.drawCircle(
          Offset(slotCenterX, baselineY - 2),
          1.5,
          dotPaint,
        );
      }

      // Draw day label
      final textSpan = TextSpan(
        text: day.label,
        style: day.isToday
            ? textStyle.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.bold,
              )
            : textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          slotCenterX - textPainter.width / 2,
          baselineY + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.days != days || oldDelegate.tokens != tokens;
  }
}
