import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class PlatformFailure extends Failure {
  const PlatformFailure(super.message);
}
