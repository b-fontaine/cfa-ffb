import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

import 'fixed_clock.dart';

/// Monde des scénarios d'interface : graphe get_it réel (dépôts en mémoire,
/// catalogue de l'asset, horloge figée) et amorçage du club par les cas
/// d'usage, comme le fera l'application.
///
/// Les étapes `Given` peuvent précéder `the app is running` : [prepare] est
/// idempotent pour un scénario.
class UiWorld {
  UiWorld._();

  /// « Aujourd'hui » des scénarios.
  static final today = DateTime(2026, 10, 12, 9, 30);

  static late FixedClock _clock;
  static bool _ready = false;
  static int _seededDays = 0;

  static Future<void> prepare(WidgetTester tester) async {
    if (_ready) return;
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    await getIt.unregister<Clock>();
    _clock = FixedClock(today);
    getIt.registerSingleton<Clock>(_clock);
    _ready = true;
    _seededDays = 0;
    addTearDown(() async {
      _ready = false;
      await getIt.reset();
    });
    // Le chargement d'asset est de l'E/S réelle : une fois le catalogue et les
    // schémas en cache, les écrans les lisent sans attendre.
    await tester.runAsync(() async {
      await getIt<CatalogueRepository>().load();
      await getIt<DiagramRepository>().load();
      await getIt<SessionSheetRepository>().getAll();
    });
  }

  /// Fait avancer « aujourd'hui » sans reconstruire les écrans ouverts.
  static void advanceDays(int days) => _clock.advance(Duration(days: days));

  static T _value<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('échec inattendu : $failure'),
  };

  static Audience audience(String label) => switch (label) {
    'children' => Audience.children,
    'adults' => Audience.adults,
    _ => throw ArgumentError('public inconnu : $label'),
  };

  static ExerciseRef exercise(String label) {
    final cut = label.lastIndexOf(' ');
    return ExerciseRef(
      blockId: label.substring(0, cut),
      number: int.parse(label.substring(cut + 1)),
    );
  }

  static Future<Student> studentNamed(String name) async {
    final students = await getIt<StudentRepository>().all();
    return students.firstWhere((student) => student.firstName == name);
  }

  static Future<void> enroll(
    WidgetTester tester,
    String name,
    Audience audience,
  ) async {
    await prepare(tester);
    await tester.runAsync(() async {
      _value(
        await getIt<EnrollStudent>()(
          firstName: name,
          audience: audience,
          today: DateTime(today.year, today.month, today.day),
          groupName: switch (audience) {
            Audience.children => 'Children group',
            Audience.adults => 'Adults group',
          },
        ),
      );
    });
  }

  /// [count] passages réussis (taux requis exact) ou manqués (une bille de
  /// moins), deux par séance passée au plus, dans l'ordre chronologique.
  static Future<void> seedPasses(
    WidgetTester tester,
    String name,
    ExerciseRef exercise,
    int count, {
    required bool passed,
  }) async {
    await prepare(tester);
    await tester.runAsync(() async {
      final student = await studentNamed(name);
      final groups = await getIt<GroupRepository>().all();
      final group = groups.firstWhere((g) => g.isMemberOn(student.id, today));
      final catalogue = await getIt<CatalogueRepository>().load();
      final rate = catalogue.exercise(exercise)!.rate;
      var remaining = count;
      while (remaining > 0) {
        final session = _value(
          await getIt<OpenSession>()(
            groupId: group.id,
            date: DateTime(2026, 9, 12).add(Duration(days: _seededDays++)),
            present: {student.id},
          ),
        );
        for (var pass = 0; pass < 2 && remaining > 0; pass++, remaining--) {
          _value(
            await getIt<RecordAttempt>()(
              sessionId: session.id,
              studentId: student.id,
              exercise: exercise,
              potted: passed ? rate.successes : rate.successes - 1,
              total: rate.attempts,
            ),
          );
        }
      }
    });
  }

  static Future<void> seedValidatedBlock(
    WidgetTester tester,
    String name,
    String blockId,
  ) async {
    await prepare(tester);
    final catalogue = await tester.runAsync(
      () => getIt<CatalogueRepository>().load(),
    );
    for (final spec in catalogue!.blockById(blockId)!.exercises) {
      await seedPasses(tester, name, spec.ref, 5, passed: true);
    }
  }

  /// Marque [blockId] acquis au positionnement le [date] (cas d'usage réel).
  static Future<void> seedAcquired(
    WidgetTester tester,
    String name,
    String blockId,
    DateTime date,
  ) async {
    await prepare(tester);
    await tester.runAsync(() async {
      final student = await studentNamed(name);
      _value(
        await getIt<MarkBlockAcquired>()(
          studentId: student.id,
          blockId: blockId,
          date: date,
          today: DateTime(today.year, today.month, today.day),
        ),
      );
    });
  }

  static Future<int> attemptCountOf(String name) async {
    final student = await studentNamed(name);
    return (await getIt<AttemptRepository>().forStudent(student.id)).length;
  }
}
