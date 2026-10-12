import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Choix d'un groupe et des élèves attendus ou présents (cases à cocher de
/// 48 dp). Sans état : la page garde la sélection.
class RosterPicker extends StatelessWidget {
  const RosterPicker({
    required this.groups,
    required this.selectedGroupId,
    required this.present,
    required this.onGroupSelected,
    required this.onPresenceChanged,
    this.studentsLabel,
    super.key,
  });

  final List<GroupOverview> groups;
  final GroupId? selectedGroupId;
  final Set<StudentId> present;
  final ValueChanged<GroupId> onGroupSelected;
  final void Function(StudentId student, {required bool isPresent})
  onPresenceChanged;

  /// Titre de la liste d'élèves (à défaut : « Élèves présents »).
  final String? studentsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    GroupOverview? selected;
    for (final group in groups) {
      if (group.group.id == selectedGroupId) selected = group;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.recordGroup, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final group in groups)
              ChoiceChip(
                label: Text(group.group.name),
                selected: group.group.id == selectedGroupId,
                onSelected: (_) => onGroupSelected(group.group.id),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              studentsLabel ?? l10n.recordPresent,
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final member in selected.members)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(member.student.firstName),
              value: present.contains(member.student.id),
              onChanged: (checked) => onPresenceChanged(
                member.student.id,
                isPresent: checked ?? false,
              ),
            ),
        ],
      ],
    );
  }
}
