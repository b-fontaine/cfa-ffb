import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : l'état d'une séance ouverte pour la saisie des résultats.
@injectable
class GetSessionOverview {
  GetSessionOverview(
    this._sessions,
    this._groups,
    this._students,
    this._attempts,
    this._catalogue,
    this._sheets,
    this._config,
  );

  final SessionRecordRepository _sessions;
  final GroupRepository _groups;
  final StudentRepository _students;
  final AttemptRepository _attempts;
  final CatalogueRepository _catalogue;
  final SessionSheetRepository _sheets;
  final RulesConfig _config;

  Future<Result<SessionOverview>> call(SessionId sessionId) =>
      runGuarded(() async {
        final session = await _sessions.byId(sessionId);
        if (session == null) throw NotFound('session', sessionId.value);
        final group = await _groups.byId(session.groupId);
        final students = [
          for (final id in session.present) ?await _students.byId(id),
        ]..sort((a, b) => a.firstName.compareTo(b.firstName));
        return SessionOverview(
          session: session,
          groupName: group?.name ?? '',
          students: students,
          attempts: await _attempts.forSession(sessionId),
          catalogue: await _catalogue.load(),
          maxPassesPerExercise: _config.maxPassesPerExercisePerSession,
          sheet: session.sheetId == null
              ? null
              : sheetOptionOf(await _sheets.getAll(), session.sheetId),
        );
      });
}
