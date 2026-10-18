import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:flutter/material.dart';

/// Le serveur refuse la lecture des clubs du compte (règle, index manquant) :
/// message localisé et « Se déconnecter », **sans** « Réessayer » (réessayer ne
/// corrige ni un accès refusé ni une configuration absente).
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessDeniedTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: ErrorView(message: l10n.accessDeniedBody)),
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
