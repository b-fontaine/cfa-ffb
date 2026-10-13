import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:flutter/material.dart';

/// Bandeau « le contenu est rédigé en français » : affiché quand l'interface
/// n'est pas en français (le contenu des séances n'est pas traduit, seule
/// l'interface l'est). Rien n'est affiché en français.
class FrenchContentNotice extends StatelessWidget {
  const FrenchContentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'fr') {
      return const SizedBox.shrink();
    }
    return AppAlert(
      level: AlertLevel.attention,
      message: AppLocalizations.of(context).contentInFrench,
    );
  }
}
