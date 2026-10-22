import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_group/domain/get_group_overview.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetGroupOverview overview;
  var ids = 0;

  /// Un exercice validé par un seul passage réussi (passesRequired = 1).
  Future<void> validate(String student, String block, int number) =>
      world.attempts.add(
        attempt(
          ref(block, number),
          potted: 3,
          student: student,
          id: 'v${ids++}',
          dayOfMonth: 2,
        ),
      );

  Future<void> misses(String student, String block, int count) async {
    for (var i = 0; i < count; i++) {
      await world.attempts.add(
        attempt(
          ref(block, 1),
          potted: 0,
          student: student,
          id: 'f${ids++}',
          dayOfMonth: 3 + i,
        ),
      );
    }
  }

  Future<GroupGrid> open({int today = 20}) => overview(
    groupId: const GroupId('g1'),
    today: day(today),
  ).then<GroupGrid>(ok);

  setUp(() async {
    world = DomainWorld(config: RulesConfig(passesRequired: 1));
    await world.seedClub(studentNames: ['Théo', 'Léa', 'Hugo']);
    overview = GetGroupOverview(
      world.groups,
      world.students,
      world.seasons,
      world.sessions,
      world.attempts,
      world.acquisitions,
      world.acknowledgements,
      world.catalogueRepository,
      world.config,
    );
  });

  test('rates each cell from its exact fraction, at the borders', () {
    GridCell cell(int done, int total) => GridCell(
      studentId: const StudentId('s'),
      status: BlockStatus.inProgress,
      doneCount: done,
      total: total,
      alerted: false,
    );

    expect(cell(0, 4).tier, HeatTier.none);
    expect(cell(1, 4).tier, HeatTier.some);
    expect(cell(2, 4).tier, HeatTier.most);
    expect(cell(3, 4).tier, HeatTier.most);
    expect(cell(4, 4).tier, HeatTier.all);
    expect(cell(1, 3).tier, HeatTier.some);
    expect(cell(2, 3).tier, HeatTier.most);
    expect(cell(1, 1).tier, HeatTier.all);
  });

  test('refuses an unknown group', () async {
    final failure = err(
      await overview(groupId: const GroupId('nope'), today: day(20)),
    );

    expect(failure, isA<NotFound>().having((e) => e.kind, 'kind', 'group'));
  });

  test('names the group and puts the current members in columns', () async {
    final grid = await open();

    expect(grid.groupId, const GroupId('g1'));
    expect(grid.name, 'Groupe');
    expect(grid.students.map((s) => s.firstName), ['Hugo', 'Léa', 'Théo']);
  });

  test('leaves out a student who left the group before today', () async {
    final group = (await world.groups.byId(const GroupId('g1')))!;
    await world.groups.save(
      group.release(studentId: const StudentId('Hugo'), to: day(10)),
    );

    final grid = await open();

    expect(grid.students.map((s) => s.firstName), ['Léa', 'Théo']);
  });

  test('counts an unknown member in the alert like the home list', () async {
    final group = await world.groups.byId(const GroupId('g1'));
    await world.groups.save(
      group!.admit(
        studentId: const StudentId('ghost'),
        studentAudience: Audience.children,
        from: day(1),
      ),
    );
    for (final name in ['Léa', 'Théo']) {
      await misses(name, 'b', 1);
    }
    await world.session(dayOfMonth: 2, present: {'Léa', 'Théo'});

    final grid = await open();

    expect(grid.students, hasLength(3));
    expect(grid.alerts.single.members, 4);
  });

  test(
    'leaves out a student who has not joined yet at the given day',
    () async {
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.students.create(
        Student.enroll(
          id: const StudentId('Eve'),
          firstName: 'Eve',
          audience: Audience.children,
          since: day(10),
        ),
      );
      await world.groups.save(
        group.admit(
          studentId: const StudentId('Eve'),
          studentAudience: Audience.children,
          from: day(10),
        ),
      );

      expect((await open(today: 5)).students.map((s) => s.firstName), [
        'Hugo',
        'Léa',
        'Théo',
      ]);
      expect(
        (await open(today: 10)).students.map((s) => s.firstName),
        contains('Eve'),
      );
    },
  );

  test('breaks a tie on the first name by the identifier', () async {
    var group = (await world.groups.byId(const GroupId('g1')))!;
    for (final id in ['z2', 'z1']) {
      group = group.admit(
        studentId: StudentId(id),
        studentAudience: Audience.children,
        from: day(1),
      );
      await world.students.create(
        Student.enroll(
          id: StudentId(id),
          firstName: 'Zoé',
          audience: Audience.children,
          since: day(1),
        ),
      );
    }
    await world.groups.save(group);

    final grid = await open();

    expect(
      grid.students.where((s) => s.firstName == 'Zoé').map((s) => s.id.value),
      ['z1', 'z2'],
    );
  });

  test(
    'has one row per technique, in teaching order, aligned on students',
    () async {
      final grid = await open();

      expect(grid.rows.map((r) => r.technique.blockId), ['a', 'b', 'c']);
      expect(grid.rows.map((r) => r.technique.title), [
        'Bloc a',
        'Bloc b',
        'Bloc c',
      ]);
      for (final row in grid.rows) {
        expect(row.cells.map((c) => c.studentId), [
          const StudentId('Hugo'),
          const StudentId('Léa'),
          const StudentId('Théo'),
        ]);
      }
    },
  );

  test('gives each cell its fraction and its status', () async {
    await validate('Léa', 'a', 1);
    await validate('Léa', 'a', 2);
    await validate('Théo', 'a', 1);
    await validate('Théo', 'a', 2);
    await validate('Théo', 'a', 3);

    final grid = await open();

    final row = grid.rows.first;
    final byStudent = {for (final c in row.cells) c.studentId.value: c};
    expect(byStudent['Hugo']!.status, BlockStatus.notStarted);
    expect(byStudent['Hugo']!.doneCount, 0);
    expect(byStudent['Léa']!.status, BlockStatus.inProgress);
    expect(byStudent['Léa']!.doneCount, 2);
    expect(byStudent['Léa']!.total, 3);
    expect(byStudent['Théo']!.status, BlockStatus.mastered);
    expect(byStudent['Théo']!.doneCount, 3);
  });

  test('counts a block acquired at placement as done', () async {
    await world.acquisitions.add(acquisition('b', student: 'Hugo'));

    final grid = await open();

    final cell = grid.rows[1].cells.first;
    expect(cell.studentId, const StudentId('Hugo'));
    expect(cell.status, BlockStatus.acquiredAtPlacement);
    expect(cell.doneCount, 3);
  });

  test(
    'marks a cell with an active alert, not one the instructor saw',
    () async {
      await misses('Léa', 'a', 3);

      var cell = (await open()).rows.first.cells[1];
      expect(cell.studentId, const StudentId('Léa'));
      expect(cell.alerted, isTrue);
      expect(cell.status, BlockStatus.toReview);

      final last = (await world.attempts.forStudent(const StudentId('Léa')))
          .last;
      await world.acknowledgements.add(
        acknowledgement(
          ref('a', 1),
          lastAttempt: last.id.value,
          student: 'Léa',
        ),
      );

      cell = (await open()).rows.first.cells[1];
      expect(cell.alerted, isFalse);
      expect(cell.status, BlockStatus.inProgress);
    },
  );

  test('summarises each row by finished, in progress and to start', () async {
    await validate('Théo', 'a', 1);
    await validate('Théo', 'a', 2);
    await validate('Théo', 'a', 3);
    await validate('Léa', 'a', 1);

    final row = (await open()).rows.first;

    expect(row.finished.map((id) => id.value), ['Théo']);
    expect(row.inProgress.map((id) => id.value), ['Léa']);
    expect(row.toStart.map((id) => id.value), ['Hugo']);
  });

  test('counts the attendance of each student and of the group', () async {
    await world.session(dayOfMonth: 3, present: {'Léa', 'Théo'});
    await world.session(id: 'x2', dayOfMonth: 10, present: {'Léa'});

    final grid = await open();

    final byName = {for (final s in grid.students) s.firstName: s.attendance};
    expect(byName['Léa']!.attended, 2);
    expect(byName['Léa']!.total, 2);
    expect(byName['Hugo']!.attended, 0);
    expect(grid.attendance.present, 3);
    expect(grid.attendance.possible, 6);
    expect(grid.attendance.sessionCount, 2);
  });

  test('dates the attendance by the given day', () async {
    await world.session(dayOfMonth: 3, present: {'Léa'});
    await world.session(id: 'x2', dayOfMonth: 15, present: {'Léa'});

    final grid = await open(today: 10);

    expect(grid.attendance.sessionCount, 1);
  });

  test('raises a group alert from the settings share', () async {
    for (final name in ['Léa', 'Théo']) {
      await misses(name, 'b', 1);
    }
    await world.session(dayOfMonth: 2, present: {'Léa', 'Théo'});

    final grid = await open();

    // 2 sur 3 membres ont manqué la technique b à leur dernier passage.
    final alert = grid.alerts.single;
    expect(alert.blockId, 'b');
    expect(alert.failed, 2);
    expect(alert.members, 3);
  });

  test(
    'a group alert ignores the acknowledgement of an individual alert',
    () async {
      await misses('Léa', 'a', 3);
      await misses('Théo', 'a', 3);
      final last = (await world.attempts.forStudent(const StudentId('Léa')))
          .last;
      await world.acknowledgements.add(
        acknowledgement(
          ref('a', 1),
          lastAttempt: last.id.value,
          student: 'Léa',
        ),
      );

      final grid = await open();

      expect(grid.alerts.single.failed, 2);
    },
  );

  test('reads the share of the settings given to the use case', () async {
    for (final name in ['Léa', 'Théo']) {
      await misses(name, 'b', 1);
    }
    final strict = GetGroupOverview(
      world.groups,
      world.students,
      world.seasons,
      world.sessions,
      world.attempts,
      world.acquisitions,
      world.acknowledgements,
      world.catalogueRepository,
      RulesConfig(passesRequired: 1, groupFailureSharePercent: 100),
    );

    final grid = ok(await strict(groupId: const GroupId('g1'), today: day(20)));

    // 2 membres sur 3 : sous les 100 % demandés.
    expect(grid.alerts, isEmpty);
  });

  test('the columns of a season that has not started are its first-day '
      'roster', () async {
    await world.seasons.save(
      Season(
        id: const SeasonId('next'),
        label: 'suite',
        startDate: day(25),
        endDate: DateTime(2027, 8, 31),
      ),
    );
    await world.groups.save(
      Group(
        id: const GroupId('gn'),
        seasonId: const SeasonId('next'),
        name: 'Suite',
        audience: Audience.children,
      ).admit(
        studentId: const StudentId('Léa'),
        studentAudience: Audience.children,
        from: day(25),
      ),
    );

    final grid = ok(
      await overview(groupId: const GroupId('gn'), today: day(20)),
    );

    expect(grid.students.map((s) => s.firstName), ['Léa']);
  });
}
