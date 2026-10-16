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
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
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
    await students.save(
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
    await attempts.add(attempt(ref('a', 1), potted: 3, id: 'a2', passIndex: 2));
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
      await students.save(
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
    // Les élèves conservés et l'archive sont là, sans aucun nom.
    expect(await count('students', 'id'), 0);
    expect((await students.all()).map((s) => s.id.value), ['s2', 's3']);
    final archive = (await archives.bySeason(const SeasonId('season')))!;
    expect(archive.audienceOf(Audience.children)!.presenceCount, 3);
    expect(archive.audienceOf(Audience.children)!.studentCount, 3);
  });
}
