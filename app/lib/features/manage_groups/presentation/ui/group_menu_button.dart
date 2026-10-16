import 'package:billard_cfa/features/manage_groups/presentation/bloc/manage_groups_cubit.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/group_form_dialog.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _GroupAction { rename, delete }

/// Menu ⋮ d'un groupe : renommer, supprimer (seulement vide et sans séance :
/// le refus du cas d'usage s'affiche en retour). Les confirmations sont
/// demandées ici, l'action part au [ManageGroupsCubit] fourni par la page.
class GroupMenuButton extends StatelessWidget {
  const GroupMenuButton({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final GroupId groupId;
  final String groupName;

  Future<void> _on(BuildContext context, _GroupAction action) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ManageGroupsCubit>();
    switch (action) {
      case _GroupAction.rename:
        final result = await showGroupFormDialog(
          context,
          creating: false,
          initialName: groupName,
        );
        if (result != null) {
          await cubit.rename(groupId: groupId, name: result.name);
        }
      case _GroupAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.groupDeleteTitle,
          message: l10n.groupDeleteBody(groupName),
        );
        if (confirmed) await cubit.delete(groupId: groupId, name: groupName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_GroupAction>(
      key: ValueKey('group-menu:${groupId.value}'),
      tooltip: l10n.groupMenuLabel(groupName),
      onSelected: (action) => _on(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _GroupAction.rename,
          child: Text(l10n.groupRename),
        ),
        PopupMenuItem(
          value: _GroupAction.delete,
          child: Text(l10n.groupDelete),
        ),
      ],
    );
  }
}

/// Bouton « Nouveau groupe » : nom et public, dans la [seasonId] donnée.
class NewGroupButton extends StatelessWidget {
  const NewGroupButton({required this.seasonId, super.key});

  final SeasonId seasonId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: () async {
        final cubit = context.read<ManageGroupsCubit>();
        final result = await showGroupFormDialog(context, creating: true);
        if (result != null) {
          await cubit.create(
            seasonId: seasonId,
            name: result.name,
            audience: result.audience,
          );
        }
      },
      icon: const Icon(Icons.group_add_outlined),
      label: Text(l10n.groupsNew),
    );
  }
}
