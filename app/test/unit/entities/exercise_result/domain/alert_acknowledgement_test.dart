import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

AlertAcknowledgement build({DateTime? date}) => AlertAcknowledgement(
  id: const AcknowledgementId('k1'),
  studentId: const StudentId('s1'),
  exercise: ref('a', 1),
  lastAttemptId: const AttemptId('p3'),
  date: date ?? day(5),
);

void main() {
  test('keeps its fields', () {
    final acknowledgement = build();

    expect(acknowledgement.id, const AcknowledgementId('k1'));
    expect(acknowledgement.studentId, const StudentId('s1'));
    expect(acknowledgement.exercise, ref('a', 1));
    expect(acknowledgement.lastAttemptId, const AttemptId('p3'));
    expect(acknowledgement.date, day(5));
  });

  test('refuses a date carrying a time of day', () {
    expect(
      () => build(date: DateTime(2026, 10, 5, 14, 30)),
      violation(InvariantCode.invalidRange),
    );
  });
}
