import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Ce que la boîte du groupe rend : le nom saisi et, à la création, le public.
typedef GroupFormResult = ({String name, Audience audience});

/// Ouvre la boîte du groupe : création (nom et public) ou renommage (nom
/// seulement, le public d'un groupe ne change pas). `null` si annulée.
Future<GroupFormResult?> showGroupFormDialog(
  BuildContext context, {
  required bool creating,
  String initialName = '',
  Audience audience = Audience.children,
}) => showDialog<GroupFormResult>(
  context: context,
  builder: (_) => GroupFormDialog(
    creating: creating,
    initialName: initialName,
    audience: audience,
  ),
);

class GroupFormDialog extends StatefulWidget {
  const GroupFormDialog({
    required this.creating,
    required this.initialName,
    required this.audience,
    super.key,
  });

  final bool creating;
  final String initialName;
  final Audience audience;

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late Audience _audience = widget.audience;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, audience: _audience));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.creating ? l10n.groupFormCreateTitle : l10n.groupFormRenameTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('group-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: l10n.groupFormName),
            ),
            if (widget.creating) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  l10n.studentFormAudience,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<Audience>(
                segments: [
                  for (final audience in Audience.values)
                    ButtonSegment(
                      value: audience,
                      label: Text(audience.label(l10n)),
                    ),
                ],
                selected: {_audience},
                onSelectionChanged: (selection) =>
                    setState(() => _audience = selection.first),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.creating ? l10n.groupFormCreate : l10n.commonSave),
        ),
      ],
    );
  }
}
