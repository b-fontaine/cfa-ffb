import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Les liens par lesquels des séances guidées en cours ont été effacées
/// (droit à l'effacement d'un élève, ADR 0020 § 7) : un groupe, une saisie ou
/// une séance planifiée.
///
/// Sert à prévenir ceux qui gardent ces séances **en mémoire** : effacer la
/// ligne ne suffit pas, un guide ouvert la réécrirait au moindre changement.
@immutable
final class RunProgressLinks {
  const RunProgressLinks({
    this.groups = const {},
    this.records = const {},
    this.plannedSessions = const {},
  });

  final Set<GroupId> groups;
  final Set<SessionId> records;
  final Set<String> plannedSessions;

  bool get isEmpty =>
      groups.isEmpty && records.isEmpty && plannedSessions.isEmpty;

  /// Vrai si la séance guidée de [key], dont la saisie ouverte est
  /// [recordId], est liée à l'un de ces liens.
  bool touches(RunProgressKey key, {SessionId? recordId}) =>
      groups.contains(key.groupId) ||
      plannedSessions.contains(key.sessionId) ||
      (recordId != null && records.contains(recordId));
}
