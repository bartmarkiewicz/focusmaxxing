import 'package:equatable/equatable.dart';

/// Entity representing the user's recurring Scheduled Auto-Shield configuration.
class ScheduleConfigEntity extends Equatable {
  static const int defaultStartHour = 9;
  static const int defaultStartMinute = 0;
  static const int defaultEndHour = 17;
  static const int defaultEndMinute = 0;
  static const List<int> defaultActiveDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  final bool isEnabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<int> activeDays;

  const ScheduleConfigEntity({
    this.isEnabled = false,
    this.startHour = defaultStartHour,
    this.startMinute = defaultStartMinute,
    this.endHour = defaultEndHour,
    this.endMinute = defaultEndMinute,
    this.activeDays = defaultActiveDays,
  });

  static const ScheduleConfigEntity initial = ScheduleConfigEntity();

  int get startTotalMinutes => startHour * 60 + startMinute;
  int get endTotalMinutes => endHour * 60 + endMinute;

  /// Checks if the schedule is mathematically valid.
  /// Start time and end time must not be equal.
  bool get isValid {
    final validHours = startHour >= 0 &&
        startHour <= 23 &&
        endHour >= 0 &&
        endHour <= 23 &&
        startMinute >= 0 &&
        startMinute <= 59 &&
        endMinute >= 0 &&
        endMinute <= 59;
    if (!validHours) return false;
    if (startTotalMinutes == endTotalMinutes) return false;
    if (activeDays.isEmpty) return false;
    final validDays = activeDays.every((day) => day >= 1 && day <= 7);
    return validDays;
  }

  /// Formatted start time string (e.g. 09:00).
  String get formattedStartTime {
    final h = startHour.toString().padLeft(2, '0');
    final m = startMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatted end time string (e.g. 17:00).
  String get formattedEndTime {
    final h = endHour.toString().padLeft(2, '0');
    final m = endMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatted range string (e.g. 09:00 - 17:00).
  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  /// Whether this schedule spans across midnight (e.g. 22:00 - 06:00).
  bool get isOvernight => startTotalMinutes > endTotalMinutes;

  /// Whether the given weekday (1..7) is active in the schedule.
  bool isActiveOn(int weekday) => activeDays.contains(weekday);

  /// Evaluates whether the given [dateTime] falls within the active scheduled window.
  bool isWithinSchedule(DateTime dateTime) {
    if (!isEnabled || !isValid) return false;
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    if (startTotalMinutes < endTotalMinutes) {
      if (!isActiveOn(dateTime.weekday)) return false;
      return currentMinutes >= startTotalMinutes &&
          currentMinutes < endTotalMinutes;
    } else {
      if (currentMinutes >= startTotalMinutes) {
        return isActiveOn(dateTime.weekday);
      } else if (currentMinutes < endTotalMinutes) {
        final prevWeekday =
            dateTime.weekday == 1 ? DateTime.sunday : dateTime.weekday - 1;
        return isActiveOn(prevWeekday);
      }
      return false;
    }
  }

  ScheduleConfigEntity copyWith({
    bool? isEnabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? activeDays,
  }) {
    return ScheduleConfigEntity(
      isEnabled: isEnabled ?? this.isEnabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      activeDays: activeDays ?? this.activeDays,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        startHour,
        startMinute,
        endHour,
        endMinute,
        activeDays,
      ];
}
