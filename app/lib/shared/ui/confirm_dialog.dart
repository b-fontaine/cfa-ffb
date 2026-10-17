import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Demande une confirmation explicite ; `false` si l'utilisateur annule ou
/// ferme la boîte. [confirmLabel] nomme l'action quand « Confirmer » serait
/// trop vague (« Retirer »).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.commonConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
