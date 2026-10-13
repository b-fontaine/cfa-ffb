import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:flutter/material.dart';

/// Écran « page introuvable » : message localisé et retour à l'accueil.
///
/// Partagé par la page d'adresse inconnue et par les pages dont l'identifiant
/// est bien formé mais inconnu (une page ne peut pas importer une autre page).
class MissingPageView extends StatelessWidget {
  const MissingPageView({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: l10n.notFoundTitle),
              Expanded(
                child: EmptyState(
                  message: l10n.notFoundMessage,
                  icon: Icons.explore_off_outlined,
                  action: FilledButton(
                    onPressed: onHome,
                    child: Text(l10n.notFoundGoHome),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
