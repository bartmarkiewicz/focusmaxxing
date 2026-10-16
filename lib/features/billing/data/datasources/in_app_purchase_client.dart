import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Abstraction over the native `in_app_purchase` plugin to support dependency
/// injection, desktop test environments, and deterministic unit testing.
abstract class IInAppPurchaseClient {
  /// Stream of purchase updates emitted by the underlying store.
  Stream<List<PurchaseDetails>> get purchaseStream;

  /// Returns `true` if the native store billing service is connected and ready.
  Future<bool> isAvailable();

  /// Queries the store for metadata matching the given product [identifiers].
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  /// Starts a non-consumable purchase flow for [purchaseParam].
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  /// Triggers restoration of previously purchased non-consumable items.
  Future<void> restorePurchases({String? applicationUserName});

  /// Acknowledges and finalizes a completed [purchase] with the store.
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// Production implementation of [IInAppPurchaseClient] delegating to
/// [InAppPurchase.instance] on supported platforms (Android, iOS, macOS).
class InAppPurchaseClientImpl implements IInAppPurchaseClient {
  final InAppPurchase? _injectedInstance;

  const InAppPurchaseClientImpl({
    InAppPurchase? instance,
  }) : _injectedInstance = instance;

  bool get _isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  InAppPurchase? _resolveInstance() {
    if (_injectedInstance != null) {
      return _injectedInstance;
    }
    if (!_isPlatformSupported) {
      return null;
    }
    try {
      return InAppPurchase.instance;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    final instance = _resolveInstance();
    if (instance == null) {
      return const Stream<List<PurchaseDetails>>.empty();
    }
    try {
      return instance.purchaseStream;
    } on PlatformException {
      return const Stream<List<PurchaseDetails>>.empty();
    } on MissingPluginException {
      return const Stream<List<PurchaseDetails>>.empty();
    }
  }

  @override
  Future<bool> isAvailable() async {
    final instance = _resolveInstance();
    if (instance == null) {
      return false;
    }
    try {
      return await instance.isAvailable();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    final instance = _resolveInstance();
    if (instance == null) {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(growable: false),
      );
    }
    try {
      return await instance.queryProductDetails(identifiers);
    } on PlatformException catch (e) {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(growable: false),
        error: IAPError(
          source: 'in_app_purchase',
          code: e.code,
          message: e.message ?? 'Platform exception querying product details.',
        ),
      );
    } on MissingPluginException {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(growable: false),
      );
    }
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    final instance = _resolveInstance();
    if (instance == null) {
      return false;
    }
    try {
      return await instance.buyNonConsumable(purchaseParam: purchaseParam);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    final instance = _resolveInstance();
    if (instance == null) {
      return;
    }
    try {
      await instance.restorePurchases(
        applicationUserName: applicationUserName,
      );
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    final instance = _resolveInstance();
    if (instance == null) {
      return;
    }
    try {
      await instance.completePurchase(purchase);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
