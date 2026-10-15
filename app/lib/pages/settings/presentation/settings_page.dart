import 'package:billard_cfa/features/manage_settings/presentation/ui/settings_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// Réglages du club (bloc fourni par l'appelant), ouverts depuis « Plus » :
/// [onBack] y ramène.
class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.settingsTitle,
      onBack: onBack,
      backLabel: l10n.settingsBackToMore,
      children: const [SettingsForm()],
    );
  }
}
