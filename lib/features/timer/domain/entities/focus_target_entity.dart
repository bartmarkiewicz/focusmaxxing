import 'package:equatable/equatable.dart';

class FocusTargetEntity extends Equatable {
  const FocusTargetEntity({
    this.id,
    required this.name,
    this.colorHex = '#00E5FF',
    this.isArchived = false,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String colorHex;
  final bool isArchived;
  final DateTime? createdAt;

  FocusTargetEntity copyWith({
    int? id,
    String? name,
    String? colorHex,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return FocusTargetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, colorHex, isArchived, createdAt];
}
