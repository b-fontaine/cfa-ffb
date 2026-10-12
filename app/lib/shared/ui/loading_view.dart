import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Chargement en cours : indicateur annoncé aux lecteurs d'écran.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
    );
  }
}
