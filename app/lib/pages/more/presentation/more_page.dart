import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// Destination « Plus » : liste des outils du club qui ne sont pas un parcours
/// quotidien. Chaque entrée mène à un écran existant ; « À propos et sources »
/// s'y ajoutera avec son écran.
class MorePage extends StatelessWidget {
  const MorePage({
    required this.onOpenBackup,
    required this.onOpenSettings,
    super.key,
  });

  final VoidCallback onOpenBackup;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.moreTitle,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: Text(l10n.moreBackup),
            subtitle: Text(l10n.moreBackupHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenBackup,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.moreSettings),
            subtitle: Text(l10n.moreSettingsHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenSettings,
          ),
        ),
      ],
    );
  }
}
