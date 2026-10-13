import 'dart:convert';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

/// Monde d'un scénario de suivi : le graphe de dépendances réel (get_it +
/// repositories en mémoire + catalogue de l'asset) et les identifiants
/// déterministes dérivés des prénoms et noms de groupes.
///
/// Les scénarios BDD du domaine n'utilisent pas l'interface : ils pilotent
/// les cas d'usage comme le fera un Bloc.
class TrackingWorld {
  TrackingWorld._(this.catalogue);

  static late TrackingWorld current;

  /// Date « du jour » des scénarios.
  static final today = DateTime(2026, 10, 12);

  final ExerciseCatalogue catalogue;
  final Map<String, String> _groupOfStudent = {};
  final Map<String, Audience> _audienceOfGroup = {};
  int _seedDays = 0;

  /// Dernier passage enregistré ou refusé par un `j'enregistre…`.
  late Result<RecordedAttempt> lastRecord;

  SessionId? currentSession;

  late ExerciseCurve curve;
  late AudienceChangeOutcome audienceOutcome;
  late AssessmentOutcome assessment;
  late SessionPlan plan;

  /// Dernière sauvegarde exportée (JSON) et dernier résultat d'import.
  late String backup;
  late Result<ImportSummary> lastImport;

  static Future<TrackingWorld> open(WidgetTester tester, String label) async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    addTearDown(getIt.reset);
    final years = label.split('-').map(int.parse).toList();
    await getIt<SeasonRepository>().save(
      Season(
        id: seasonId,
        label: label,
        startDate: DateTime(years.first, 9),
        endDate: DateTime(years.last, 6, 30),
      ),
    );
    // Le chargement d'asset est de l'E/S réelle : hors de la zone de faux temps.
    final catalogue = await tester.runAsync(
      () => getIt<CatalogueRepository>().load(),
    );
    return current = TrackingWorld._(catalogue!);
  }

  static const seasonId = SeasonId('season-current');

  static DateTime date(String iso) => DateTime.parse(iso);

  static StudentId studentId(String name) => StudentId('student-$name');

  static GroupId groupId(String name) => GroupId('group-$name');

  static List<String> names(String list) =>
      list.split(',').map((name) => name.trim()).toList();

  static Audience audience(String label) => switch (label) {
    'enfants' => Audience.children,
    'adultes' => Audience.adults,
    _ => throw ArgumentError('public inconnu : $label'),
  };

  static String audienceLabel(Audience audience) => switch (audience) {
    Audience.children => 'enfants',
    Audience.adults => 'adultes',
  };

  /// `bille-pleine 3` -> bloc `bille-pleine`, numéro 3.
  static ExerciseRef exercise(String label) {
    final cut = label.lastIndexOf(' ');
    return ExerciseRef(
      blockId: label.substring(0, cut),
      number: int.parse(label.substring(cut + 1)),
    );
  }

  Future<void> addStudent({
    required String group,
    required String audienceName,
    required String student,
  }) async {
    final audience = TrackingWorld.audience(audienceName);
    final start = DateTime(2026, 9);
    final groups = getIt<GroupRepository>();
    final existing = await groups.byId(groupId(group));
    final base =
        existing ??
        Group(
          id: groupId(group),
          seasonId: seasonId,
          name: group,
          audience: audience,
        );
    await groups.save(
      base.admit(
        studentId: studentId(student),
        studentAudience: audience,
        from: start,
      ),
    );
    await getIt<StudentRepository>().save(
      Student.enroll(
        id: studentId(student),
        firstName: student,
        audience: audience,
        since: start,
      ),
    );
    _groupOfStudent[student] = group;
    _audienceOfGroup[group] = audience;
  }

  Future<SessionRecord> openSession({
    required String group,
    required DateTime on,
    required List<String> present,
  }) async {
    final result = await getIt<OpenSession>()(
      groupId: groupId(group),
      date: on,
      present: {for (final name in present) studentId(name)},
    );
    final session = _valueOf(result);
    currentSession = session.id;
    return session;
  }

  /// Enregistre un passage dans une séance d'historique neuve (jamais plus de
  /// deux passages par séance) et attend un succès.
  Future<void> seedPass(
    String student,
    ExerciseRef exercise, {
    required int potted,
    required int total,
  }) async {
    final session = await _seedSession(_groupOfStudent[student]!, [student]);
    _valueOf(
      await getIt<RecordAttempt>()(
        sessionId: session.id,
        studentId: studentId(student),
        exercise: exercise,
        potted: potted,
        total: total,
      ),
    );
  }

  /// [count] passages réussis (au taux requis exact) ou échoués (une bille de
  /// moins que le taux requis) de l'exercice, chacun dans une séance passée.
  Future<void> seedPasses(
    String student,
    ExerciseRef exercise,
    int count, {
    required bool passed,
  }) async {
    final rate = catalogue.exercise(exercise)!.rate;
    for (var i = 0; i < count; i++) {
      await seedPass(
        student,
        exercise,
        potted: passed ? rate.successes : rate.successes - 1,
        total: rate.attempts,
      );
    }
  }

  /// Chaque exercice qui précède [before] (ordre d'enseignement) reçoit cinq
  /// passages réussis, répartis en trois séances passées du groupe.
  Future<void> seedValidatedBefore(
    List<String> students,
    ExerciseRef before,
  ) async {
    final group = _groupOfStudent[students.first]!;
    final specs = catalogue.exercises;
    final stop = specs.indexWhere((spec) => spec.ref == before);
    for (final passes in [2, 2, 1]) {
      final session = await _seedSession(group, students);
      for (final spec in specs.take(stop)) {
        for (final student in students) {
          for (var pass = 0; pass < passes; pass++) {
            _valueOf(
              await getIt<RecordAttempt>()(
                sessionId: session.id,
                studentId: studentId(student),
                exercise: spec.ref,
                potted: spec.rate.successes,
                total: spec.rate.attempts,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> exportBackup() async {
    backup = _valueOf(await getIt<ExportBackup>()());
  }

  /// Recompose un graphe de dépendances neuf (club vide, sans saison) puis
  /// importe [content].
  Future<void> importIntoEmptyClub(WidgetTester tester, String content) async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    // Les règles d'import lisent les catalogues : E/S réelle, hors faux temps.
    await tester.runAsync(() async {
      await getIt<CatalogueRepository>().load();
      await getIt<SessionSheetRepository>().getAll();
    });
    await importAgain(content);
  }

  Future<void> importAgain(String content) async {
    lastImport = await getIt<ImportBackup>()(content);
  }

  /// La sauvegarde exportée, avec `schemaVersion` remplacé par [version].
  String backupWithVersion(int version) {
    final document = jsonDecode(backup) as Map<String, Object?>;
    document['schemaVersion'] = version;
    return jsonEncode(document);
  }

  /// La sauvegarde exportée, dont le premier passage réussit plus de billes
  /// qu'il n'y a de tentatives.
  String backupWithInvalidAttempt() {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final first =
        (data['attempts']! as List<Object?>).first! as Map<String, Object?>;
    first['potted'] = (first['total']! as int) + 1;
    return jsonEncode(document);
  }

  /// La sauvegarde exportée, dont le premier passage vise un exercice absent
  /// du catalogue (la forme du fichier reste valide).
  String backupWithUnknownExercise() {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final first =
        (data['attempts']! as List<Object?>).first! as Map<String, Object?>;
    first['blockId'] = 'exercice-inconnu';
    return jsonEncode(document);
  }

  /// La sauvegarde exportée, dont la première séance planifiée vise une
  /// séance absente du catalogue (la forme du fichier reste valide).
  String backupWithUnknownSheet() {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final first =
        (data['plannedSessions']! as List<Object?>).first!
            as Map<String, Object?>;
    first['sheetId'] = 'inconnue-9';
    return jsonEncode(document);
  }

  Future<({int students, int attempts})> clubCounts() async => (
    students: (await getIt<StudentRepository>().all()).length,
    attempts: (await getIt<AttemptRepository>().all()).length,
  );

  Future<SessionRecord> _seedSession(String group, List<String> present) =>
      openSession(
        group: group,
        on: DateTime(2026, 9).add(Duration(days: _seedDays++)),
        present: present,
      );

  Future<void> record(
    String student,
    ExerciseRef exercise, {
    required int potted,
    required int total,
  }) async {
    lastRecord = await getIt<RecordAttempt>()(
      sessionId: currentSession!,
      studentId: studentId(student),
      exercise: exercise,
      potted: potted,
      total: total,
    );
  }

  /// Valeur d'un résultat attendu en succès ; échoue le test sinon.
  static T _valueOf<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('échec inattendu : $failure'),
  };

  static T valueOf<T>(Result<T> result) => _valueOf(result);
}
