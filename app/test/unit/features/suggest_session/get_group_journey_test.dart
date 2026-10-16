import 'package:billard_cfa/features/suggest_session/domain/get_group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

/// `posture-1` (bloc a, 1-2), `demi-bille-1` (bloc b, 1-2), `demi-bille-2`
/// (bloc b, 3-4) ; le groupe `g1` a `s1` et `s2`.
void main() {
  late DomainWorld world;
  late GetGroupJourney journey;
  late FixedClock clock;

  Future<void> givenSheet(String id, String sheet, {int dayOfMonth = 2}) async {
    await world.session(id: id, dayOfMonth: dayOfMonth, sheet: SheetId(sheet));
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, id: 'at-$id', session: id),
    );
  }

  setUp(() async {
    clock = FixedClock(DateTime(2026, 10, 12));
    world = DomainWorld(
      config: RulesConfig(passesRequired: 1),
      sheets: sheetsOnTestBlocks(),
    );
    await world.seedClub(studentNames: ['s1', 's2']);
    journey = GetGroupJourney(
      world.groups,
      world.sessions,
      world.attempts,
      world.sheets,
      SuggestNextSheet(
        SuggestSession(
          world.groups,
          world.sessions,
          world.attempts,
          world.acquisitions,
          world.catalogueRepository,
          world.config,
          world.sheets,
          clock,
        ),
      ),
      clock,
    );
  });

  test('refuses an unknown group', () async {
    final result = await journey(const GroupId('nope'));

    expect(err(result), isA<NotFound>());
  });

  test('passes the failure of the next-sheet suggestion on', () async {
    const failure = InvariantViolation(InvariantCode.blankName);
    final failing = GetGroupJourney(
      world.groups,
      world.sessions,
      world.attempts,
      world.sheets,
      _FailingNext(failure),
      clock,
    );

    expect(err(await failing(const GroupId('g1'))), same(failure));
  });

  test('a new group has nothing done and the first sheet next', () async {
    final result = ok(await journey(const GroupId('g1')));

    expect(result.done, isEmpty);
    expect(result.next, SheetId('posture-1'));
    expect(result.noStudents, isFalse);
  });

  test('a sheet given with a pass is done and the next one follows', () async {
    await givenSheet('x1', 'posture-1');
    // posture-1 donnée : le bloc principal reste « a » tant que ses exercices
    // ne sont pas validés ; la règle de la suggestion reste celle d'ADR 0009.
    final result = ok(await journey(const GroupId('g1')));

    expect(result.done.keys, [SheetId('posture-1')]);
    expect(result.done[SheetId('posture-1')], day(2));
    expect(
      result.next,
      ok(
        await SuggestNextSheet(
          SuggestSession(
            world.groups,
            world.sessions,
            world.attempts,
            world.acquisitions,
            world.catalogueRepository,
            world.config,
            world.sheets,
            clock,
          ),
        )(
          groupId: const GroupId('g1'),
          present: {const StudentId('s1'), const StudentId('s2')},
        ),
      ).sheet?.option.id,
    );
  });

  test('a session recorded without any pass is not done', () async {
    await world.session(sheet: SheetId('posture-1'));

    final result = ok(await journey(const GroupId('g1')));

    expect(result.done, isEmpty);
  });

  test('a session without a catalogue sheet is not done', () async {
    await world.session();
    await world.attempts.add(attempt(ref('a', 1), potted: 3));

    expect(ok(await journey(const GroupId('g1'))).done, isEmpty);
  });

  test('a group without students keeps the done sheets, no next', () async {
    final empty = DomainWorld(sheets: sheetsOnTestBlocks());
    await empty.seedClub(studentNames: const []);
    await empty.session(sheet: SheetId('posture-1'));
    await empty.attempts.add(attempt(ref('a', 1), potted: 3));
    final emptyJourney = GetGroupJourney(
      empty.groups,
      empty.sessions,
      empty.attempts,
      empty.sheets,
      SuggestNextSheet(
        SuggestSession(
          empty.groups,
          empty.sessions,
          empty.attempts,
          empty.acquisitions,
          empty.catalogueRepository,
          empty.config,
          empty.sheets,
          clock,
        ),
      ),
      clock,
    );

    final result = ok(await emptyJourney(const GroupId('g1')));

    expect(result.noStudents, isTrue);
    expect(result.next, isNull);
    expect(result.done.keys, [SheetId('posture-1')]);
  });

  test('a notion without a sheet leaves no next sheet', () async {
    final world2 = DomainWorld(
      config: RulesConfig(passesRequired: 1),
      sheets: [],
    );
    await world2.seedClub(studentNames: ['s1']);
    final j = GetGroupJourney(
      world2.groups,
      world2.sessions,
      world2.attempts,
      world2.sheets,
      SuggestNextSheet(
        SuggestSession(
          world2.groups,
          world2.sessions,
          world2.attempts,
          world2.acquisitions,
          world2.catalogueRepository,
          world2.config,
          world2.sheets,
          clock,
        ),
      ),
      clock,
    );

    final result = ok(await j(const GroupId('g1')));

    expect(result.next, isNull);
    expect(result.noStudents, isFalse);
  });
}

/// Une suggestion qui échoue toujours avec [failure].
class _FailingNext implements SuggestNextSheet {
  _FailingNext(this.failure);

  final Failure failure;

  @override
  Future<Result<NextSheet>> call({
    required GroupId groupId,
    required Set<StudentId> present,
  }) async => Err(failure);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
