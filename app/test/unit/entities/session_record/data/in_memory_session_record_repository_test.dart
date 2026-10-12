import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

SessionRecord session(
  String id,
  String group,
  int dayOfMonth,
  Set<String> who,
) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('s'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: {for (final name in who) StudentId(name)},
);

void main() {
  late InMemorySessionRecordRepository repository;

  setUp(() async {
    repository = InMemorySessionRecordRepository();
    await repository.save(session('late', 'g1', 20, {'a', 'b'}));
    await repository.save(session('early', 'g1', 5, {'a'}));
    await repository.save(session('other', 'g2', 10, {'a'}));
  });

  test('finds a session by id', () async {
    expect((await repository.byId(const SessionId('early')))!.date, day(5));
    expect(await repository.byId(const SessionId('zz')), isNull);
  });

  test('lists the sessions of a group, oldest first', () async {
    final sessions = await repository.forGroup(const GroupId('g1'));

    expect(sessions.map((s) => s.id.value), ['early', 'late']);
  });

  test('lists the sessions attended by a student, oldest first', () async {
    final sessions = await repository.forStudent(const StudentId('a'));

    expect(sessions.map((s) => s.id.value), ['early', 'other', 'late']);
  });

  test('skips sessions a student did not attend', () async {
    final sessions = await repository.forStudent(const StudentId('b'));

    expect(sessions.map((s) => s.id.value), ['late']);
  });
}
