import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_failures.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_alerts.freezed.dart';

/// Alerte de groupe : [failed] élèves sur [members] ont manqué la technique à
/// leur dernier passage.
@freezed
abstract class GroupAlert with _$GroupAlert {
  const factory GroupAlert({
    required String blockId,
    required String blockTitle,
    required int failed,
    required int members,
  }) = _GroupAlert;

  const GroupAlert._();

  /// Part des élèves en échec, en pourcentage entier (arrondi inférieur).
  int get sharePercent => members == 0 ? 0 : failed * 100 ~/ members;
}

/// Alertes de groupe pour les [members] à partir de leur [progress].
List<GroupAlert> groupFailureAlerts({
  required ExerciseCatalogue catalogue,
  required List<StudentId> members,
  required Map<StudentId, StudentProgress> progress,
  required List<SessionRecord> groupSessions,
  required DateTime asOf,
  required RulesConfig config,
}) {
  final cutoff = asOf.dateOnly;
  final dates = [
    for (final session in groupSessions)
      if (!session.date.dateOnly.isAfter(cutoff)) session.date.dateOnly,
  ]..sort();
  // Fenêtre : les `recallStaleSessions` dernières séances du groupe ; un échec
  // plus ancien que la plus ancienne d'entre elles n'alerte plus.
  final since = dates.isEmpty
      ? null
      : dates[(dates.length - config.recallStaleSessions).clamp(
          0,
          dates.length - 1,
        )];
  final current = {for (final id in members) id: ?progress[id]};
  final alerts = <GroupAlert>[];
  for (final block in catalogue.blocks) {
    final failed =
        blockFailedStudents(exercises: block.exerciseRefs, progress: current)
            .values
            .where((date) => since == null || !date.dateOnly.isBefore(since))
            .length;
    if (failed >= config.minGroupFailures &&
        reachesGroupFailureShare(
          failed: failed,
          members: members.length,
          sharePercent: config.groupFailureSharePercent,
        )) {
      alerts.add(
        GroupAlert(
          blockId: block.id,
          blockTitle: block.title,
          failed: failed,
          members: members.length,
        ),
      );
    }
  }
  // Tri stable : à part égale, l'ordre d'enseignement du catalogue.
  alerts.sort((a, b) => b.failed.compareTo(a.failed));
  return List.unmodifiable(alerts);
}
