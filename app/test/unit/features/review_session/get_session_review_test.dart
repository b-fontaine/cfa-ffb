import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  const todayRecord = SessionId('x12');

  GetSessionReview build([DateTime? now]) => GetSessionReview(
    world.sessions,
    world.attempts,
    world.acquisitions,
    world.students,
    world.groups,
    world.plannedSessions,
    world.catalogueRepository,
    world.sheets,
    world.config,
    FixedClock(now ?? DateTime(2026, 10, 12, 18)),
  );

  Future<void> plan(String id, int dayOfMonth, {String sheet = 'posture-1'}) =>
      world.plannedSessions.add(
        Session(
          id: id,
          title: id,
          date: day(dayOfMonth),
          audience: Audience.children,
          groupId: const GroupId('g1'),
          sheetId: SheetId(sheet),
        ),
      );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    await world.session(
      id: 'x12',
      dayOfMonth: 12,
      present: {'s1', 's2'},
      sheet: SheetId('posture-1'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, session: 'x12', dayOfMonth: 12),
    );
  });

  test('refuses an unknown record', () async {
    final failure = err(await build()(const SessionId('nope')));

    expect(failure, isA<NotFound>());
  });

  test('gives the record, the sheet, the group and the students', () async {
    final review = ok(await build()(todayRecord));

    expect(review.record.id, todayRecord);
    expect(review.sheet?.id, SheetId('posture-1'));
    expect(review.group?.name, 'Groupe');
    expect([for (final s in review.students.values) s.firstName], ['s1', 's2']);
  });

  test('computes the outcome from the stored passes', () async {
    final review = ok(await build()(todayRecord));

    expect(review.outcome.totalPasses, 1);
    expect([for (final id in review.outcome.unrated) id.value], ['s2']);
  });

  test('proposes the same weekday of the next week, after today', () async {
    final review = ok(await build()(todayRecord));

    expect(review.proposedDate, day(19));
  });

  test('moves the proposed date with the injected clock', () async {
    final review = ok(await build(DateTime(2026, 10, 20))(todayRecord));

    expect(review.proposedDate, day(26));
  });

  test('has no sheet when the record was entered without one', () async {
    await world.sessions.save(
      SessionRecord(
        id: const SessionId('free'),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(8),
        audience: Audience.children,
        present: {const StudentId('s1')},
      ),
    );

    final review = ok(await build()(const SessionId('free')));

    expect(review.sheet, isNull);
  });

  test('does not fail when the catalogue no longer knows the sheet', () async {
    await world.sessions.save(
      SessionRecord(
        id: const SessionId('old'),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(8),
        audience: Audience.children,
        present: {const StudentId('s1')},
        sheetId: SheetId('inconnue-9'),
      ),
    );

    final review = ok(await build()(const SessionId('old')));

    expect(review.sheet, isNull);
  });

  test('has no group when the club no longer knows it', () async {
    await world.groups.delete(const GroupId('g1'));

    final review = ok(await build()(todayRecord));

    expect(review.group, isNull);
  });

  test('lists the sessions planned for the group after today only', () async {
    await plan('past', 5);
    await plan('today', 12);
    await plan('later', 19, sheet: 'posture-2');

    final review = ok(await build()(todayRecord));

    expect([for (final s in review.upcoming) s.id], ['later']);
    expect(review.plannedFor(SheetId('posture-2'))?.date, day(19));
    expect(review.plannedFor(SheetId('posture-1')), isNull);
  });

  test('ignores the sessions planned for another group', () async {
    await world.plannedSessions.add(
      Session(
        id: 'other',
        title: 'other',
        date: day(19),
        audience: Audience.children,
        groupId: const GroupId('g2'),
        sheetId: SheetId('posture-2'),
      ),
    );

    final review = ok(await build()(todayRecord));

    expect(review.upcoming, isEmpty);
  });

  test('names the blocks so that the exercises can be titled', () async {
    final review = ok(await build()(todayRecord));

    expect(review.blockLabels.keys, contains('a'));
    expect(review.blockLabels['a']!.title, 'Bloc a');
  });
}
