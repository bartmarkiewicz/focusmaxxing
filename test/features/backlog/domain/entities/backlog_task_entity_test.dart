import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';

void main() {
  group('BacklogTaskEntity', () {
    final createdDate = DateTime(2026, 10, 14, 10);
    final completedDate = DateTime(2026, 10, 14, 11);

    final task = BacklogTaskEntity(
      id: 1,
      title: 'Deep Code Review',
      isCompleted: false,
      completedSessionId: null,
      createdAt: createdDate,
      completedAt: null,
    );

    test('equality and props', () {
      final task2 = BacklogTaskEntity(
        id: 1,
        title: 'Deep Code Review',
        isCompleted: false,
        completedSessionId: null,
        createdAt: createdDate,
        completedAt: null,
      );

      expect(task, equals(task2));
      expect(task.hashCode, equals(task2.hashCode));
    });

    test('copyWith updates fields correctly', () {
      final updated = task.copyWith(
        title: 'Review Complete',
        isCompleted: true,
        completedSessionId: 10,
        completedAt: completedDate,
      );

      expect(updated.id, 1);
      expect(updated.title, 'Review Complete');
      expect(updated.isCompleted, isTrue);
      expect(updated.completedSessionId, 10);
      expect(updated.completedAt, completedDate);

      final noChange = task.copyWith();
      expect(noChange, equals(task));
    });
  });
}
