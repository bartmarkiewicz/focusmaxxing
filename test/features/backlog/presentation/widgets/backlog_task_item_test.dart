import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_task_item.dart';

void main() {
  Widget buildSubject({
    required BacklogTaskEntity task,
    required VoidCallback onSelect,
    required VoidCallback onDelete,
    VoidCallback? onToggleComplete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BacklogTaskItem(
          task: task,
          onSelect: onSelect,
          onDelete: onDelete,
          onToggleComplete: onToggleComplete,
        ),
      ),
    );
  }

  group('BacklogTaskItem', () {
    testWidgets('renders pending task with unchecked circle and calls onToggleComplete',
        (tester) async {
      var toggled = false;
      var selected = false;

      final task = BacklogTaskEntity(
        id: 42,
        title: 'Review pull request',
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildSubject(
          task: task,
          onSelect: () => selected = true,
          onDelete: () {},
          onToggleComplete: () => toggled = true,
        ),
      );

      expect(find.text('Review pull request'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Tap checkbox
      await tester.tap(
        find.byKey(const ValueKey('backlog_task_checkbox_42')),
      );
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
      expect(selected, isFalse);

      // Tap tile body
      await tester.tap(find.text('Review pull request'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
    });

    testWidgets('renders completed task with check circle and strikethrough',
        (tester) async {
      final task = BacklogTaskEntity(
        id: 99,
        title: 'Submit tax return',
        isCompleted: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildSubject(
          task: task,
          onSelect: () {},
          onDelete: () {},
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

      final textWidget = tester.widget<Text>(find.text('Submit tax return'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
    });
  });
}
