import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : l'historique des séances saisies, de la plus récente à la
/// plus ancienne (à date égale, la dernière enregistrée en premier).
@injectable
class ListRecordedSessions {
  ListRecordedSessions(
    this._sessions,
    this._groups,
    this._attempts,
    this._catalogue,
    this._sheets,
  );

  final SessionRecordRepository _sessions;
  final GroupRepository _groups;
  final AttemptRepository _attempts;
  final CatalogueRepository _catalogue;
  final SessionSheetRepository _sheets;

  Future<Result<List<RecordedSessionSummary>>> call() => runGuarded(() async {
    final sessions = await _sessions.all();
    final catalogue = await _catalogue.load();
    final sheets = await _sheets.getAll();
    final summaries = <RecordedSessionSummary>[];
    for (final session in sessions) {
      final group = await _groups.byId(session.groupId);
      final blockId = session.mainBlockId;
      summaries.add(
        RecordedSessionSummary(
          session: session,
          groupName: group?.name ?? '',
          mainBlock: blockId == null ? null : catalogue.blockById(blockId),
          attemptCount: (await _attempts.forSession(session.id)).length,
          sheet: sheetOptionOf(sheets, session.sheetId),
        ),
      );
    }
    // `all()` rend l'ordre de première sauvegarde : l'indice départage les
    // séances d'un même jour.
    final recorded = {
      for (final (index, summary) in summaries.indexed) summary: index,
    };
    summaries.sort((a, b) {
      final byDate = b.session.date.compareTo(a.session.date);
      return byDate != 0 ? byDate : recorded[b]!.compareTo(recorded[a]!);
    });
    return summaries;
  });
}
