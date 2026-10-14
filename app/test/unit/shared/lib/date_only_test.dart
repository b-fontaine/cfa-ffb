import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two moments of the same day are the same day', () {
    expect(
      DateTime(2026, 10, 12, 9, 30).isSameDayAs(DateTime(2026, 10, 12, 21)),
      isTrue,
    );
    expect(
      DateTime(2026, 10, 12, 23).isSameDayAs(DateTime(2026, 10, 13)),
      isFalse,
    );
    expect(DateTime(2026, 10, 12).isSameDayAs(DateTime(2025, 10, 12)), isFalse);
  });

  test('dateOnly drops the time and keeps the local day', () {
    expect(DateTime(2026, 10, 12, 23, 59).dateOnly, DateTime(2026, 10, 12));
    expect(DateTime(2026, 10, 12).dateOnly, DateTime(2026, 10, 12));
  });
}
