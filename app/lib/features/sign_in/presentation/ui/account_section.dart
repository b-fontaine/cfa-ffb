import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le compte connecté (adresse, club actif et rôle), la déconnexion et
/// « Supprimer mon compte » ([onDeleteAccount], FB8 partie B). Posé dans
/// « Plus ».
class AccountSection extends StatelessWidget {
  const AccountSection({
    required this.email,
    required this.clubName,
    required this.roleLabel,
    required this.onSignOut,
    this.onDeleteAccount,
    super.key,
  });

  final String email;
  final String clubName;

  /// Rôle déjà traduit (le widget ne connaît pas les rôles).
  final String roleLabel;
  final VoidCallback onSignOut;

  /// Ouvre « Supprimer mon compte » ; absent, l'entrée n'est pas montrée.
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.accountSectionTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.accountSignedInAs(email)),
            Text(l10n.accountClub(clubName, roleLabel)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: Text(l10n.accountSignOut),
            ),
            if (onDeleteAccount != null)
              TextButton.icon(
                onPressed: onDeleteAccount,
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(l10n.deleteAccountTitle),
              ),
          ],
        ),
      ),
    );
  }
}
