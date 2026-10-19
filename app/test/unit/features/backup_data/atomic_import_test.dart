import 'dart:convert';

import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/backup_formats.dart';
import '../../../support/domain_world.dart';
import '../../../support/drift_support.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

/// Un dépôt de passages dont la deuxième écriture échoue (disque plein…).
class _FailingSecondAttempt implements AttemptRepository {
  _FailingSecondAttempt(this._inner);

  final AttemptRepository _inner;
  int _writes = 0;

  @override
  Future<void> add(ExerciseAttempt attempt) async {
    if (++_writes == 2) throw StateError('disque plein');
    await _inner.add(attempt);
  }

  @override
  Future<void> correct(ExerciseAttempt attempt) => _inner.correct(attempt);

  @override
  Future<List<ExerciseAttempt>> all() => _inner.all();

  @override
  Future<void> delete(AttemptId id) => _inner.delete(id);

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) =>
      _inner.forSession(sessionId);

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) =>
      _inner.forStudent(studentId);

  @override
  Future<void> eraseStudent(StudentId studentId) =>
      _inner.eraseStudent(studentId);

  @override
  Stream<List<ExerciseAttempt>> watchAll() => _inner.watchAll();

  @override
  Stream<List<ExerciseAttempt>> watchForStudent(StudentId studentId) =>
      _inner.watchForStudent(studentId);

  @override
  Stream<List<ExerciseAttempt>> watchForSession(SessionId sessionId) =>
      _inner.watchForSession(sessionId);
}

