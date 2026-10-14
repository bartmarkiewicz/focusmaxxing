import 'package:equatable/equatable.dart';

class DailySummaryEntity extends Equatable {
  final DateTime date;
  final int totalFocusMinutes;
  final int completedSessionsCount;
  final int currentStreakDays;

  const DailySummaryEntity({
    required this.date,
    required this.totalFocusMinutes,
    required this.completedSessionsCount,
    required this.currentStreakDays,
  });

  DailySummaryEntity copyWith({
    DateTime? date,
    int? totalFocusMinutes,
    int? completedSessionsCount,
    int? currentStreakDays,
  }) {
    return DailySummaryEntity(
      date: date ?? this.date,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      completedSessionsCount:
          completedSessionsCount ?? this.completedSessionsCount,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
    );
  }

  @override
  List<Object?> get props => [
        date,
        totalFocusMinutes,
        completedSessionsCount,
        currentStreakDays,
      ];
}
