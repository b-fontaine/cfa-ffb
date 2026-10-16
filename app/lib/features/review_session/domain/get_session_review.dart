import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/review_session/domain/next_session_date.dart';
import 'package:billard_cfa/features/review_session/domain/review_session.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le bilan d'une saisie, relu depuis la persistance (il
/// survit à un rechargement). Une saisie inconnue est un `NotFound`.
@injectable
class GetSessionReview {
  GetSessionReview(
    this._records,
    this._attempts,
    this._acquisitions,
    this._students,
    this._groups,
    this._planned,
    this._catalogue,
    this._sheets,
    this._config,
    this._clock,
  );

  final SessionRecordRepository _records;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final StudentRepository _students;
  final GroupRepository _groups;
  final SessionRepository _planned;
  final CatalogueRepository _catalogue;
  final SessionSheetRepository _sheets;
  final RulesConfig _config;
  final Clock _clock;

  Future<Result<SessionReview>> call(SessionId sessionId) =>
      runGuarded(() async {
        final record = await _records.byId(sessionId);
        if (record == null) throw NotFound('session', sessionId.value);
        final catalogue = await _catalogue.load();
        final outcome = reviewSession(
          record: record,
          attempts: await _attempts.all(),
          acquisitions: await _acquisitions.all(),
          catalogue: catalogue,
          config: _config,
        );
        final students = {
          for (final id in record.present) id: ?await _students.byId(id),
        };
        final today = _clock.today();
        final upcoming = [
          for (final session in await _planned.getAll())
            if (session.groupId == record.groupId &&
                session.date.dateOnly.isAfter(today))
              session,
        ]..sort((a, b) => a.date.compareTo(b.date));
        return SessionReview(
          record: record,
          outcome: outcome,
          proposedDate: nextSameWeekday(given: record.date, today: today),
          sheet: sheetOptionOf(await _sheets.getAll(), record.sheetId),
          group: await _groups.byId(record.groupId),
          students: Map.unmodifiable(students),
          upcoming: List.unmodifiable(upcoming),
          blockLabels: catalogue.blockLabels,
        );
      });
}
