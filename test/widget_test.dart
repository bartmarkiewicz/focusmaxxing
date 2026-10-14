import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/main.dart';

void main() {
  testWidgets('FocusmaxxingApp launches and displays app title', (tester) async {
    await tester.pumpWidget(const FocusmaxxingApp());
    await tester.pumpAndSettle();

    expect(find.text('Focusmaxxing'), findsOneWidget);
  });
}
