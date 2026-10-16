import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/open_or_resume_session.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/resolve_sheet_blocks.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

void main() {
  late DomainWorld world;
  late OpenOrResumeSession openOrResume;

  setUp(() async {
    world = DomainWorld(sheets: sheetsOnTestBlocks());
    await world.seedClub(studentNames: ['s1', 's2']);
    final sheetBlocks = ResolveSheetBlocks(world.sheets);
    openOrResume = OpenOrResumeSession(
      world.groups,
      world.sessions,
      sheetBlocks,
      OpenSession(
        world.groups,
        world.seasons,
        world.sessions,
        world.catalogueRepository,
        sheetBlocks,
        world.ids,
      ),
    );
  });

  Future<Result<SessionRecord>> call({
    int dayOfMonth = 5,
    Set<String> present = const {'s1'},
    String? main,
    String? recall,
    String? sheet,
  }) => openOrResume(
    groupId: const GroupId('g1'),
    date: day(dayOfMonth),
    present: {for (final name in present) StudentId(name)},
    mainBlockId: main,
    recallBlockId: recall,
    sheetId: sheet == null ? null : SheetId(sheet),
  );

  test('opens a new session when none exists for that group and day', () async {
    final session = ok(await call(main: 'a'));

    expect(session.present, {const StudentId('s1')});
    expect(session.mainBlockId, 'a');
    expect(await world.sessions.forGroup(const GroupId('g1')), [session]);
  });

  test(
    'resumes the session of the same day and updates the presents',
    () async {
      final first = ok(await call(main: 'a'));

      final second = ok(await call(present: {'s1', 's2'}));

      expect(second.id, first.id);
      expect(second.present, {const StudentId('s1'), const StudentId('s2')});
      expect(second.mainBlockId, 'a');
      expect(await world.sessions.forGroup(const GroupId('g1')), [second]);
    },
  );

  test('resuming keeps the recorded passes of the session', () async {
    final first = ok(await call());
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, session: first.id.value),
    );

    ok(await call(present: {'s1', 's2'}));

    expect(await world.attempts.forSession(first.id), hasLength(1));
  });

  test('sets the blocks of a resumed session when given', () async {
    ok(await call());

    final resumed = ok(await call(main: 'b', recall: 'a'));

    expect(resumed.mainBlockId, 'b');
    expect(resumed.recallBlockId, 'a');
  });

  test('keeps the catalogue session and its blocks when resuming', () async {
    final first = ok(await call(sheet: 'demi-bille-2'));

    final resumed = ok(await call(present: {'s1', 's2'}));

    expect(resumed.id, first.id);
    expect(resumed.sheetId?.value, 'demi-bille-2');
    expect(resumed.mainBlockId, 'b');
    expect(resumed.recallBlockId, 'a');
  });

  test(
    'derives the missing blocks of a resumed session from the sheet',
    () async {
      ok(await call());

      final resumed = ok(await call(sheet: 'demi-bille-2'));

      expect(resumed.sheetId?.value, 'demi-bille-2');
      expect(resumed.mainBlockId, 'b');
      expect(resumed.recallBlockId, 'a');
    },
  );

  test('keeps the blocks already set over those of the sheet', () async {
    ok(await call(main: 'c'));

    final resumed = ok(await call(sheet: 'demi-bille-2'));

    expect(resumed.mainBlockId, 'c');
    expect(resumed.recallBlockId, 'a', reason: 'rappel dérivé, non donné');
  });

  test(
    'ignores a derived recall equal to the main block already set',
    () async {
      ok(await call(main: 'a'));

      final resumed = ok(await call(sheet: 'demi-bille-2'));

      expect(resumed.mainBlockId, 'a');
      expect(resumed.recallBlockId, isNull);
    },
  );

  test('refuses an unknown sheet when resuming and changes nothing', () async {
    final first = ok(await call(main: 'a'));

    final result = await call(present: {'s1', 's2'}, sheet: 'inconnue-9');

    expect(codeOf(result), InvariantCode.unknownSheet);
    expect(await world.sessions.byId(first.id), first);
  });

  test('opens another session on another day', () async {
    final first = ok(await call());

    final other = ok(await call(dayOfMonth: 6));

    expect(other.id, isNot(first.id));
    expect(await world.sessions.forGroup(const GroupId('g1')), hasLength(2));
  });

  test('refuses a student who is not a member when resuming', () async {
    ok(await call());

    final result = await call(present: {'ghost'});

    expect(codeOf(result), InvariantCode.studentNotInGroup);
    final stored = await world.sessions.forGroup(const GroupId('g1'));
    expect(stored.single.present, {const StudentId('s1')});
  });

  test('refuses an unknown group', () async {
    final result = await openOrResume(
      groupId: const GroupId('nope'),
      date: day(5),
      present: {const StudentId('s1')},
    );

    expect(err(result), isA<NotFound>());
  });

  test('names the missing group when resuming an orphan session', () async {
    await world.sessions.save(
      SessionRecord(
        id: const SessionId('orphan'),
        groupId: const GroupId('ghost'),
        seasonId: const SeasonId('season'),
        date: day(5),
        audience: Audience.children,
        present: const {},
      ),
    );

    final result = await openOrResume(
      groupId: const GroupId('ghost'),
      date: day(5),
      present: {const StudentId('s1')},
    );

    final failure = err(result) as NotFound;
    expect(failure.kind, 'group');
    expect(failure.id, 'ghost');
  });

  // D1 (ADR 0016) : noter une autre séance du catalogue le même jour ouvre
  // une nouvelle saisie et laisse la première intacte.
  test(
    'opens a second session for another catalogue session the same day',
    () async {
      final first = ok(await call(sheet: 'posture-1', present: {'s1', 's2'}));
      final second = ok(await call(sheet: 'demi-bille-2'));

      expect(second.id, isNot(first.id));
      expect(second.sheetId, SheetId('demi-bille-2'));
      final records = await world.sessions.forGroup(const GroupId('g1'));
      expect(records, hasLength(2));
      final kept = records.firstWhere((record) => record.id == first.id);
      expect(kept.sheetId, SheetId('posture-1'));
      expect(kept.present, {const StudentId('s1'), const StudentId('s2')});
    },
  );

  test(
    'resumes the session of the same catalogue session the same day',
    () async {
      final first = ok(await call(sheet: 'posture-1'));
      final again = ok(await call(sheet: 'posture-1', present: {'s1', 's2'}));

      expect(again.id, first.id);
      expect(await world.sessions.forGroup(const GroupId('g1')), hasLength(1));
    },
  );

  // Reprise depuis le formulaire manuel (aucune séance du catalogue demandée) :
  // la saisie du jour est reprise sans perdre sa séance, et une autre saisie
  // du même jour n'est pas touchée (D1 résiduel, ADR 0016, U-1).
  test(
    'resumes without sheet the first record of the day and keeps both',
    () async {
      final posture = ok(await call(sheet: 'posture-1'));
      final demi = ok(await call(sheet: 'demi-bille-2'));

      final resumed = ok(await call(present: {'s1', 's2'}));

      expect(resumed.id, posture.id);
      expect(resumed.sheetId, SheetId('posture-1'));
      expect(resumed.present, {const StudentId('s1'), const StudentId('s2')});
      final records = await world.sessions.forGroup(const GroupId('g1'));
      expect(records, hasLength(2));
      expect(records.firstWhere((r) => r.id == demi.id), demi);
    },
  );

  test('resumes without sheet the record that has no sheet first', () async {
    ok(await call(sheet: 'posture-1'));
    await world.session(id: 'x-free', dayOfMonth: 5);

    final resumed = ok(await call(present: {'s1', 's2'}));

    expect(resumed.id, const SessionId('x-free'));
    expect(resumed.sheetId, isNull);
  });

  test(
    'resumes the session of another day only when it is the same day',
    () async {
      ok(await call(sheet: 'posture-1'));
      ok(await call(dayOfMonth: 6, sheet: 'demi-bille-2'));

      expect(await world.sessions.forGroup(const GroupId('g1')), hasLength(2));
    },
  );
}
