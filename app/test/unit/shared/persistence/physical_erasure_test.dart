import 'package:billard_cfa/app/student_eraser.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/run_progress/data/drift_run_progress_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/drift_support.dart';
import '../../../support/fixtures.dart';

/// L'effacement est physique : plus aucune ligne SQLite ne nomme l'élève,
/// même celles qui avaient été supprimées logiquement.
void main() {
  late AppDatabase db;

  setUp(() => db = openMemoryDatabase());
  tearDown(() => db.close());

  Future<int> count(String table, String column) async {
    final row = await db
        .customSelect("SELECT COUNT(*) AS n FROM $table WHERE $column = 's1'")
        .getSingle();
    return row.read<int>('n');
  }

  test('leaves no SQLite row that names the erased student', () async {
    final clock = TickingClock();
    final students = DriftStudentRepository(db, clock);
    final groups = DriftGroupRepository(db, clock);
    final sessions = DriftSessionRecordRepository(db, clock);
    final attempts = DriftAttemptRepository(db, clock);
    final assessments = DriftAssessmentRepository(db, clock);
    final acquisitions = DriftAcquisitionRepository(db, clock);
    final acknowledgements = DriftAcknowledgementRepository(db, clock);
    const lea = StudentId('s1');
    await students.create(
      Student.enroll(
        id: lea,
        firstName: 'Léa',
        audience: Audience.children,
        since: DateTime(2026, 9),
      ),
    );
    await groups.save(
      Group(
        id: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        name: 'Jeunes',
        audience: Audience.children,
      ).admit(
        studentId: lea,
        studentAudience: Audience.children,
        from: DateTime(2026, 9),
      ),
    );
    await sessions.save(
      SessionRecord(
        id: const SessionId('x1'),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(3),
        audience: Audience.children,
        present: {lea},
      ),
    );
    await attempts.add(attempt(ref('a', 1), potted: 3));
    await attempts.add(attempt(ref('a', 1), potted: 3, id: 'a2'));
    await attempts.delete(const AttemptId('a2'));
    await assessments.add(
      MaturityAssessment(
        id: const AssessmentId('b1'),
        studentId: lea,
        date: day(5),
        concentration: 3,
        endurance: 3,
        frustration: 3,
        comment: 'Timide',
      ),
    );
    await acquisitions.add(
      BlockAcquisition(
        id: const AcquisitionId('q1'),
        studentId: lea,
        blockId: 'posture',
        date: day(4),
        source: AcquisitionSource.placement,
      ),
    );
    await acquisitions.add(
      BlockAcquisition(
        id: const AcquisitionId('q2'),
        studentId: lea,
        blockId: 'puissance',
        date: day(4),
        source: AcquisitionSource.placement,
      ),
    );
    await acquisitions.delete(const AcquisitionId('q2'));
    for (final id in ['k1', 'k2']) {
      await acknowledgements.add(
        AlertAcknowledgement(
          id: AcknowledgementId(id),
          studentId: lea,
          exercise: ref('a', 1),
          lastAttemptId: const AttemptId('a1'),
          date: day(4),
        ),
      );
    }
    await acknowledgements.delete(const AcknowledgementId('k2'));
    await students.delete(lea);

    await attempts.eraseStudent(lea);
    await assessments.eraseStudent(lea);
    await acquisitions.eraseStudent(lea);
    await acknowledgements.eraseStudent(lea);
    await sessions.eraseStudent(lea);
    await groups.eraseStudent(lea);
    await students.erase(lea);

    expect(await count('students', 'id'), 0);
    expect(await count('student_audience_changes', 'student_id'), 0);
    expect(await count('group_memberships', 'student_id'), 0);
    expect(await count('session_presences', 'student_id'), 0);
    expect(await count('attempts', 'student_id'), 0);
    expect(await count('assessments', 'student_id'), 0);
    expect(await count('block_acquisitions', 'student_id'), 0);
    expect(await count('alert_acknowledgements', 'student_id'), 0);
  });

  test('closing a season erases the chosen students from every table, '
      'archive included', () async {
    final clock = TickingClock();
    final students = DriftStudentRepository(db, clock);
    final groups = DriftGroupRepository(db, clock);
    final sessions = DriftSessionRecordRepository(db, clock);
    final attempts = DriftAttemptRepository(db, clock);
    final assessments = DriftAssessmentRepository(db, clock);
    final acquisitions = DriftAcquisitionRepository(db, clock);
    final acknowledgements = DriftAcknowledgementRepository(db, clock);
    final seasons = DriftSeasonRepository(db, clock);
    final archives = DriftSeasonArchiveRepository(db);
    final runProgress = DriftRunProgressRepository(db);
    await seasons.save(
      Season(
        id: const SeasonId('season'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    );
    var group = Group(
      id: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      name: 'Jeunes',
      audience: Audience.children,
    );
    final names = ['s1', 's2', 's3'];
    for (final id in names) {
      await students.create(
        Student.enroll(
          id: StudentId(id),
          firstName: 'Élève $id',
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
      group = group.admit(
        studentId: StudentId(id),
        studentAudience: Audience.children,
        from: DateTime(2026, 9),
      );
    }
    await groups.save(group);
    await sessions.save(
      SessionRecord(
        id: const SessionId('x1'),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(3),
        audience: Audience.children,
        present: {for (final id in names) StudentId(id)},
      ),
    );
    for (final id in names) {
      await attempts.add(
        attempt(ref('a', 1), potted: 3, student: id, id: 'a-$id'),
      );
      await assessments.add(
        MaturityAssessment(
          id: AssessmentId('b-$id'),
          studentId: StudentId(id),
          date: day(5),
          concentration: 3,
          endurance: 3,
          frustration: 3,
          comment: 'Timide',
        ),
      );
      await acquisitions.add(
        BlockAcquisition(
          id: AcquisitionId('q-$id'),
          studentId: StudentId(id),
          blockId: 'posture',
          date: day(4),
          source: AcquisitionSource.placement,
        ),
      );
      await acknowledgements.add(
        AlertAcknowledgement(
          id: AcknowledgementId('k-$id'),
          studentId: StudentId(id),
          exercise: ref('a', 1),
          lastAttemptId: AttemptId('a-$id'),
          date: day(4),
        ),
      );
    }
    // Séances guidées en cours : une sur le groupe de l'élève effacé, une sur
    // la saisie où il était présent, une sans aucun lien.
    await DriftSessionRepository(db, clock).add(
      Session(
        id: 'p1',
        title: 'Cours',
        date: day(8),
        audience: Audience.children,
        groupId: const GroupId('g1'),
      ),
    );
    for (final (sheet, group, record, planned) in [
      ('posture-1', 'g1', null, null),
      ('posture-2', null, 'x1', null),
      ('posture-3', null, null, null),
      ('posture-4', null, null, 'p1'),
    ]) {
      await runProgress.save(
        RunProgress(
          key: RunProgressKey(
            sheetId: SheetId(sheet),
            sessionId: planned,
            groupId: group == null ? null : GroupId(group),
          ),
          updatedAt: DateTime.utc(2026, 10, 12),
          recordId: record == null ? null : SessionId(record),
        ),
      );
    }
    final close = CloseSeason(
      seasons,
      groups,
      students,
      sessions,
      attempts,
      DriftSessionRepository(db, clock),
      archives,
      EraseStudentRecords(
        EraseStudent(
          students,
          groups,
          sessions,
          attempts,
          assessments,
          acquisitions,
          acknowledgements,
          runProgress,
          DriftSessionRepository(db, clock),
          DriftUnitOfWork(db),
        ),
      ),
      UuidV4Generator(),
      DriftUnitOfWork(db),
    );

    final result = await close(
      seasonId: const SeasonId('season'),
      closedOn: day(20),
      erase: {const StudentId('s1')},
    );

    expect(result, isA<Ok<ClosureResult>>());
    // Aucune table n'a plus de ligne portant l'identifiant effacé.
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    for (final table in tables.map((t) => t.read<String>('name'))) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      for (final column in columns.map((c) => c.read<String>('name'))) {
        final rows = await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM $table WHERE CAST($column AS TEXT) '
              "LIKE '%s1%' OR CAST($column AS TEXT) LIKE '%Élève s1%'",
            )
            .getSingle();
        expect(rows.read<int>('n'), 0, reason: '$table.$column');
      }
    }
    // Seule la séance guidée sans lien avec l'élève reste, physiquement.
    expect((await runProgress.all()).map((p) => p.key.sheetId.value), [
      'posture-3',
    ]);
    // Les élèves conservés et l'archive sont là, sans aucun nom.
    expect(await count('students', 'id'), 0);
    expect((await students.all()).map((s) => s.id.value), ['s2', 's3']);
    final archive = (await archives.bySeason(const SeasonId('season')))!;
    expect(archive.audienceOf(Audience.children)!.presenceCount, 3);
    expect(archive.audienceOf(Audience.children)!.studentCount, 3);
  });

  test(
    'erases the running guides tied to a deleted group, a deleted planned '
    'session and a deleted record, which stay in the base until purged',
    () async {
      final clock = TickingClock();
      final students = DriftStudentRepository(db, clock);
      final groups = DriftGroupRepository(db, clock);
      final records = DriftSessionRecordRepository(db, clock);
      final planned = DriftSessionRepository(db, clock);
      final runProgress = DriftRunProgressRepository(db);
      const lea = StudentId('s1');
      await students.create(
        Student.enroll(
          id: lea,
          firstName: 'Léa',
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
      Group group(String id) => Group(
        id: GroupId(id),
        seasonId: const SeasonId('season'),
        name: id,
        audience: Audience.children,
      );
      // g-supprime : Léa y a été membre, puis le groupe a été supprimé.
      // g-vivant : Léa y est membre, et sa séance planifiée est supprimée.
      for (final id in ['g-supprime', 'g-vivant']) {
        await groups.save(
          group(id).admit(
            studentId: lea,
            studentAudience: Audience.children,
            from: DateTime(2026, 9),
          ),
        );
      }
      await groups.delete(const GroupId('g-supprime'));
      await planned.add(
        Session(
          id: 'p-supprimee',
          title: 'Cours',
          date: day(8),
          audience: Audience.children,
          groupId: const GroupId('g-vivant'),
        ),
      );
      await planned.delete('p-supprimee');
      await records.save(
        SessionRecord(
          id: const SessionId('x-supprimee'),
          groupId: const GroupId('autre'),
          seasonId: const SeasonId('season'),
          date: day(3),
          audience: Audience.children,
          present: {lea},
        ),
      );
      await records.delete(const SessionId('x-supprimee'));
      Future<void> running(String sheet, {String? g, String? r, String? p}) =>
          runProgress.save(
            RunProgress(
              key: RunProgressKey(
                sheetId: SheetId(sheet),
                sessionId: p,
                groupId: g == null ? null : GroupId(g),
              ),
              updatedAt: DateTime.utc(2026, 10, 12),
              step: 2,
              recordId: r == null ? null : SessionId(r),
            ),
          );
      await running('groupe-supprime-1', g: 'g-supprime');
      await running('planifiee-supprimee-1', p: 'p-supprimee');
      await running('saisie-supprimee-1', r: 'x-supprimee');
      await running('sans-lien-1');

      final erase = EraseStudent(
        students,
        groups,
        records,
        DriftAttemptRepository(db, clock),
        DriftAssessmentRepository(db, clock),
        DriftAcquisitionRepository(db, clock),
        DriftAcknowledgementRepository(db, clock),
        runProgress,
        planned,
        DriftUnitOfWork(db),
      );
      final result = await erase(lea);

      expect(result, isA<Ok<void>>());
      expect((await runProgress.all()).map((p) => p.key.sheetId.value), [
        'sans-lien-1',
      ]);
    },
  );
}
