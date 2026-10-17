import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/features/select_club/presentation/ui/club_choice_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// Choix du club actif, à l'ouverture (plusieurs clubs, aucun retenu) ou en
/// cours d'usage (« Changer de club », [onBack] ramène à « Plus »).
///
/// Sans club ([choices] vide), la page l'explique et propose d'actualiser puis
/// de se déconnecter. [blocked] : une séance guidée est en cours, la bascule
/// est refusée et la page le dit.
class SelectClubPage extends StatelessWidget {
  const SelectClubPage({
    required this.choices,
    required this.onChoose,
    required this.onSignOut,
    this.current,
    this.blocked = false,
    this.onRefresh,
    this.onBack,
    super.key,
  });

  final List<ClubMembership> choices;
  final ClubId? current;
  final bool blocked;
  final ValueChanged<ClubMembership> onChoose;
  final VoidCallback onSignOut;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final empty = choices.isEmpty;
    return ScrollPage(
      title: empty
          ? l10n.noClubTitle
          : onBack == null
          ? l10n.selectClubTitle
          : l10n.moreSwitchClub,
      subtitle: empty ? l10n.noClubBody : l10n.selectClubIntro,
      onBack: onBack,
      backLabel: onBack == null ? null : l10n.switchClubBackToMore,
      maxWidth: 480,
      children: [
        if (blocked)
          AppAlert(
            level: AlertLevel.attention,
            message: l10n.selectClubBlocked,
          ),
        if (!empty)
          ClubChoiceList(
            choices: choices,
            current: current,
            enabled: !blocked,
            onChoose: onChoose,
          ),
        if (empty && onRefresh != null)
          FilledButton(onPressed: onRefresh, child: Text(l10n.noClubRefresh)),
        if (onBack == null)
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: Text(l10n.accountSignOut),
          ),
      ],
    );
  }
}
