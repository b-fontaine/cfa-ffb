import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// Destination « Plus » : liste des outils du club qui ne sont pas un parcours
/// quotidien. Chaque entrée mène à un écran existant ; « À propos et sources »
/// s'y ajoutera avec son écran.
///
/// Une entrée sans action n'est **pas affichée** : l'appelant ne donne que ce
/// que le rôle peut ouvrir (le garde de route refuse aussi ce que le menu ne
/// montre pas, ADR 0024).
class MorePage extends StatelessWidget {
  const MorePage({
    this.onOpenBackup,
    this.onOpenSettings,
    this.onOpenSeasons,
    this.onOpenClub,
    this.onOpenAdministration,
    this.account,
    this.onSwitchClub,
    super.key,
  });

  final VoidCallback? onOpenBackup;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenSeasons;

  /// Ouvre « Mon club » (enseignant, directeur, administrateur).
  final VoidCallback? onOpenClub;

  /// Ouvre « Administration » (administrateur seulement).
  final VoidCallback? onOpenAdministration;

  /// Le compte connecté et la déconnexion (`AccountSection`), fournis par le
  /// routeur ; absent hors d'une session ouverte.
  final Widget? account;

  /// Ouvre « Changer de club » ; absent quand le compte n'a qu'un club.
  final VoidCallback? onSwitchClub;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.moreTitle,
      children: [
        ?account,
        if (onSwitchClub != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.moreSwitchClub),
              subtitle: Text(l10n.moreSwitchClubHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: onSwitchClub,
            ),
          ),
        if (onOpenClub != null)
          _MoreEntry(
            icon: Icons.groups_outlined,
            title: l10n.moreClub,
            subtitle: l10n.moreClubHint,
            onTap: onOpenClub!,
          ),
        if (onOpenAdministration != null)
          _MoreEntry(
            icon: Icons.admin_panel_settings_outlined,
            title: l10n.moreAdministration,
            subtitle: l10n.moreAdministrationHint,
            onTap: onOpenAdministration!,
          ),
        if (onOpenBackup != null)
          _MoreEntry(
            icon: Icons.save_alt_outlined,
            title: l10n.moreBackup,
            subtitle: l10n.moreBackupHint,
            onTap: onOpenBackup!,
          ),
        if (onOpenSeasons != null)
          _MoreEntry(
            icon: Icons.history,
            title: l10n.moreSeasons,
            subtitle: l10n.moreSeasonsHint,
            onTap: onOpenSeasons!,
          ),
        if (onOpenSettings != null)
          _MoreEntry(
            icon: Icons.tune,
            title: l10n.moreSettings,
            subtitle: l10n.moreSettingsHint,
            onTap: onOpenSettings!,
          ),
      ],
    );
  }
}

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
