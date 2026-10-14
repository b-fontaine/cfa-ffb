import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

class _FailingSheets implements SessionSheetRepository {
  @override
  Future<List<SessionSheet>> getAll() async =>
      throw const InvariantViolation(InvariantCode.invalidSheet);

  @override
  Future<SessionSheet?> getById(SheetId id) async =>
      throw const InvariantViolation(InvariantCode.invalidSheet);
}

void main() {
  final config = RulesConfig(passesRequired: 1);

  Future<(DomainWorld, SuggestSession)> start({
    Audience audience = Audience.adults,
    List<SessionSheet>? sheets,
    SessionSheetRepository? sheetRepository,
  }) async {
    final world = DomainWorld(config: config, sheets: sheets);
    await world.seedClub(studentNames: ['s1', 's2'], audience: audience);
    return (
      world,
      SuggestSession(
        world.groups,
        world.sessions,
        world.attempts,
        world.acquisitions,
        world.catalogueRepository,
        world.config,
        sheetRepository ?? world.sheets,
        FixedClock(DateTime(2026, 10, 12, 18)),
      ),
    );
  }

  test('refuses an unknown group', () async {
    final (_, suggest) = await start();

    final result = await suggest(
      groupId: const GroupId('nope'),
      expectedStudents: {const StudentId('s1')},
    );

    expect(
      err(result),
      isA<NotFound>()
          .having((n) => n.kind, 'kind', 'group')
          .having((n) => n.id, 'id', 'nope'),
    );
  });

  test('refuses an empty list of expected students', () async {
    final (_, suggest) = await start();

    final result = await suggest(
      groupId: const GroupId('g1'),
      expectedStudents: {},
    );

    expect(codeOf(result), InvariantCode.noStudents);
  });

  test('plans from the stored passes of the expected students', () async {
    final (world, suggest) = await start();
    await world.attempts.add(attempt(ref('a', 1), potted: 3, id: 'p1'));
    await world.attempts.add(attempt(ref('a', 2), potted: 3, id: 'p2'));
    await world.attempts.add(attempt(ref('a', 3), potted: 3, id: 'p3'));
    await world.attempts.add(
      attempt(ref('a', 3), potted: 1, dayOfMonth: 2, id: 'p4'),
    );

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1'), const StudentId('s2')},
      ),
    );

    expect(plan.durationMinutes, 120);
    expect(plan.mainBlockId, 'a');
    expect(plan.exercises.first, ref('a', 1));
  });

  test(
    'skips a block acquired at placement by the expected students',
    () async {
      final (world, suggest) = await start();
      await world.acquisitions.add(acquisition('a'));
      await world.acquisitions.add(acquisition('a', student: 's2', id: 'q2'));

      final plan = ok(
        await suggest(
          groupId: const GroupId('g1'),
          expectedStudents: {const StudentId('s1'), const StudentId('s2')},
        ),
      );

      expect(plan.mainBlockId, 'b');
      expect(plan.exercises.first, ref('b', 1));
    },
  );

  test('recalls a stale notion using the group sessions', () async {
    final (world, suggest) = await start();
    for (var n = 1; n <= 3; n++) {
      await world.attempts.add(attempt(ref('a', n), potted: 3, id: 'p$n'));
    }
    for (var d = 2; d <= 5; d++) {
      await world.session(id: 'x$d', dayOfMonth: d);
    }

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1')},
      ),
    );

    expect(plan.mainBlockId, 'b');
    expect(plan.recallBlockId, 'a');
  });

  test('plans 90 minutes for a children group', () async {
    final (_, suggest) = await start(audience: Audience.children);

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1')},
      ),
    );

    expect(plan.durationMinutes, 90);
    expect(plan.recallBlockId, isNull);
  });

  group('catalogue session', () {
    final both = {const StudentId('s1'), const StudentId('s2')};

    Future<void> given(
      DomainWorld world,
      String id,
      SheetId sheet, {
      int dayOfMonth = 5,
      bool withPass = true,
    }) async {
      await world.session(id: id, dayOfMonth: dayOfMonth, sheet: sheet);
      if (withPass) {
        await world.attempts.add(
          attempt(
            ref('b', 1),
            potted: 3,
            id: 'pass-$id',
            session: id,
            dayOfMonth: dayOfMonth,
          ),
        );
      }
    }

    test('proposes the first part when nothing was given', () async {
      final (_, suggest) = await start(sheets: sheetsOnTestBlocks());
      final plan = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(plan.mainBlockId, 'a');
      expect(plan.sheet?.option.id, SheetId('posture-1'));
      expect(plan.sheet?.kind, SheetSuggestionKind.coversHead);
    });

    test(
      'proposes nothing and keeps the exercises without a session',
      () async {
        final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
        for (var n = 1; n <= 3; n++) {
          await world.attempts.add(attempt(ref('a', n), potted: 3, id: 'a$n'));
          await world.attempts.add(attempt(ref('b', n), potted: 3, id: 'b$n'));
        }

        final plan = ok(
          await suggest(
            groupId: const GroupId('g1'),
            expectedStudents: {const StudentId('s1')},
          ),
        );

        expect(plan.mainBlockId, 'c');
        expect(plan.sheet, isNull);
        expect(plan.exercises.first, ref('c', 1));
      },
    );

    test(
      'replaces the exercises by the unvalidated ones of the part',
      () async {
        final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
        for (var n = 1; n <= 3; n++) {
          for (final student in ['s1', 's2']) {
            await world.attempts.add(
              attempt(
                ref('a', n),
                potted: 3,
                id: 'a$n$student',
                student: student,
              ),
            );
          }
        }
        await given(world, 'x1', SheetId('demi-bille-1'));

        final plan = ok(
          await suggest(groupId: const GroupId('g1'), expectedStudents: both),
        );

        expect(plan.mainBlockId, 'b');
        expect(plan.sheet?.option.id, SheetId('demi-bille-2'));
        expect(plan.sheet?.kind, SheetSuggestionKind.nextPending);
        expect(plan.sheet?.headCovered, isFalse);
        expect(plan.sheet?.head, ref('b', 1));
        expect(plan.exercises, [ref('b', 3), ref('b', 4)]);
      },
    );

    test('keeps durations and phases whatever the exercises', () async {
      final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
      for (var n = 1; n <= 3; n++) {
        for (final student in ['s1', 's2']) {
          await world.attempts.add(
            attempt(
              ref('a', n),
              potted: 3,
              id: 'a$n$student',
              student: student,
            ),
          );
        }
      }
      final before = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );
      await given(world, 'x1', SheetId('demi-bille-1'));

      final after = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(after.durationMinutes, before.durationMinutes);
      expect(after.phases, before.phases);
      expect(after.phasesMinutes, after.durationMinutes);
    });

    test('ignores a session opened without a pass', () async {
      final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
      await given(world, 'x1', SheetId('posture-1'), withPass: false);

      final plan = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(plan.sheet?.option.id, SheetId('posture-1'));
    });

    test('proposes the part of a block acquired by only one student', () async {
      final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
      await world.acquisitions.add(acquisition('a'));

      final plan = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(plan.mainBlockId, 'a');
      expect(plan.sheet?.option.id, SheetId('posture-1'));
    });

    test('ignores a session dated after today', () async {
      final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
      await given(world, 'x1', SheetId('posture-1'), dayOfMonth: 20);

      final plan = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(plan.sheet?.option.id, SheetId('posture-1'));
    });

    test('ignores a sheet identifier the catalogue does not know', () async {
      final (world, suggest) = await start(sheets: sheetsOnTestBlocks());
      await given(world, 'x1', SheetId('inconnue-9'));

      final plan = ok(
        await suggest(groupId: const GroupId('g1'), expectedStudents: both),
      );

      expect(plan.sheet?.option.id, SheetId('posture-1'));
    });

    test('fails when the sheet catalogue cannot be read', () async {
      final (_, suggest) = await start(sheetRepository: _FailingSheets());

      final result = await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: both,
      );

      expect(codeOf(result), InvariantCode.invalidSheet);
    });
  });
}
