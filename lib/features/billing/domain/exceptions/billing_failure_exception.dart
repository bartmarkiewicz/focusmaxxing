/// Domain exception thrown when an in-app purchase or restore operation fails.
class BillingFailureException implements Exception {
  final String message;
  final bool isCancelled;

  const BillingFailureException(
    this.message, {
    this.isCancelled = false,
  });

  @override
  String toString() => message;
}
