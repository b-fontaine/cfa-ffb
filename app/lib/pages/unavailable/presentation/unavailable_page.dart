import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:flutter/material.dart';

/// Le service de comptes est indisponible : message localisé et « Réessayer ».
class UnavailablePage extends StatelessWidget {
  const UnavailablePage({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.unavailableTitle)),
      body: SafeArea(
        child: ErrorView(message: l10n.unavailableBody, onRetry: onRetry),
      ),
    );
  }
}
