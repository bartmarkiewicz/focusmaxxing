abstract final class TimeFormatter {

  static String formatMMSS(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDurationToMinutes(int totalSeconds) {
    final minutes = (totalSeconds / 60).round();
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
  }

  static String formatTimestamp(int epochMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
