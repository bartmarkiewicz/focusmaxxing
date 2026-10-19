import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';

abstract interface class IShieldNativeBridgeSource {
  Future<ShieldPermissionStatus> checkPermissions();
  Future<bool> requestPermission(ShieldPermissionType permissionType);
  Future<bool> startShield(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  });
  Future<bool> stopShield();
  Future<bool> isShieldRunning();
  Future<bool> bringToForeground();
  Future<void> shareOverlayData(Map<String, dynamic> payload);
  Stream<dynamic> get overlayEvents;
}

class ShieldNativeBridgeSourceImpl implements IShieldNativeBridgeSource {
  static const MethodChannel _defaultChannel =
      MethodChannel('com.focusmaxxing/shield');

  ShieldNativeBridgeSourceImpl({
    MethodChannel? channel,
    Stream<dynamic>? overlayStream,
    this.shareDataCallback,
  })  : _channel = channel ?? _defaultChannel,
        _hasCustomChannel = channel != null,
        _customOverlayStream = overlayStream {
    if (_canUseNativeChannel) {
      _channel.setMethodCallHandler(_handleNativeMethodCall);
    }
  }

  final MethodChannel _channel;
  final bool _hasCustomChannel;
  final Stream<dynamic>? _customOverlayStream;
  final Future<dynamic> Function(dynamic data)? shareDataCallback;

  static final StreamController<dynamic> _mergedOverlayController =
      StreamController<dynamic>.broadcast();
  static bool _isOverlayListenerAttached = false;

  bool get _canUseNativeChannel =>
      _hasCustomChannel || (!kIsWeb && Platform.isAndroid);

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onOverlayAction') {
      _mergedOverlayController.add(call.arguments);
      return true;
    }
    return null;
  }

  @override
  Stream<dynamic> get overlayEvents {
    if (_customOverlayStream != null) {
      return _customOverlayStream;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return const Stream.empty();
    }
    if (!_isOverlayListenerAttached) {
      _isOverlayListenerAttached = true;
      FlutterOverlayWindow.overlayListener
          .asBroadcastStream()
          .listen(_mergedOverlayController.add, onError: (_) {});
    }
    return _mergedOverlayController.stream;
  }

  @override
  Future<ShieldPermissionStatus> checkPermissions() async {
    if (!_canUseNativeChannel) {
      return const ShieldPermissionStatus.allGranted();
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('checkPermissions');
      if (result == null) {
        return const ShieldPermissionStatus.allGranted();
      }
      return ShieldPermissionStatus(
        hasUsageStatsPermission: result['usageStats'] as bool? ?? false,
        hasOverlayPermission: result['overlay'] as bool? ?? false,
        isIgnoringBatteryOptimizations:
            result['batteryOptimization'] as bool? ?? false,
      );
    } on MissingPluginException {
      return const ShieldPermissionStatus.allGranted();
    } on PlatformException catch (e) {
      throw PlatformBridgeException(
        'Failed to check shield permissions: ${e.message}',
      );
    }
  }

  @override
  Future<bool> requestPermission(ShieldPermissionType permissionType) async {
    if (!_canUseNativeChannel) {
      return true;
    }
    final method = switch (permissionType) {
      ShieldPermissionType.usageStats => 'requestUsageStatsPermission',
      ShieldPermissionType.overlay => 'requestOverlayPermission',
      ShieldPermissionType.batteryOptimization =>
        'requestIgnoreBatteryOptimizations',
    };
    try {
      final granted = await _channel.invokeMethod<bool>(method);
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      throw PlatformBridgeException(
        'Failed to request permission ($method): ${e.message}',
      );
    }
  }

  @override
  Future<bool> startShield(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async {
    if (!_canUseNativeChannel) {
      return true;
    }
    try {
      final started = await _channel.invokeMethod<bool>(
        'startShield',
        <String, dynamic>{
          'packages': blockedPackages,
          'isScheduled': isScheduled,
          if (timeRange != null) 'timeRange': timeRange,
        },
      );
      return started ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      throw PlatformBridgeException(
        'Failed to start native shield service: ${e.message}',
      );
    }
  }

  @override
  Future<bool> stopShield() async {
    if (!_canUseNativeChannel) {
      return true;
    }
    try {
      final stopped = await _channel.invokeMethod<bool>('stopShield');
      return stopped ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      throw PlatformBridgeException(
        'Failed to stop native shield service: ${e.message}',
      );
    }
  }

  @override
  Future<bool> isShieldRunning() async {
    if (!_canUseNativeChannel) {
      return false;
    }
    try {
      final running = await _channel.invokeMethod<bool>('isShieldRunning');
      return running ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> bringToForeground() async {
    if (!_canUseNativeChannel) {
      return true;
    }
    try {
      final res = await _channel.invokeMethod<bool>('bringToForeground');
      return res ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> shareOverlayData(Map<String, dynamic> payload) async {
    final encoded = jsonEncode(payload);
    final callback = shareDataCallback;
    if (callback != null) {
      await callback(encoded);
      return;
    }
    if (!_canUseNativeChannel) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('syncOverlayData', payload);
    } catch (_) {
      // Ignore if native channel is unavailable in test environment
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await FlutterOverlayWindow.shareData(encoded);
    } catch (_) {
      // Ignore transient IPC errors when overlay engine is not yet attached
    }
  }
}
