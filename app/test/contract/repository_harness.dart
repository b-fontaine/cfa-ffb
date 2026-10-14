import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';

/// Tous les ports de persistance d'une implémentation, ouverts sur un stockage
/// neuf ; [close] libère le stockage.
class RepositoryHarness {
  RepositoryHarness({
    required this.students,
    required this.groups,
    required this.seasons,
    required this.sessionRecords,
    required this.attempts,
    required this.acquisitions,
    required this.assessments,
    required this.sessions,
    required this.unitOfWork,
    required this.close,
  });

  final StudentRepository students;
  final GroupRepository groups;
  final SeasonRepository seasons;
  final SessionRecordRepository sessionRecords;
  final AttemptRepository attempts;
  final AcquisitionRepository acquisitions;
  final AssessmentRepository assessments;
  final SessionRepository sessions;
  final UnitOfWork unitOfWork;
  final Future<void> Function() close;
}
