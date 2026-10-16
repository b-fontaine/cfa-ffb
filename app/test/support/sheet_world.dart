import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/track_group/domain/get_group_overview.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'domain_world.dart';
import 'fixtures.dart';

/// Fiche de l'élève `s1` construite par le vrai cas d'usage sur des dépôts en
/// mémoire : les tests d'interface partent d'un modèle réel, jamais d'un
/// modèle écrit à la main. Le catalogue de test compte trois blocs `a`, `b`,
/// `c` de trois exercices, taux 3 sur 5 ; 5 passages réussis valident un
/// exercice.
class SheetWorld {
  SheetWorld({ExerciseCatalogue? catalogue})
    : world = DomainWorld(catalogue: catalogue);

  final DomainWorld world;
  int _attempts = 0;

  Future<void> start({List<String> students = const ['s1']}) async {
    await world.seedClub(studentNames: students);
    await world.session(dayOfMonth: 2, main: 'a', present: {...students});
  }

  /// [count] passages réussis (ou manqués) de `s1` sur [exercise], l'un après
  /// l'autre dans le temps.
  Future<void> passes(
    ExerciseRef exercise,
    int count, {
    bool pass = true,
    String student = 's1',
  }) async {
    for (var i = 0; i < count; i++) {
      _attempts++;
      await world.attempts.add(
        attempt(
          exercise,
          potted: pass ? 4 : 0,
          id: 'w$_attempts',
          dayOfMonth: 1 + _attempts,
          student: student,
        ),
      );
    }
  }

  Future<void> acquire(String blockId) =>
      world.acquisitions.add(acquisition(blockId, id: 'q$blockId'));

  /// « Vu » sur l'alerte de [exercise], rattaché au dernier passage saisi.
  Future<void> acknowledge(ExerciseRef exercise) => world.acknowledgements.add(
    acknowledgement(exercise, lastAttempt: 'w$_attempts'),
  );

  Future<StudentSheet> sheet(WidgetTester tester) => tester
      .runAsync(
        () => GetStudentSheet(
          world.students,
          world.attempts,
          world.acquisitions,
          world.acknowledgements,
          world.sessions,
          world.groups,
          world.assessments,
          world.catalogueRepository,
          world.config,
        )(const StudentId('s1')),
      )
      .then((result) => ok(result!));

  /// La vue « à montrer à l'élève » de `s1`.
  Future<StudentShowcase> showcase(WidgetTester tester) => tester
      .runAsync(
        () => GetStudentShowcase(
          world.students,
          world.attempts,
          world.acquisitions,
          world.catalogueRepository,
          world.config,
        )(const StudentId('s1')),
      )
      .then((result) => ok(result!));

  /// La vue du groupe `g1` au 12 octobre 2026.
  Future<GroupGrid> grid(WidgetTester tester) => tester
      .runAsync(
        () => GetGroupOverview(
          world.groups,
          world.students,
          world.sessions,
          world.attempts,
          world.acquisitions,
          world.acknowledgements,
          world.catalogueRepository,
          world.config,
        )(groupId: const GroupId('g1'), today: DateTime(2026, 10, 12)),
      )
      .then((result) => ok(result!));
}
