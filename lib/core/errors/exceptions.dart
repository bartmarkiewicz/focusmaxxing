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
