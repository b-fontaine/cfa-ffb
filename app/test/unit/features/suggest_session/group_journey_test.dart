import 'package:billard_cfa/features/suggest_session/domain/group_journey.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  final a = SheetId('posture-1');
  final b = SheetId('posture-2');
  final c = SheetId('demi-bille-1');
  final d = SheetId('demi-bille-2');

  test('marks done sheets, the next one, and the rest as upcoming', () {
    final journey = GroupJourney(done: {a: day(1)}, next: b);

    expect(journey.marksFor([a, b, c]), {
      a: JourneyMark.done,
      b: JourneyMark.next,
      c: JourneyMark.upcoming,
    });
  });

  test('next wins over done: a repeated sheet stays recommended', () {
    final journey = GroupJourney(done: {a: day(1), b: day(2)}, next: b);

    expect(journey.markOf(b), JourneyMark.next);
    expect(journey.markOf(a), JourneyMark.done);
  });

  test('a technique with several parts has one mark per part', () {
    final journey = GroupJourney(done: {c: day(1)}, next: d);

    expect(journey.marksFor([c, d, a]), {
      c: JourneyMark.done,
      d: JourneyMark.next,
      a: JourneyMark.upcoming,
    });
  });

  test('a skipped part stays upcoming', () {
    final journey = GroupJourney(done: {d: day(1)});

    expect(journey.markOf(c), JourneyMark.upcoming);
    expect(journey.markOf(d), JourneyMark.done);
  });

  test('no next sheet marks only the done ones', () {
    final journey = GroupJourney(done: {a: day(1)});

    expect(
      journey.marksFor([a, b]).values.where((m) => m == JourneyMark.next),
      isEmpty,
    );
  });
}
