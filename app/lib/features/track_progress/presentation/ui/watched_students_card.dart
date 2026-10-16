import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/watch_row.dart';
import 'package:flutter/material.dart';

/// Les élèves à surveiller : une ligne par élève (exercice le plus alarmant,
/// échecs de suite, niveau en texte), et un lien vers tous les élèves quand la
/// liste est tronquée.
class WatchedStudentsCard extends StatelessWidget {
  const WatchedStudentsCard({
    required this.watchList,
    required this.onOpenStudent,
    required this.onOpenAll,
    super.key,
  });

  final WatchList watchList;
  final ValueChanged<StudentId> onOpenStudent;
  final VoidCallback onOpenAll;

  /// « Posture · exercice 1 », proposition signalée.
  String _exercise(AppLocalizations l10n, ExerciseRef exercise) {
    final label = watchList.blockLabels[exercise.blockId];
    return exerciseTitle(
      l10n,
      blockTitle: label?.title ?? exercise.blockId,
      number: exercise.number,
      proposal: label?.proposal ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines = watchList.lines;
    return SectionCard(
      title: l10n.homeWatchTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lines.isEmpty) Text(l10n.homeWatchNobody),
          for (final line in lines)
            WatchRow(
              name: line.student.firstName,
              persistent: line.watched.alert == AlertLevel.persistent,
              detail: l10n.homeWatchDetail(
                _exercise(l10n, line.watched.exercise),
                line.watched.consecutiveFailures,
                line.watched.otherAlerts,
              ),
              onTap: () => onOpenStudent(line.student.id),
            ),
          if (watchList.total > lines.length) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onOpenAll,
                child: Text(l10n.homeWatchAll(watchList.total)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
