import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class ShieldPreset extends Equatable {
  final String packageName;
  final String appName;

  const ShieldPreset({
    required this.packageName,
    required this.appName,
  });

  static const List<ShieldPreset> defaults = [
    ShieldPreset(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
    ),
    ShieldPreset(
      packageName: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
    ),
    ShieldPreset(
      packageName: 'com.twitter.android',
      appName: 'Twitter / X',
    ),
    ShieldPreset(
      packageName: 'com.reddit.frontpage',
      appName: 'Reddit',
    ),
    ShieldPreset(
      packageName: 'com.google.android.youtube',
      appName: 'YouTube Shorts',
    ),
    ShieldPreset(
      packageName: 'com.android.chrome',
      appName: 'Web Browsers',
    ),
    ShieldPreset(
      packageName: 'com.roblox.client',
      appName: 'Mobile Games',
    ),
  ];

  @override
  List<Object?> get props => [packageName, appName];
}

class ShieldedAppEntity extends Equatable {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
  final bool isActive;
  final bool isPreset;
  final DateTime createdAt;

  const ShieldedAppEntity({
    required this.packageName,
    required this.appName,
    this.iconBytes,
    this.isActive = true,
    this.isPreset = false,
    required this.createdAt,
  });

  ShieldedAppEntity copyWith({
    String? packageName,
    String? appName,
    Uint8List? iconBytes,
    bool? isActive,
    bool? isPreset,
    DateTime? createdAt,
  }) {
    return ShieldedAppEntity(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconBytes: iconBytes ?? this.iconBytes,
      isActive: isActive ?? this.isActive,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        packageName,
        appName,
        iconBytes?.lengthInBytes,
        isActive,
        isPreset,
        createdAt,
      ];
}
