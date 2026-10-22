import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/domain/next_season_plan.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final closed = Season(
    id: const SeasonId('se1'),
    label: '2026-2027',
    startDate: DateTime(2026, 9),
    endDate: DateTime(2027, 6, 30),
    closedOn: DateTime(2026, 10, 12),
  );

  Group origin({int students = 3, String name = 'Mardi'}) {
    var group = Group(
      id: GroupId('g-${name.toLowerCase()}'),
      seasonId: closed.id,
      name: name,
      audience: Audience.children,
    );
    for (var i = 0; i < students; i++) {
      group = group.admit(
        studentId: StudentId('s$i'),
        studentAudience: Audience.children,
        from: DateTime(2026, 9),
      );
    }
    return group;
  }

  NextSeasonPlan? plan(
    List<Group> groups, {
    Set<StudentId> erased = const {},
    List<Season> seasons = const [],
    int? chunk,
  }) => planNextSeason(
    closed: closed,
    day: DateTime(2026, 10, 12),
    seasons: [closed, ...seasons],
    groups: groups,
    erased: erased,
    newSeasonId: const SeasonId('se2'),
    newGroupId: (o) => GroupId('new-${o.id.value}'),
    chunk: chunk,
  );

  test(
    'creates the next season and one step per group, all students at once',
    () {
      final result = plan([origin()])!;

      expect(result.seasonToSave!.id, const SeasonId('se2'));
      expect(result.steps, hasLength(1));
      expect(result.steps.single.moved, 3);
      expect(result.steps.single.destination.id, const GroupId('new-g-mardi'));
      expect(result.steps.single.destination.name, 'Mardi');
      expect(
        result.steps.single.destination.memberships.where((m) => m.to == null),
        hasLength(3),
      );
      expect(
        result.steps.single.released.memberships.where((m) => m.to == null),
        isEmpty,
      );
    },
  );

  test('erased students are neither released nor admitted', () {
    final result = plan([origin()], erased: {const StudentId('s1')})!;

    expect(result.steps.single.moved, 2);
    expect(
      result.steps.single.destination.memberships.map((m) => m.studentId),
      isNot(contains(const StudentId('s1'))),
    );
  });

  test('a chunk cuts a big group in cumulative steps', () {
    final result = plan([origin(students: 5)], chunk: 2)!;

    expect([for (final s in result.steps) s.moved], [2, 2, 1]);
    // Chaque étape contient les précédentes : l'écriture d'un groupe ne change
    // que ce qui diffère.
    expect(
      [
        for (final s in result.steps)
          s.destination.memberships.where((m) => m.to == null).length,
      ],
      [2, 4, 5],
    );
    expect(
      [
        for (final s in result.steps)
          s.released.memberships.where((m) => m.to != null).length,
      ],
      [2, 4, 5],
    );
  });

  test('a group without students is still prepared, by an empty step', () {
    final result = plan([origin(students: 0)])!;

    expect(result.steps, hasLength(1));
    expect(result.steps.single.moved, 0);
  });

  test('an existing closed next season leaves nothing to prepare', () {
    final next = Season(
      id: const SeasonId('se2'),
      label: '2027-2028',
      startDate: DateTime(2027, 7),
      endDate: DateTime(2028, 6, 30),
      closedOn: DateTime(2027, 12),
    );

    expect(plan([origin()], seasons: [next]), isNull);
  });

  test('an existing open next season is reused, not created again', () {
    final next = Season(
      id: const SeasonId('se2'),
      label: '2027-2028',
      startDate: DateTime(2027, 7),
      endDate: DateTime(2028, 6, 30),
    );

    final result = plan([origin()], seasons: [next])!;

    expect(result.seasonToSave, isNull);
  });

  test('a replay after the destination was written does not admit twice', () {
    // État d'une reprise : la destination (id dérivé) existe déjà avec les
    // élèves admis, l'origine n'est pas encore libérée.
    final first = plan([origin()])!;
    final destination = first.steps.single.destination;
    final next = Season(
      id: const SeasonId('se2'),
      label: first.seasonToSave!.label,
      startDate: first.seasonToSave!.startDate,
      endDate: first.seasonToSave!.endDate,
    );

    final replay = plan([origin(), destination], seasons: [next])!;

    expect(
      replay.steps.single.destination.memberships,
      destination.memberships,
    );
    expect(
      replay.steps.single.released.memberships.where((m) => m.to == null),
      isEmpty,
      reason: 'l’origine est libérée à la reprise',
    );
  });

  test('the new group id is asked only for a group that is created', () {
    var asked = 0;
    final result = planNextSeason(
      closed: closed,
      day: DateTime(2026, 10, 12),
      seasons: [closed],
      groups: [
        origin(),
        origin(name: 'Jeudi'),
      ],
      erased: const {},
      newSeasonId: const SeasonId('se2'),
      newGroupId: (o) {
        asked++;
        return GroupId('n-${o.id.value}');
      },
    )!;

    expect(result.steps, hasLength(2));
    expect(asked, 2);
  });
}
