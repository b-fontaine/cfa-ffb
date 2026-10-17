import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : fixer les étiquettes de la note de jeu d'une saisie depuis
/// son bilan (ADR 0023). Elles remplacent les précédentes ; l'ensemble vide
/// les retire. Une saisie inconnue (ou supprimée) est un `NotFound`.
@injectable
class SetSessionTags {
  SetSessionTags(this._records);

  final SessionRecordRepository _records;

  Future<Result<void>> call(SessionId sessionId, Set<SessionTag> tags) =>
      runGuarded(() async {
        if (await _records.byId(sessionId) == null) {
          throw NotFound('session', sessionId.value);
        }
        await _records.setTags(sessionId, tags);
      });
}
