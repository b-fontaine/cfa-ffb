import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/suggest_session/domain/given_sheets.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Exercices validés (ou acquis, lot 7) par **chaque** élève attendu ; vide
/// pour zéro élève (jamais « tout »).
Set<ExerciseRef> validatedByAll(Iterable<StudentProgress> progress) {
  final validated = [for (final student in progress) student.validated];
  if (validated.isEmpty) return {};
  return validated.reduce((all, next) => all.intersection(next));
}

/// Séance du catalogue à proposer pour la notion [mainBlockId] (ADR 0009) ;
/// `null` pour un bloc sans séance (cas nominal) ou si aucune séance du bloc
/// ne contient [head].
///
/// - candidates : séances du bloc, par `order` ;
/// - faites : saisie du groupe avec séance du catalogue **et** au moins un
///   passage ([attemptCountBySession]), datée d'aujourd'hui ([today]) ou
///   avant ; un identifiant inconnu du catalogue est ignoré ;
/// - sans objet : tous les exercices dans [validatedByAll] (jamais la séance
///   qui contient [head]) ; [validatedByAll] vide ne saute rien ;
/// - à faire : ni faite ni sans objet. La proposée est celle qui contient
///   [head], sinon la première ; aucune à faire : celle qui contient [head],
///   redonnée.
///
/// Pure : ni dépôt, ni horloge, ni effet de bord.
SheetSuggestion? suggestSheet({
  required String mainBlockId,
  required ExerciseRef head,
  required Iterable<SessionSheet> sheets,
  required List<SessionRecord> groupSessions,
  required Map<SessionId, int> attemptCountBySession,
  required DateTime today,
  required Set<ExerciseRef> validatedByAll,
}) {
  final candidates = [
    for (final sheet in sheets)
      if (sheet.catalogueBlock == mainBlockId) sheet,
  ]..sort((a, b) => a.order.compareTo(b.order));
  if (candidates.isEmpty) return null;

  final lastGiven = givenSheets(
    groupSessions: groupSessions,
    attemptCountBySession: attemptCountBySession,
    today: today,
  );

  bool holdsHead(SessionSheet sheet) =>
      sheet.exercises.any((exercise) => exercise.ref == head);
  bool withoutObject(SessionSheet sheet) =>
      !holdsHead(sheet) &&
      sheet.exercises.every(
        (exercise) => validatedByAll.contains(exercise.ref),
      );

  final pending = [
    for (final sheet in candidates)
      if (!lastGiven.containsKey(sheet.id) && !withoutObject(sheet)) sheet,
  ];
  final SessionSheet? chosen;
  final SheetSuggestionKind kind;
  if (pending.isNotEmpty) {
    chosen = pending.where(holdsHead).firstOrNull ?? pending.first;
    kind = holdsHead(chosen)
        ? SheetSuggestionKind.coversHead
        : SheetSuggestionKind.nextPending;
  } else {
    chosen = candidates.where(holdsHead).firstOrNull;
    kind = SheetSuggestionKind.repeat;
  }
  if (chosen == null) return null;
  final option = sheetOptionOf(sheets, chosen.id);
  if (option == null) return null;
  return SheetSuggestion(
    option: option,
    kind: kind,
    exerciseNumbers: [for (final e in chosen.exercises) e.ref.number],
    headCovered: holdsHead(chosen),
    head: head,
    lastGivenOn: kind == SheetSuggestionKind.repeat
        ? lastGiven[chosen.id]
        : null,
  );
}
