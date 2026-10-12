import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/in_memory_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

class FixedCatalogueRepository implements CatalogueRepository {
  FixedCatalogueRepository(this.catalogue);

  final ExerciseCatalogue catalogue;

  @override
  Future<ExerciseCatalogue> load() async => catalogue;
}

class CountingIds implements IdGenerator {
  int _counter = 0;

  @override
  String next() => 'id-${++_counter}';
}

/// Dépôts en mémoire + catalogue de test + configuration, pour tester les cas
/// d'usage sans mock (le domaine pur se teste avec de vrais objets).
class DomainWorld {
  DomainWorld({ExerciseCatalogue? catalogue, RulesConfig? config})
    : catalogue = catalogue ?? defaultCatalogue(),
      config = config ?? RulesConfig();

  final ExerciseCatalogue catalogue;
  final RulesConfig config;
  final attempts = InMemoryAttemptRepository();
  final sessions = InMemorySessionRecordRepository();
  final groups = InMemoryGroupRepository();
  final seasons = InMemorySeasonRepository();
  final students = InMemoryStudentRepository();
  final assessments = InMemoryAssessmentRepository();
  final ids = CountingIds();

  late final catalogueRepository = FixedCatalogueRepository(catalogue);

  static ExerciseCatalogue defaultCatalogue() => buildCatalogue();

  /// Saison du 1er au 31 octobre 2026 et groupe `g1` (enfants) dont les
  /// élèves donnés sont membres depuis le 1er.
  Future<void> seedClub({
    List<String> studentNames = const ['s1'],
    Audience audience = Audience.children,
  }) async {
    await seasons.save(
      Season(
        id: const SeasonId('season'),
        label: '2026-2027',
        startDate: day(1),
        endDate: day(31),
      ),
    );
    var group = Group(
      id: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      name: 'Groupe',
      audience: audience,
    );
    for (final name in studentNames) {
      group = group.admit(
        studentId: StudentId(name),
        studentAudience: audience,
        from: day(1),
      );
      await students.save(
        Student.enroll(
          id: StudentId(name),
          firstName: name,
          audience: audience,
          since: day(1),
        ),
      );
    }
    await groups.save(group);
  }

  Future<SessionRecord> session({
    String id = 'x1',
    int dayOfMonth = 1,
    Set<String> present = const {'s1'},
    Audience audience = Audience.children,
    String? main,
    String? recall,
  }) async {
    final record = SessionRecord(
      id: SessionId(id),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: day(dayOfMonth),
      audience: audience,
      present: {for (final name in present) StudentId(name)},
      mainBlockId: main,
      recallBlockId: recall,
    );
    await sessions.save(record);
    return record;
  }
}

/// Valeur d'un résultat attendu en succès.
T ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('échec inattendu : $failure'),
};

/// Échec d'un résultat attendu en échec.
Failure err<T>(Result<T> result) => switch (result) {
  Ok(:final value) => fail('succès inattendu : $value'),
  Err(:final failure) => failure,
};

/// Code de la violation d'un résultat attendu en échec d'invariant.
InvariantCode codeOf<T>(Result<T> result) => switch (err(result)) {
  InvariantViolation(:final code) => code,
  final other => fail('pas une violation : $other'),
};
