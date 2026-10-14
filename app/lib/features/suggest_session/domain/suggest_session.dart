import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_planner.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : proposer la séance (90 min enfants, 120 min adultes) d'un
/// groupe pour les élèves attendus. Voir [planSession] pour les règles.
@injectable
class SuggestSession {
  SuggestSession(
    this._groups,
    this._sessions,
    this._attempts,
    this._acquisitions,
    this._catalogue,
    this._config,
  );

  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<SessionPlan>> call({
    required GroupId groupId,
    required Set<StudentId> expectedStudents,
  }) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final catalogue = await _catalogue.load();
    final progress = <StudentId, StudentProgress>{
      for (final student in expectedStudents)
        student: StudentProgress.derive(
          studentId: student,
          attempts: await _attempts.forStudent(student),
          acquisitions: await _acquisitions.forStudent(student),
          rates: catalogue.rates,
          config: _config,
        ),
    };
    return planSession(
      catalogue: catalogue,
      audience: group.audience,
      progress: progress,
      groupSessions: await _sessions.forGroup(groupId),
      config: _config,
    );
  });
}
