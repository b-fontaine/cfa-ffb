import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/list_watched_students.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  var ids = 0;

  ListWatchedStudents build() => ListWatchedStudents(
    world.students,
    world.attempts,
    world.acquisitions,
    world.catalogueRepository,
    world.config,
  );

  Future<void> fail(String student, int count, {int block = 1}) async {
    for (var i = 0; i < count; i++) {
      await world.attempts.add(
        attempt(
          ref('a', block),
          potted: 2,
          student: student,
          dayOfMonth: 1 + i,
          id: 'f${ids++}',
        ),
      );
    }
  }

  test('lists nobody when the club has no alert', () async {
    world = DomainWorld();
    await world.seedClub();

    final list = ok(await build()());

    expect(list.lines, isEmpty);
    expect(list.total, 0);
  });

  test('gives the student, the exercise and the level', () async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['Léa']);
    await fail('Léa', 3);

    final list = ok(await build()());

    final line = list.lines.single;
    expect(line.student.firstName, 'Léa');
    expect(line.watched.exercise, ref('a', 1));
    expect(line.watched.alert, AlertLevel.attention);
    expect(line.watched.consecutiveFailures, 3);
  });

  test('orders persistent first, then failures, then student id', () async {
    world = DomainWorld();
    // L'identifiant départage : 'B' (66) précède 'a' (97), alors que l'ordre
    // alphabétique des prénoms donnerait l'inverse.
    await world.seedClub(studentNames: ['a', 'B', 'Hugo', 'Marc']);
    await fail('a', 3);
    await fail('B', 3);
    await fail('Hugo', 5);
    await fail('Marc', 4);

    final list = ok(await build()());

    expect(
      [for (final l in list.lines) l.student.firstName],
      ['Hugo', 'Marc', 'B', 'a'],
    );
  });

  test('limits the lines but counts every student to watch', () async {
    world = DomainWorld();
    final names = ['s1', 's2', 's3', 's4', 's5', 's6', 's7'];
    await world.seedClub(studentNames: names);
    for (final name in names) {
      await fail(name, 3);
    }

    final list = ok(await build()());

    expect(list.lines, hasLength(5));
    expect(list.total, 7);
  });

  test('honours another limit', () async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    await fail('s1', 3);
    await fail('s2', 3);

    final list = ok(await build()(limit: 1));

    expect(list.lines, hasLength(1));
    expect(list.total, 2);
  });

  test('does not list a student whose exercise is validated', () async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1']);
    await fail('s1', 3);
    for (var i = 0; i < 5; i++) {
      await world.attempts.add(
        attempt(ref('a', 1), potted: 3, dayOfMonth: 10 + i % 2, id: 'ok$i'),
      );
    }

    final list = ok(await build()());

    expect(list.total, 0);
  });

  test('names the blocks so that the lines can be titled', () async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['Léa']);
    await fail('Léa', 3);

    final list = ok(await build()());

    expect(list.blockLabels.keys, contains('a'));
    expect(list.blockLabels['a']!.title, isNotEmpty);
  });
}
