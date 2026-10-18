import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_record.freezed.dart';

/// Une séance réellement donnée à un groupe : date, public, notion principale,
/// rappel éventuel, séance du catalogue notée et élèves présents. Les passages
/// sont enregistrés à part (`ExerciseAttempt.sessionId`).
@freezed
abstract class SessionRecord with _$SessionRecord {
  factory SessionRecord({
    required SessionId id,
    required GroupId groupId,
    required SeasonId seasonId,
    required DateTime date,
    required Audience audience,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,

    /// Séance du catalogue que cette saisie note (ADR 0007) ; `null` pour une
    /// séance ouverte sans séance du catalogue. Peut désigner une séance que
    /// le catalogue ne connaît plus : l'affichage le traite sans échouer.
    SheetId? sheetId,

    /// Note de jeu de la séance (ADR 0023) : étiquettes d'une liste fermée,
    /// sur la séance et jamais sur un élève, sans texte libre.
    @Default(<SessionTag>{}) Set<SessionTag> tags,
  }) = _SessionRecord;

  SessionRecord._() {
    if (recallBlockId != null && recallBlockId == mainBlockId) {
      throw const InvariantViolation(InvariantCode.recallEqualsMainBlock);
    }
  }

  /// Durée prévue : dérivée du public `[U]` (90 min enfants, 120 min adultes).
  int get plannedDurationMinutes => audience.sessionDuration.inMinutes;
}

/// Refuse plus de [maxPresentStudents] élèves présents (borne de `recordShape`
/// : une règle ne parcourt pas une liste plus longue). Appelée quand
/// l'animateur **saisit** les présents (ouverture ou reprise d'une séance), pas
/// à la construction : une saisie déjà enregistrée reste lisible.
void requirePresentFit(Set<StudentId> present) {
  if (present.length > maxPresentStudents) {
    throw const InvariantViolation(InvariantCode.tooManyPresent);
  }
}
