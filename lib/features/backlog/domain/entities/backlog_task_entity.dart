import 'package:equatable/equatable.dart';

class BacklogTaskEntity extends Equatable {
  final int? id;
  final String title;
  final bool isCompleted;
  final int? completedSessionId;
  final DateTime createdAt;
  final DateTime? completedAt;

  const BacklogTaskEntity({
    this.id,
    required this.title,
    this.isCompleted = false,
    this.completedSessionId,
    required this.createdAt,
    this.completedAt,
  });

  BacklogTaskEntity copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    int? completedSessionId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return BacklogTaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      completedSessionId: completedSessionId ?? this.completedSessionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        isCompleted,
        completedSessionId,
        createdAt,
        completedAt,
      ];
}
