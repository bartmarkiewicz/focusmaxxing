import 'dart:async';

import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';

/// Provides reactive domain access to Lifetime Pro entitlement changes and cached status.
class WatchProEntitlementUseCase {
  final IBillingRepository _repository;

  const WatchProEntitlementUseCase(this._repository);

  static final Expando<StreamController<ProUnlockStatusEntity>>
      _statusBroadcasters = Expando<StreamController<ProUnlockStatusEntity>>();
  static final Expando<StreamSubscription<ProUnlockStatusEntity>>
      _repoSubscriptions = Expando<StreamSubscription<ProUnlockStatusEntity>>();
  static final Expando<ProUnlockStatusEntity> _lastEmittedStatuses =
      Expando<ProUnlockStatusEntity>();

  StreamController<ProUnlockStatusEntity> get _broadcaster {
    var controller = _statusBroadcasters[_repository];
    if (controller == null) {
      controller = StreamController<ProUnlockStatusEntity>.broadcast();
      _statusBroadcasters[_repository] = controller;
      _repoSubscriptions[_repository] =
          _repository.purchaseStatusStream.listen(
        (status) {
          if (!controller!.isClosed &&
              _lastEmittedStatuses[_repository] != status) {
            _lastEmittedStatuses[_repository] = status;
            controller.add(status);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller!.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!controller!.isClosed) {
            unawaited(controller.close());
          }
        },
      );
    }
    return controller;
  }

  /// Emits [ProUnlockStatusEntity] updates whenever a purchase, restoration, or
  /// cached entitlement check completes.
  Stream<ProUnlockStatusEntity> call() {
    return _broadcaster.stream;
  }

  /// Queries the locally cached [ProUnlockStatusEntity] and broadcasts it to
  /// active entitlement listeners.
  Future<ProUnlockStatusEntity> getCachedStatus() async {
    final status = await _repository.getCachedProStatus();
    notifyEntitlementChanged(status);
    return status;
  }

  /// Broadcasts an updated [ProUnlockStatusEntity] to all subscribed listeners.
  void notifyEntitlementChanged(ProUnlockStatusEntity status) {
    final controller = _broadcaster;
    if (!controller.isClosed && _lastEmittedStatuses[_repository] != status) {
      _lastEmittedStatuses[_repository] = status;
      controller.add(status);
    }
  }
}
