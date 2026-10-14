import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';

class BacklogTaskModel extends BacklogTaskEntity {
  const BacklogTaskModel({
    super.id,
    required super.title,
    super.isCompleted,
    super.completedSessionId,
    required super.createdAt,
    super.completedAt,
  });

  factory BacklogTaskModel.fromMap(Map<String, dynamic> map) {
    return BacklogTaskModel(
      id: (map['id'] as num?)?.toInt(),
      title: map['title']?.toString() ?? '',
      isCompleted: ((map['is_completed'] as num?)?.toInt() ?? 0) == 1,
      completedSessionId: (map['completed_session_id'] as num?)?.toInt(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'completed_session_id': completedSessionId,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  BacklogTaskEntity toEntity() {
    return BacklogTaskEntity(
      id: id,
      title: title,
      isCompleted: isCompleted,
      completedSessionId: completedSessionId,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }
}
