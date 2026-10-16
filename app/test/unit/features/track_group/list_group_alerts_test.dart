import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListGroupAlerts list;
  var ids = 0;

  Future<void> miss(String student, String block, {int dayOfMonth = 5}) =>
      world.attempts.add(
        attempt(
          ref(block, 1),
          potted: 0,
          student: student,
          id: 'f${ids++}',
          dayOfMonth: dayOfMonth,
        ),
      );

  setUp(() async {
    world = DomainWorld(config: RulesConfig(passesRequired: 1));
    await world.seedClub(studentNames: ['s1', 's2', 's3']);
    list = ListGroupAlerts(
      world.groups,
      world.seasons,
      world.sessions,
      world.attempts,
      world.acquisitions,
      world.catalogueRepository,
      world.config,
    );
  });

  test('has no alert for a calm club', () async {
    final result = ok(await list(today: day(12)));

    expect(result.lines, isEmpty);
    expect(result.total, 0);
  });

  test('names the group, the technique and the counts', () async {
    await miss('s1', 'a');
    await miss('s2', 'a');

    final result = ok(await list(today: day(12)));

    final line = result.lines.single;
    expect(line.groupId, const GroupId('g1'));
    expect(line.groupName, 'Groupe');
    expect(line.alert.blockId, 'a');
    expect(line.alert.blockTitle, 'Bloc a');
    expect(line.alert.failed, 2);
    expect(line.alert.members, 3);
    expect(result.total, 1);
  });

  test('limits the lines but counts every alert', () async {
    for (final block in ['a', 'b', 'c']) {
      await miss('s1', block);
      await miss('s2', block);
    }

    final result = ok(await list(today: day(12), limit: 2));

    expect(result.lines, hasLength(2));
    expect(result.total, 3);
  });

  test('shows three alerts at most by default', () async {
    expect(defaultGroupAlertLimit, 3);
  });

  test('orders by share, then by teaching order', () async {
    for (final block in ['a', 'b']) {
      await miss('s1', block);
      await miss('s2', block);
    }
    await miss('s3', 'b');

    final result = ok(await list(today: day(12)));

    expect(result.lines.map((l) => l.alert.blockId), ['b', 'a']);
  });

  test('reads every group of the current season only', () async {
    await world.seasons.save(
      Season(
        id: const SeasonId('old'),
        label: '2025-2026',
        startDate: DateTime(2025, 9),
        endDate: DateTime(2026, 6, 30),
      ),
    );
    var other = Group(
      id: const GroupId('g-old'),
      seasonId: const SeasonId('old'),
      name: 'Ancien',
      audience: Audience.children,
    );
    for (final name in ['o1', 'o2']) {
      other = other.admit(
        studentId: StudentId(name),
        studentAudience: Audience.children,
        from: DateTime(2025, 9),
      );
      await world.students.save(
        Student.enroll(
          id: StudentId(name),
          firstName: name,
          audience: Audience.children,
          since: DateTime(2025, 9),
        ),
      );
      await miss(name, 'a');
    }
    await world.groups.save(other);

    final result = ok(await list(today: day(12)));

    expect(result.lines, isEmpty);
  });

  test('ignores a group with a single failing student', () async {
    await miss('s1', 'a');

    expect(ok(await list(today: day(12))).lines, isEmpty);
  });
}
