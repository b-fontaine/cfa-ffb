import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

SessionRecord build({
  Audience audience = Audience.children,
  String? main,
  String? recall,
}) => SessionRecord(
  id: const SessionId('x'),
  groupId: const GroupId('g'),
  seasonId: const SeasonId('s'),
  date: day(5),
  audience: audience,
  present: {const StudentId('s1')},
  mainBlockId: main,
  recallBlockId: recall,
);

void main() {
  test('plans 90 minutes for children', () {
    expect(build().plannedDurationMinutes, 90);
  });

  test('plans 120 minutes for adults', () {
    expect(build(audience: Audience.adults).plannedDurationMinutes, 120);
  });

  test('accepts a recall block different from the main block', () {
    expect(build(main: 'a', recall: 'b').recallBlockId, 'b');
  });

  test('refuses a recall block equal to the main block', () {
    expect(
      () => build(main: 'a', recall: 'a'),
      violation(InvariantCode.recallEqualsMainBlock),
    );
  });

  test('accepts a recall block without main block', () {
    expect(build(recall: 'a').mainBlockId, isNull);
  });
}
