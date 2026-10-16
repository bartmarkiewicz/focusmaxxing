import 'package:equatable/equatable.dart';

/// Represents the user's current Lifetime Pro entitlement state.
class ProUnlockStatusEntity extends Equatable {
  /// Google Play non-consumable product identifier for Lifetime Pro.
  static const String lifetimeProProductId = 'focusmaxxing_lifetime_pro';

  /// Default formatted display price when the store catalog is offline.
  static const String defaultFormattedPrice = r'$9.99';

  /// Whether Lifetime Pro has been purchased and verified.
  final bool isUnlocked;

  /// Unix epoch milliseconds when the purchase was recorded, if unlocked.
  final int? purchaseDateMs;

  /// Store order identifier or verification token hash, if unlocked.
  final String? orderId;

  const ProUnlockStatusEntity({
    required this.isUnlocked,
    this.purchaseDateMs,
    this.orderId,
  });

  /// Default locked entitlement state for Free Tier users.
  static const ProUnlockStatusEntity locked = ProUnlockStatusEntity(
    isUnlocked: false,
  );

  ProUnlockStatusEntity copyWith({
    bool? isUnlocked,
    int? purchaseDateMs,
    String? orderId,
  }) {
    return ProUnlockStatusEntity(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      purchaseDateMs: purchaseDateMs ?? this.purchaseDateMs,
      orderId: orderId ?? this.orderId,
    );
  }

  @override
  List<Object?> get props => [isUnlocked, purchaseDateMs, orderId];
}

/// Domain representation of the Lifetime Pro store product metadata.
class ProProductDetailsEntity extends Equatable {
  /// Product SKU identifier (`focusmaxxing_lifetime_pro`).
  final String id;

  /// Localized product title from Google Play Billing.
  final String title;

  /// Localized product description from Google Play Billing.
  final String description;

  /// Formatted display price including currency symbol (e.g., `$9.99`).
  final String price;

  /// Raw numeric price value (e.g., `9.99`).
  final double rawPrice;

  /// ISO 4217 currency code (e.g., `USD`).
  final String currencyCode;

  const ProProductDetailsEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });

  /// Offline fallback metadata matching the flat $9.99 Lifetime Pro pricing.
  static const ProProductDetailsEntity fallback = ProProductDetailsEntity(
    id: ProUnlockStatusEntity.lifetimeProProductId,
    title: 'Focusmaxxing Lifetime Pro',
    description:
        'Unlock Unlimited Shielding & Audio forever with a single one-time payment.',
    price: ProUnlockStatusEntity.defaultFormattedPrice,
    rawPrice: 9.99,
    currencyCode: 'USD',
  );

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        price,
        rawPrice,
        currencyCode,
      ];
}
