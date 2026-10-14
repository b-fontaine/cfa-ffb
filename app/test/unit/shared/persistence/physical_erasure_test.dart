import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
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
    await students.delete(lea);

    await attempts.eraseStudent(lea);
    await assessments.eraseStudent(lea);
    await acquisitions.eraseStudent(lea);
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
  });
}
