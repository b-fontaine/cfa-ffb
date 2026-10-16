import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/now_card.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// La séance guidée en cours : étape, séance planifiée d'origine, « Reprendre
/// à l'étape n » et « Abandonner ». Mise en avant (bord bleu-tapis).
class RunningSessionCard extends StatelessWidget {
  const RunningSessionCard({
    required this.session,
    required this.onResume,
    required this.onAbandon,
    this.groupName,
    super.key,
  });

  final RunningSession session;

  /// Nom du groupe de la séance planifiée d'origine, s'il est connu.
  final String? groupName;
  final VoidCallback onResume;
  final VoidCallback onAbandon;

  /// Séance planifiée d'origine : « lun. 12 oct. · Jeunes ».
  String? _origin(BuildContext context, AppLocalizations l10n) {
    final date = session.plannedDate;
    if (date == null) return null;
    final formatted = MaterialLocalizations.of(context).formatMediumDate(date);
    final group = groupName;
    return group == null ? formatted : l10n.homeDateGroup(formatted, group);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NowCard(
      stateLabel: l10n.homeNowRunning,
      stateIcon: Icons.play_circle_outline,
      emphasis: SectionEmphasis.high,
      title: l10n.sheetFullTitle(
        session.sheetTitle,
        session.part,
        session.partCount,
      ),
      meta: [
        l10n.guideStepCounter(session.step + 1, session.stepCount),
        ?_origin(context, l10n),
      ],
      primaryLabel: l10n.guideResume(session.step + 1),
      onPrimary: onResume,
      secondaryLabel: l10n.homeAbandon,
      onSecondary: onAbandon,
    );
  }
}

/// Une autre séance commencée, en ligne : « Reprendre ».
class RunningSessionRow extends StatelessWidget {
  const RunningSessionRow({
    required this.session,
    required this.onResume,
    super.key,
  });

  final RunningSession session;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.homeOtherRunning(
              l10n.sheetFullTitle(
                session.sheetTitle,
                session.part,
                session.partCount,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(onPressed: onResume, child: Text(l10n.homeResume)),
      ],
    );
  }
}
