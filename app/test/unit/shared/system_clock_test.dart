import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the current time', () {
    final before = DateTime.now();
    final now = SystemClock().now();
    final after = DateTime.now();

    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });
}
