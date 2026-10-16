import 'dart:typed_data';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';

class ShieldedAppModel extends ShieldedAppEntity {
  const ShieldedAppModel({
    required super.packageName,
    required super.appName,
    super.iconBytes,
    super.isActive,
    super.isPreset,
    required super.createdAt,
  });

  factory ShieldedAppModel.fromMap(
    Map<String, dynamic> map, {
    Uint8List? iconBytes,
  }) {
    return ShieldedAppModel(
      packageName: map['package_name']?.toString() ?? '',
      appName: map['app_name']?.toString() ?? '',
      iconBytes: iconBytes,
      isActive: ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
      isPreset: ((map['is_preset'] as num?)?.toInt() ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'package_name': packageName,
      'app_name': appName,
      'is_active': isActive ? 1 : 0,
      'is_preset': isPreset ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ShieldedAppEntity toEntity({Uint8List? overrideIconBytes}) {
    return ShieldedAppEntity(
      packageName: packageName,
      appName: appName,
      iconBytes: overrideIconBytes ?? iconBytes,
      isActive: isActive,
      isPreset: isPreset,
      createdAt: createdAt,
    );
  }
}
