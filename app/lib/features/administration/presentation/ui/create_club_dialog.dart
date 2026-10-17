import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:flutter/material.dart';

/// Demande le nom du club à créer ; `null` si l'utilisateur annule. Le champ
/// borne la saisie à `maxClubNameLength` caractères.
Future<String?> showCreateClubDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _CreateClubDialog(),
    );

class _CreateClubDialog extends StatefulWidget {
  const _CreateClubDialog();

  @override
  State<_CreateClubDialog> createState() => _CreateClubDialogState();
}

class _CreateClubDialogState extends State<_CreateClubDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminCreateClub),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: maxClubNameLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: InputDecoration(labelText: l10n.adminClubNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.adminCreateConfirm),
        ),
      ],
    );
  }
}
