import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:flutter/material.dart';

/// Le service de comptes est indisponible : message localisé et « Réessayer ».
/// Quand un compte est connecté (ses clubs sont illisibles), « Se déconnecter »
/// reste possible : on n'est jamais coincé sur cet écran.
class UnavailablePage extends StatelessWidget {
  const UnavailablePage({required this.onRetry, this.onSignOut, super.key});

  final VoidCallback onRetry;

  /// Absent tant qu'aucun compte n'est connecté (le service ne démarre pas).
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.unavailableTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorView(message: l10n.unavailableBody, onRetry: onRetry),
            ),
            if (onSignOut != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.accountSignOut),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
