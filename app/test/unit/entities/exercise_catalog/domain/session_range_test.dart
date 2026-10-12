import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  test('accepts min equal to max', () {
    expect(SessionRange(min: 2, max: 2).max, 2);
  });

  test('accepts min 1', () {
    expect(SessionRange(min: 1, max: 2).min, 1);
  });

  test('refuses min 0', () {
    expect(
      () => SessionRange(min: 0, max: 2),
      violation(InvariantCode.invalidRange),
    );
  });

  test('refuses min above max', () {
    expect(
      () => SessionRange(min: 3, max: 2),
      violation(InvariantCode.invalidRange),
    );
  });
}
