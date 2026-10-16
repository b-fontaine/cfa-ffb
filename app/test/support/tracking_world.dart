import 'dart:convert';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/acknowledge_alert.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/restore_alert.dart';
import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/features/record_results/domain/open_or_resume_session.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/track_group/domain/get_group_overview.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

import 'fixed_clock.dart';
import 'settings_names.dart';

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

  /// Ce que l'accueil « Aujourd'hui » montre (lot U7).
  late UpcomingSessions upcoming;
  late WatchList watchList;

  /// La fiche ouverte (lot U9) : parcours et en-tête.
  late StudentSheet sheet;

  /// Dernier acquittement demandé (accepté ou refusé).
  late Result<AlertAcknowledgement> lastAcknowledgement;

  /// La liste des élèves du club (lot U9 : alertes vues).
  late ClubOverview club;

  /// La vue élève demandée (acceptée ou refusée).
  late Result<StudentShowcase> showcaseResult;

  /// La grille de groupe demandée (acceptée ou refusée) et les alertes de
  /// groupe de l'accueil.
  late Result<GroupGrid> gridResult;
  late GroupAlertList groupAlerts;
  late WeekSummary week;
  late List<RunningSession> running;

  /// Bilan de la dernière saisie, la séance suivante proposée et le résultat
  /// de la dernière planification depuis le bilan.
  late Result<SessionReview> reviewResult;
  late NextSheet nextSheet;
  late Result<Session> planResult;

  /// Dernière sauvegarde exportée (JSON) et dernier résultat d'import.
  late String backup;
  late Result<ImportSummary> lastImport;

  /// Dernier enregistrement de réglage (accepté ou refusé).
  late Result<ClubSettings> lastSettingsSave;

  static Future<TrackingWorld> open(WidgetTester tester, String label) async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    // « Aujourd'hui » est connu : « faite », « future » dépendent de l'horloge.
    await getIt.unregister<Clock>();
    getIt.registerSingleton<Clock>(FixedClock(today));
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
    // Les séances du catalogue sont lues par l'ouverture d'une saisie qui en
    // note une (ADR 0007) : une fois en cache, elles se lisent sans attendre.
    final catalogue = await tester.runAsync(() async {
      await getIt<SessionSheetRepository>().getAll();
      return await getIt<CatalogueRepository>().load();
    });
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
    SheetId? sheet,
  }) async {
    final result = await getIt<OpenSession>()(
      groupId: groupId(group),
      date: on,
      present: {for (final name in present) studentId(name)},
      sheetId: sheet,
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

  /// [count] passages réussis (ou échoués) de l'exercice, saisis le [on],
  /// deux au plus par séance (limite de la saisie) : une séance du groupe
  /// de l'élève par paire de passages.
  Future<void> seedPassesOn(
    String student,
    ExerciseRef exercise,
    int count, {
    required DateTime on,
    required bool passed,
  }) async {
    final rate = catalogue.exercise(exercise)!.rate;
    var left = count;
    while (left > 0) {
      final session = await openSession(
        group: _groupOfStudent[student]!,
        on: on,
        present: [student],
      );
      for (var i = 0; i < left.clamp(0, 2); i++) {
        _valueOf(
          await getIt<RecordAttempt>()(
            sessionId: session.id,
            studentId: studentId(student),
            exercise: exercise,
            potted: passed ? rate.successes : rate.successes - 1,
            total: rate.attempts,
          ),
        );
      }
      left -= 2;
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

  /// Séance du groupe à la date [on] pour la séance du catalogue [sheet] (ou
  /// sans séance du catalogue), tous les élèves suivis du groupe présents ;
  /// [withPass] ajoute un passage réussi du premier élève sur le premier
  /// exercice de la séance (sinon sur `posture 1`).
  Future<SessionRecord> giveSession({
    required String group,
    required DateTime on,
    SheetId? sheet,
    bool withPass = true,
  }) async {
    final present = [
      for (final entry in _groupOfStudent.entries)
        if (entry.value == group) entry.key,
    ];
    final session = await openSession(
      group: group,
      on: on,
      present: present,
      sheet: sheet,
    );
    if (withPass) {
      final exercise = sheet == null
          ? ExerciseRef(blockId: 'posture', number: 1)
          : (await getIt<SessionSheetRepository>().getById(sheet))!
                .exercises
                .first
                .ref;
      final spec = catalogue.exercise(exercise)!;
      _valueOf(
        await getIt<RecordAttempt>()(
          sessionId: session.id,
          studentId: studentId(present.first),
          exercise: exercise,
          potted: spec.rate.successes,
          total: spec.rate.attempts,
        ),
      );
    }
    return session;
  }

  /// Saisie du groupe portant [sheet], absente du catalogue (écrite
  /// directement : l'ouverture refuse une séance inconnue), avec un passage.
  Future<void> giveSessionOfUnknownSheet({
    required String group,
    required DateTime on,
    required SheetId sheet,
  }) async {
    final student = _groupOfStudent.entries
        .firstWhere((entry) => entry.value == group)
        .key;
    final session = SessionRecord(
      id: SessionId('unknown-${sheet.value}'),
      groupId: groupId(group),
      seasonId: seasonId,
      date: on,
      audience: _audienceOfGroup[group]!,
      present: {studentId(student)},
      sheetId: sheet,
    );
    await getIt<SessionRecordRepository>().save(session);
    final spec = catalogue.exercise(
      ExerciseRef(blockId: 'posture', number: 1),
    )!;
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

  /// Reprend la saisie du groupe du jour [on] avec la séance [sheet].
  Future<void> resumeSession({
    required String group,
    required DateTime on,
    required SheetId sheet,
  }) async {
    final present = [
      for (final entry in _groupOfStudent.entries)
        if (entry.value == group) studentId(entry.key),
    ];
    _valueOf(
      await getIt<OpenOrResumeSession>()(
        groupId: groupId(group),
        date: on,
        present: present.toSet(),
        sheetId: sheet,
      ),
    );
  }

  /// Planifie [sheet] pour le groupe à la date [on] (sans saisie).
  Future<void> planSheet({
    required String group,
    required DateTime on,
    required SheetId sheet,
  }) => getIt<SessionRepository>().add(
    Session(
      id: 'planned-${sheet.value}',
      title: sheet.value,
      date: on,
      audience: _audienceOfGroup[group]!,
      groupId: groupId(group),
      sheetId: sheet,
    ),
  );

  /// Marque [blockId] acquis au positionnement pour [student] le [on].
  Future<void> markAcquired(String student, String blockId, DateTime on) async {
    _valueOf(
      await getIt<MarkBlockAcquired>()(
        studentId: studentId(student),
        blockId: blockId,
        date: on,
        today: today,
      ),
    );
  }

  Future<void> openSheet(String student) async {
    sheet = _valueOf(await getIt<GetStudentSheet>()(studentId(student)));
  }

  Future<void> acknowledge(String student, String exercise) async {
    lastAcknowledgement = await getIt<AcknowledgeAlert>()(
      studentId: studentId(student),
      exercise: TrackingWorld.exercise(exercise),
      today: today,
    );
  }

  Future<void> restore(String student, String exercise) async {
    _valueOf(
      await getIt<RestoreAlert>()(
        studentId: studentId(student),
        exercise: TrackingWorld.exercise(exercise),
      ),
    );
  }

  Future<int> acknowledgementCount() async =>
      (await getIt<AcknowledgementRepository>().all()).length;

  Future<void> openClub() async {
    club = _valueOf(await getIt<GetClubOverview>()(today: today));
  }

  Future<void> eraseStudent(String student) async {
    _valueOf(await getIt<EraseStudent>()(studentId(student)));
  }

  Future<void> openShowcase(String student) async {
    showcaseResult = await getIt<GetStudentShowcase>()(studentId(student));
  }

  StudentShowcase get showcase => _valueOf(showcaseResult);

  Future<void> openGrid(String group) async {
    gridResult = await getIt<GetGroupOverview>()(
      groupId: groupId(group),
      today: today,
    );
  }

  GroupGrid get grid => _valueOf(gridResult);

  Future<void> openGroupAlerts() async {
    groupAlerts = _valueOf(await getIt<ListGroupAlerts>()(today: today));
  }

  /// Admet [student] dans [group] à la date [from] (l'élève est inscrit s'il
  /// ne l'est pas encore).
  Future<void> joinGroup(String student, String group, DateTime from) async {
    final audience = _audienceOfGroup[group]!;
    final groups = getIt<GroupRepository>();
    final existing = (await groups.byId(groupId(group)))!;
    await groups.save(
      existing.admit(
        studentId: studentId(student),
        studentAudience: audience,
        from: from,
      ),
    );
    final students = getIt<StudentRepository>();
    if (await students.byId(studentId(student)) == null) {
      await students.save(
        Student.enroll(
          id: studentId(student),
          firstName: student,
          audience: audience,
          since: from,
        ),
      );
    }
    _groupOfStudent[student] = group;
  }

  /// Clôt l'appartenance de [student] à [group] au jour [to].
  Future<void> leaveGroup(String student, String group, DateTime to) async {
    final groups = getIt<GroupRepository>();
    final existing = (await groups.byId(groupId(group)))!;
    await groups.save(existing.release(studentId: studentId(student), to: to));
    _groupOfStudent.remove(student);
  }

  /// [count] séances consécutives du groupe à partir du jour [from], tous les
  /// élèves suivis du groupe présents, sans aucun passage.
  Future<void> holdSessions(String group, int count, DateTime from) async {
    for (var i = 0; i < count; i++) {
      await giveSession(
        group: group,
        on: from.add(Duration(days: i)),
        withPass: false,
      );
    }
  }

  /// Une séance du groupe à la date [on] avec les élèves [present].
  Future<void> holdSessionWith(
    String group,
    DateTime on,
    List<String> present,
  ) async {
    await openSession(group: group, on: on, present: present);
  }

  Future<void> exportBackup() async {
    backup = _valueOf(await getIt<ExportBackup>()());
  }

  /// Recompose un graphe de dépendances neuf (club vide, sans saison) puis
  /// importe [content].
  ///
  /// [settings] : réglages déjà enregistrés dans ce club vide.
  Future<void> importIntoEmptyClub(
    WidgetTester tester,
    String content, {
    ClubSettings? settings,
  }) async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    if (settings != null) {
      valueOf(await getIt<SaveSettings>()(settings));
    }
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

  /// La sauvegarde exportée sans la clé `data.settings`, au format [version].
  String backupWithoutSettings(int version) {
    final document = jsonDecode(backup) as Map<String, Object?>;
    document['schemaVersion'] = version;
    (document['data']! as Map<String, Object?>)
      ..remove('settings')
      // Les formats 1 et 2 ne connaissent pas les acquittements (ADR 0013).
      ..remove('alertAcknowledgements');
    return jsonEncode(document);
  }

  /// La sauvegarde exportée dont le réglage [name] vaut [value].
  String backupWithSetting(String name, int value) {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    (data['settings']! as Map<String, Object?>)[SettingsNames.key(name)] =
        value;
    return jsonEncode(document);
  }

  /// Valeur du réglage [name] écrite dans la sauvegarde exportée.
  int backupSetting(String name) {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final settings = data['settings']! as Map<String, Object?>;
    return settings[SettingsNames.key(name)]! as int;
  }

  /// La sauvegarde exportée au format [version] : sans la clé des
  /// acquittements (formats 1 et 2) ni celle des réglages (format 1).
  String backupAtFormat(int version) {
    final document = jsonDecode(backup) as Map<String, Object?>;
    document['schemaVersion'] = version;
    final data = document['data']! as Map<String, Object?>
      ..remove('alertAcknowledgements');
    if (version < 2) data.remove('settings');
    return jsonEncode(document);
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

  /// La sauvegarde exportée, dont le premier bloc acquis vise un bloc absent
  /// du catalogue (la forme du fichier reste valide).
  String backupWithUnknownAcquiredBlock() {
    final document = jsonDecode(backup) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final first =
        (data['blockAcquisitions']! as List<Object?>).first!
            as Map<String, Object?>;
    first['blockId'] = 'bloc-inconnu';
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
