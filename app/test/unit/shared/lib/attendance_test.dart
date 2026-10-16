import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts the attended sessions among the counted ones', () {
    final result = attendanceFrom([true, false, true, true]);

    expect(result.attended, 3);
    expect(result.total, 4);
  });

  test('is empty without any counted session', () {
    final result = attendanceFrom(const []);

    expect(result.isEmpty, isTrue);
    expect(result.attended, 0);
  });
}
