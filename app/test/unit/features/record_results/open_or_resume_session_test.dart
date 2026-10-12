import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/open_or_resume_session.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late OpenOrResumeSession openOrResume;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    openOrResume = OpenOrResumeSession(
      world.groups,
      world.sessions,
      OpenSession(
        world.groups,
        world.seasons,
        world.sessions,
        world.catalogueRepository,
        world.ids,
      ),
    );
  });

  Future<Result<SessionRecord>> call({
    int dayOfMonth = 5,
    Set<String> present = const {'s1'},
    String? main,
    String? recall,
  }) => openOrResume(
    groupId: const GroupId('g1'),
    date: day(dayOfMonth),
    present: {for (final name in present) StudentId(name)},
    mainBlockId: main,
    recallBlockId: recall,
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
}
