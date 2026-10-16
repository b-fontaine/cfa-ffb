import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Choix d'un groupe parmi plusieurs (inscription, changement de public) :
/// une ligne par groupe, sélection unique, cibles de 48 dp. [selected] est
/// `null` tant que rien n'est choisi.
class GroupChoicePicker extends StatelessWidget {
  const GroupChoicePicker({
    required this.choices,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<GroupChoice> choices;
  final GroupId? selected;
  final ValueChanged<GroupId> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.groupChoiceTitle, style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.groupChoiceHint, style: theme.textTheme.bodyMedium),
        RadioGroup<GroupId>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          child: Column(
            children: [
              for (final choice in choices)
                RadioListTile<GroupId>(
                  key: ValueKey('group-choice:${choice.id.value}'),
                  value: choice.id,
                  title: Text(choice.name),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
