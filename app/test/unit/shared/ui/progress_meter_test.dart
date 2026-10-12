import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:flutter_test/flutter_test.dart';

ProgressMeter _meter(int value) =>
    ProgressMeter(value: value, maximum: 5, label: 'x');

void main() {
  test('accepts the bounds of the range', () {
    expect(() => _meter(0), returnsNormally);
    expect(() => _meter(5), returnsNormally);
  });

  test('refuses a value outside the range', () {
    expect(() => _meter(-1), throwsAssertionError);
    expect(() => _meter(6), throwsAssertionError);
  });
}
