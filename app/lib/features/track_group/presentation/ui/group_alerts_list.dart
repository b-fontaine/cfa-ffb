import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:flutter/material.dart';

/// Les alertes d'un groupe, en tête de sa vue : « 4 élèves sur 8 ont manqué
/// « Demi-bille » à leur dernier passage ». Ton « attention », jamais de rouge
/// ; rien du tout sans alerte.
class GroupAlertsList extends StatelessWidget {
  const GroupAlertsList({required this.alerts, super.key});

  final List<GroupAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.groupAlertsTitle,
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, alert) in alerts.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  key: ValueKey('grid-alert-$index'),
                  tone: BadgeTone.attention,
                  label: l10n.groupAlertLine(
                    alert.failed,
                    alert.members,
                    alert.blockTitle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
