import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter', () {
    test('formatMMSS formats positive seconds into standard digital clock format', () {
      expect(TimeFormatter.formatMMSS(1500), '25:00');
      expect(TimeFormatter.formatMMSS(59), '00:59');
      expect(TimeFormatter.formatMMSS(60), '01:00');
      expect(TimeFormatter.formatMMSS(5), '00:05');
      expect(TimeFormatter.formatMMSS(3599), '59:59');
    });

    test('formatMMSS clamps zero and negative seconds to 00:00', () {
      expect(TimeFormatter.formatMMSS(0), '00:00');
      expect(TimeFormatter.formatMMSS(-10), '00:00');
    });

    test('formatDurationToMinutes formats durations into clean labels', () {
      expect(TimeFormatter.formatDurationToMinutes(1500), '25m');
      expect(TimeFormatter.formatDurationToMinutes(3600), '1h');
      expect(TimeFormatter.formatDurationToMinutes(4500), '1h 15m');
      expect(TimeFormatter.formatDurationToMinutes(300), '5m');
    });

    test('formatTimestamp formats epoch ms into HH:mm format', () {
      final dateTime = DateTime(2026, 10, 14, 14, 5);
      final epochMs = dateTime.millisecondsSinceEpoch;
      expect(TimeFormatter.formatTimestamp(epochMs), '14:05');
    });
  });
}
