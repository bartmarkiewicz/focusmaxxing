class DatabaseException implements Exception {
  final String message;

  const DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}

class PlatformBridgeException implements Exception {
  final String message;

  const PlatformBridgeException(this.message);

  @override
  String toString() => 'PlatformBridgeException: $message';
}

class ScheduleException implements Exception {
  final String message;

  const ScheduleException(this.message);

  @override
  String toString() => 'ScheduleException: $message';
}
