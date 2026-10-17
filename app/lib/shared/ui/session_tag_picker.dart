import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Libellé d'une étiquette de la note de jeu, dans la langue de l'application.
String sessionTagLabel(AppLocalizations l10n, SessionTag tag) => switch (tag) {
  SessionTag.gameAppreciated => l10n.sessionTagGameAppreciated,
  SessionTag.instructionsToRephrase => l10n.sessionTagInstructionsToRephrase,
  SessionTag.tooLong => l10n.sessionTagTooLong,
  SessionTag.tooShort => l10n.sessionTagTooShort,
  SessionTag.tooHard => l10n.sessionTagTooHard,
  SessionTag.tooEasy => l10n.sessionTagTooEasy,
  SessionTag.toRedo => l10n.sessionTagToRedo,
  SessionTag.equipmentLacking => l10n.sessionTagEquipmentLacking,
};

/// Choix multiple d'étiquettes de la note de jeu d'une séance (ADR 0023).
///
/// Liste **fermée** : toutes les étiquettes de [SessionTag] sont proposées,
/// dans l'ordre d'affichage, et rien d'autre (aucun champ de texte : un texte
/// libre pourrait nommer un enfant). Un `FilterChip` par étiquette ; l'état
/// choisi n'est jamais porté par la couleur seule (coche), la cible fait au
/// moins 48 dp, le lecteur d'écran annonce « sélectionné ».
///
/// Sans composant d'état : l'appelant fournit [selected] et reçoit le nouvel
/// ensemble par [onChanged] (jamais l'ensemble donné, muté). Sans [onChanged],
/// la liste est en lecture seule.
class SessionTagPicker extends StatelessWidget {
  const SessionTagPicker({required this.selected, this.onChanged, super.key});

  final Set<SessionTag> selected;
  final ValueChanged<Set<SessionTag>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final change = onChanged;
    return Wrap(
      key: const ValueKey('session-tags'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in SessionTag.values)
          FilterChip(
            key: ValueKey('session-tag-${tag.name}'),
            label: Text(sessionTagLabel(l10n, tag)),
            selected: selected.contains(tag),
            showCheckmark: true,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: change == null
                ? null
                : (on) => change(
                    on ? {...selected, tag} : ({...selected}..remove(tag)),
                  ),
          ),
      ],
    );
  }
}
