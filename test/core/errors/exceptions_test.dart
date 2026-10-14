import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';

void main() {
  test('DatabaseException toString formats message correctly', () {
    const exception = DatabaseException('disk I/O error');
    expect(exception.toString(), 'DatabaseException: disk I/O error');
  });
}
