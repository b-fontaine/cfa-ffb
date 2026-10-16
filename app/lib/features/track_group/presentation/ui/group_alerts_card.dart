import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Les alertes de groupe de « Aujourd'hui » : trois au plus, chacune avec son
/// groupe, et un lien vers la grille du groupe. Rien sans alerte.
class GroupAlertsCard extends StatelessWidget {
  const GroupAlertsCard({
    required this.alerts,
    required this.onOpenGroup,
    super.key,
  });

  final GroupAlertList alerts;
  final ValueChanged<GroupId> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    if (alerts.lines.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hidden = alerts.total - alerts.lines.length;
    return SectionCard(
      title: l10n.groupAlertsTitle,
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, line) in alerts.lines.indexed)
            () {
              final message = l10n.groupAlertLine(
                line.alert.failed,
                line.alert.members,
                line.alert.blockTitle,
              );
              return Semantics(
                key: ValueKey('group-alert-$index'),
                container: true,
                button: true,
                label: l10n.groupAlertOpen(line.groupName, message),
                excludeSemantics: true,
                onTap: () => onOpenGroup(line.groupId),
                child: InkWell(
                  onTap: () => onOpenGroup(line.groupId),
                  borderRadius: AppRadii.smallRadius,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.groupName,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  message,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const ExcludeSemantics(
                            child: Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }(),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.groupAlertsMore(hidden),
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
