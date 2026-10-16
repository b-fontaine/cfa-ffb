import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/now_card.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// « lun. 12 oct. · Jeunes · Enfants · 90 min » (le groupe quand il est connu).
String _line(BuildContext context, PlannedSessionSummary summary) {
  final l10n = AppLocalizations.of(context);
  final session = summary.session;
  final date = MaterialLocalizations.of(context).formatMediumDate(session.date);
  final audience = session.audience.label(l10n);
  final minutes = session.duration.inMinutes;
  final group = summary.group;
  return group == null
      ? l10n.plannerSessionLine(date, audience, minutes)
      : l10n.plannerSessionGroupLine(date, group.name, audience, minutes);
}

/// La prochaine séance planifiée : date, groupe, « Préparer » et « Lancer ».
///
/// Une séance sans séance du catalogue n'a qu'une action : « Ouvrir dans
/// Planifiées ». Un groupe disparu est signalé, « Lancer » reste possible.
class NextSessionCard extends StatelessWidget {
  const NextSessionCard({
    required this.summary,
    required this.sameDayOthers,
    required this.onPrepare,
    required this.onLaunch,
    required this.onOpenPlanned,
    super.key,
  });

  final PlannedSessionSummary summary;

  /// Autres séances à donner le même jour.
  final int sameDayOthers;

  /// Ouvre la séance du catalogue ; lance son guide (avec la séance
  /// planifiée).
  final void Function(SheetId sheet, Audience audience) onPrepare;
  final void Function(SheetId sheet, Audience audience, String sessionId)
  onLaunch;
  final VoidCallback onOpenPlanned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = summary.session;
    final sheet = session.sheetId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NowCard(
          stateLabel: l10n.homeNowNext,
          stateIcon: Icons.event_outlined,
          title: session.title,
          meta: [
            _line(context, summary),
            if (summary.groupUnavailable) l10n.plannerGroupUnavailable,
          ],
          primaryLabel: sheet == null ? null : l10n.guideLaunch,
          onPrimary: sheet == null
              ? null
              : () => onLaunch(sheet, session.audience, session.id),
          secondaryLabel: sheet == null
              ? l10n.homeOpenInPlanned
              : l10n.homePrepare,
          onSecondary: sheet == null
              ? onOpenPlanned
              : () => onPrepare(sheet, session.audience),
        ),
        if (sameDayOthers > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onOpenPlanned,
              child: Text(l10n.homeSameDayOthers(sameDayOthers)),
            ),
          ),
      ],
    );
  }
}

/// Aucune séance à venir : inviter à planifier ou à voir la suggestion ; sans
/// élève, à en ajouter.
class EmptyNextSessionCard extends StatelessWidget {
  const EmptyNextSessionCard({
    required this.hasClub,
    required this.onSuggestion,
    required this.onAddStudents,
    super.key,
  });

  /// Le club a déjà au moins un groupe.
  final bool hasClub;
  final VoidCallback onSuggestion;
  final VoidCallback onAddStudents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.homeEmptyTitle,
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasClub ? l10n.homeEmptyBody : l10n.homeEmptyNoClub),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (!hasClub)
                FilledButton(
                  onPressed: onAddStudents,
                  child: Text(l10n.studentsAdd),
                ),
              OutlinedButton(
                onPressed: onSuggestion,
                child: Text(l10n.homeSeeSuggestion),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Séances passées sans saisie des 7 derniers jours : « Noter les résultats ».
class ToRecordList extends StatelessWidget {
  const ToRecordList({
    required this.sessions,
    required this.onRecord,
    super.key,
  });

  final List<PlannedSessionSummary> sessions;
  final ValueChanged<PlannedSessionSummary> onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.homeToRecordTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final summary in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeToRecordLine(
                        summary.session.title,
                        dates.formatMediumDate(summary.session.date),
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRecord(summary),
                    child: Text(l10n.plannerRecord),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