void main() {
  test('a failing write rolls back every write of the import', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final clock = TickingClock();
    final student = Student.enroll(
      id: const StudentId('s1'),
      firstName: 'Léa',
      audience: Audience.children,
      since: day(1),
    );
    final content = BackupCodec().encode(
      BackupSnapshot(
        seasons: [
          Season(
            id: const SeasonId('season'),
            label: '2026-2027',
            startDate: day(1),
            endDate: DateTime(2027, 6, 30),
          ),
        ],
        students: [student],
        groups: [
          Group(
            id: const GroupId('g1'),
            seasonId: const SeasonId('season'),
            name: 'Jeunes',
            audience: Audience.children,
          ),
        ],
        sessionRecords: [
          SessionRecord(
            id: const SessionId('x1'),
            groupId: const GroupId('g1'),
            seasonId: const SeasonId('season'),
            date: day(3),
            audience: Audience.children,
            present: {student.id},
          ),
        ],
        attempts: [
          attempt(ref('a', 1), potted: 3),
          attempt(ref('a', 1), potted: 4, id: 'a2'),
        ],
        blockAcquisitions: const [],
        seasonArchives: const [],
        settings: ClubSettings.defaults.copyWith(passesRequired: 3),
      ),
      exportedAt: DateTime.utc(2026, 10, 12),
    );
    final store = RulesStore(RulesConfig());
    final import = ImportBackup(
      DriftSeasonRepository(db, clock),
      DriftSeasonArchiveRepository(db),
      DriftStudentRepository(db, clock),
      DriftGroupRepository(db, clock),
      DriftSessionRecordRepository(db, clock),
      _FailingSecondAttempt(DriftAttemptRepository(db, clock)),
      DriftAcquisitionRepository(db, clock),
      DriftAcknowledgementRepository(db, clock),
      DriftAssessmentRepository(db, clock),
      DriftSessionRepository(db, clock),
      BackupCodec(),
      BackupRules(
        FixedCatalogueRepository(buildCatalogue()),
        FixtureSessionSheetRepository(catalogueFixture()),
        RulesConfig(),
        clock,
      ),
      DriftUnitOfWork(db),
      DriftSettingsRepository(db, clock),
      store,
    );

    await expectLater(import(content), throwsStateError);

    expect(await DriftSeasonRepository(db, clock).all(), isEmpty);
    expect(await DriftStudentRepository(db, clock).all(), isEmpty);
    expect(await DriftGroupRepository(db, clock).all(), isEmpty);
    expect(await DriftSessionRecordRepository(db, clock).all(), isEmpty);
    expect(await DriftAttemptRepository(db, clock).all(), isEmpty);
    // Les réglages, écrits dans la même unité de travail, sont annulés ; la
    // valeur courante des règles n'a pas changé.
    expect(
      await DriftSettingsRepository(db, clock).load(),
      ClubSettings.defaults,
    );
    expect(store.current.passesRequired, 5);
  });

  test(
    'a failing import of an old format keeps the acknowledgements in place',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final clock = TickingClock();
      final acknowledgements = DriftAcknowledgementRepository(db, clock);
      await acknowledgements.add(
        AlertAcknowledgement(
          id: const AcknowledgementId('k1'),
          studentId: const StudentId('s1'),
          exercise: ref('a', 1),
          lastAttemptId: const AttemptId('a1'),
          date: day(4),
        ),
      );
      final student = Student.enroll(
        id: const StudentId('s1'),
        firstName: 'Léa',
        audience: Audience.children,
        since: day(1),
      );
      // Format 2 : la liste des acquittements n'existe pas dans le fichier.
      final document = jsonDecode(
        BackupCodec().encode(
          BackupSnapshot(
            seasons: [
              Season(
                id: const SeasonId('season'),
                label: '2026-2027',
                startDate: day(1),
                endDate: DateTime(2027, 6, 30),
              ),
            ],
            students: [student],
            groups: [
              Group(
                id: const GroupId('g1'),
                seasonId: const SeasonId('season'),
                name: 'Jeunes',
                audience: Audience.children,
              ),
            ],
            sessionRecords: [
              SessionRecord(
                id: const SessionId('x1'),
                groupId: const GroupId('g1'),
                seasonId: const SeasonId('season'),
                date: day(3),
                audience: Audience.children,
                present: {student.id},
              ),
            ],
            attempts: [
              attempt(ref('a', 1), potted: 3),
              attempt(ref('a', 1), potted: 4, id: 'a2'),
            ],
            blockAcquisitions: const [],
            seasonArchives: const [],
          ),
          exportedAt: DateTime.utc(2026, 10, 12),
        ),
      ) as Map<String, Object?>;
      document['schemaVersion'] = 2;
      (document['data']! as Map<String, Object?>)
        ..remove('alertAcknowledgements')
        ..remove('seasonArchives');
      dropSessionTags(document['data']! as Map<String, Object?>);
      final import = ImportBackup(
        DriftSeasonRepository(db, clock),
        DriftSeasonArchiveRepository(db),
        DriftStudentRepository(db, clock),
        DriftGroupRepository(db, clock),
        DriftSessionRecordRepository(db, clock),
        _FailingSecondAttempt(DriftAttemptRepository(db, clock)),
        DriftAcquisitionRepository(db, clock),
        acknowledgements,
        DriftAssessmentRepository(db, clock),
        DriftSessionRepository(db, clock),
        BackupCodec(),
        BackupRules(
          FixedCatalogueRepository(buildCatalogue()),
          FixtureSessionSheetRepository(catalogueFixture()),
          RulesConfig(),
          clock,
        ),
        DriftUnitOfWork(db),
        DriftSettingsRepository(db, clock),
        RulesStore(RulesConfig()),
      );

      await expectLater(import(jsonEncode(document)), throwsStateError);

      expect(await acknowledgements.all(), hasLength(1));
      expect(await DriftStudentRepository(db, clock).all(), isEmpty);
    },
  );

  test('a refused file is reported as a failure, not thrown', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final clock = TickingClock();
    final import = ImportBackup(
      DriftSeasonRepository(db, clock),
      DriftSeasonArchiveRepository(db),
      DriftStudentRepository(db, clock),
      DriftGroupRepository(db, clock),
      DriftSessionRecordRepository(db, clock),
      DriftAttemptRepository(db, clock),
      DriftAcquisitionRepository(db, clock),
      DriftAcknowledgementRepository(db, clock),
      DriftAssessmentRepository(db, clock),
      DriftSessionRepository(db, clock),
      BackupCodec(),
      BackupRules(
        FixedCatalogueRepository(buildCatalogue()),
        FixtureSessionSheetRepository(catalogueFixture()),
        RulesConfig(),
        clock,
      ),
      DriftUnitOfWork(db),
      DriftSettingsRepository(db, clock),
      RulesStore(RulesConfig()),
    );

    final result = await import('{"format": "autre"}');

    expect(
      result,
      isA<Err<Object?>>().having(
        (r) => r.failure,
        'failure',
        isA<InvariantViolation>().having(
          (f) => f.code,
          'code',
          InvariantCode.backupUnreadable,
        ),
      ),
    );
  });
}
