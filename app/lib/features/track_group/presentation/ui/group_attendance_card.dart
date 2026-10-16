import 'package:billard_cfa/features/track_group/domain/group_attendance.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';

/// L'assiduité du groupe : présences sur présences possibles, nombre de
/// séances et dernières séances. Sans séance saisie, on le dit au lieu
/// d'afficher « 0 % ».
class GroupAttendanceCard extends StatelessWidget {
  const GroupAttendanceCard({required this.attendance, super.key});

  final GroupAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final percent = attendance.percent;
    return SectionCard(
      title: l10n.groupAttendanceTitle,
      child: attendance.isEmpty || percent == null
          ? Text(l10n.groupAttendanceNone, style: theme.textTheme.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.groupAttendanceSummary(
                    attendance.present,
                    attendance.possible,
                    percent,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.groupAttendanceSessions(attendance.sessionCount),
                  style: theme.textTheme.bodyMedium,
                ),
                for (final line in attendance.recent)
                  Text(
                    l10n.groupAttendanceRecent(
                      dates.formatMediumDate(line.date),
                      line.present,
                      line.possible,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
    );
  }
}
