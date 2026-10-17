import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:flutter/material.dart';

/// Les clubs d'un compte, à choisir. Chaque ligne fait au moins 48 dp et se
/// lit « club, rôle » ; le club actif est marqué (icône, texte et état
/// « sélectionné », jamais la couleur seule). [enabled] faux : la liste est
/// affichée mais inerte (bascule interdite pendant une séance guidée).
class ClubChoiceList extends StatelessWidget {
  const ClubChoiceList({
    required this.choices,
    required this.onChoose,
    this.current,
    this.enabled = true,
    super.key,
  });

  final List<ClubMembership> choices;
  final ClubId? current;
  final bool enabled;
  final ValueChanged<ClubMembership> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        for (final club in choices)
          Card(
            child: ListTile(
              enabled: enabled,
              selected: club.clubId == current,
              leading: Icon(
                club.clubId == current
                    ? Icons.check_circle
                    : Icons.sports_bar_outlined,
              ),
              title: Text(club.clubName),
              subtitle: Text(
                club.clubId == current
                    ? l10n.selectClubRoleCurrent(club.role.label(l10n))
                    : club.role.label(l10n),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: enabled ? () => onChoose(club) : null,
            ),
          ),
      ],
    );
  }
}
