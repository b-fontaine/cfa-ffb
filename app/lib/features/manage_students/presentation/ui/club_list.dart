import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Les groupes de la saison : élèves, public (badge) et alertes.
class ClubList extends StatelessWidget {
  const ClubList({required this.club, required this.onOpenStudent, super.key});

  final ClubOverview club;
  final ValueChanged<StudentId> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in club.groups) ...[
          SectionCard(
            title: group.group.name,
            child: _Members(
              count: group.members.length,
              members: group.members,
              onOpenStudent: onOpenStudent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (club.unassigned.isNotEmpty)
          SectionCard(
            title: l10n.studentsUnassigned,
            child: _Members(
              count: club.unassigned.length,
              members: club.unassigned,
              onOpenStudent: onOpenStudent,
            ),
          ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({
    required this.count,
    required this.members,
    required this.onOpenStudent,
  });

  final int count;
  final List<StudentSummary> members;
  final ValueChanged<StudentId> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.studentsMemberCount(count),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final member in members)
          Semantics(
            button: true,
            label: l10n.studentsOpenSheet(member.student.firstName),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onOpenStudent(member.student.id),
              borderRadius: AppRadii.smallRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTouchTarget + AppSpacing.md,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.student.firstName,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AudienceBadge(
                                  kind: member.student.currentAudience.kind,
                                ),
                                Text(
                                  l10n.studentsValidated(
                                    member.validatedCount,
                                    member.exerciseCount,
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (member.alertCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(
                          tone: BadgeTone.attention,
                          label: l10n.studentsAlerts(member.alertCount),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.xs),
                      const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
