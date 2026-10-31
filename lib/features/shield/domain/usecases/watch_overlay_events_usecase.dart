import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class WatchOverlayEventsUseCase {
  final IShieldRepository repository;

  const WatchOverlayEventsUseCase(this.repository);

  Stream<dynamic> call() {
    return repository.overlayEvents;
  }
}
