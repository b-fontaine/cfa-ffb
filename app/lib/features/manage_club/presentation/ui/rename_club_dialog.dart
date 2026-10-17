import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:flutter/material.dart';

/// Demande le nouveau nom du club ; `null` si l'utilisateur annule. Le champ
/// reprend [current] et borne la saisie à `maxClubNameLength` caractères.
Future<String?> showRenameClubDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _RenameClubDialog(current: current),
    );

class _RenameClubDialog extends StatefulWidget {
  const _RenameClubDialog({required this.current});

  final String current;

  @override
  State<_RenameClubDialog> createState() => _RenameClubDialogState();
}

class _RenameClubDialogState extends State<_RenameClubDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.clubRename),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: maxClubNameLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: InputDecoration(labelText: l10n.clubRenameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
