import 'dart:async';

import 'package:billard_cfa/features/manage_groups/presentation/bloc/move_student_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre la feuille « Changer de groupe » de l'élève ; elle se ferme d'elle
/// même une fois l'élève déplacé et rend le nom du groupe d'arrivée (`null`
/// si l'animateur l'a fermée sans déplacer).
Future<String?> showMoveStudentDialog(
  BuildContext context, {
  required StudentId studentId,
}) {
  final cubit = context.read<MoveStudentCubit>();
  unawaited(cubit.load(studentId));
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: MoveStudentDialog(studentId: studentId),
    ),
  );
}

/// Boîte de déplacement : le groupe actuel, les groupes possibles (même
/// saison, même public), la date d'effet (aujourd'hui par défaut) et le refus
/// éventuel du cas d'usage sous la date.
class MoveStudentDialog extends StatefulWidget {
  const MoveStudentDialog({required this.studentId, super.key});

  final StudentId studentId;

  @override
  State<MoveStudentDialog> createState() => _MoveStudentDialogState();
}

class _MoveStudentDialogState extends State<MoveStudentDialog> {
  GroupId? _target;
  DateTime? _date;

  Future<void> _pickDate(DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    return BlocConsumer<MoveStudentCubit, MoveStudentState>(
      listenWhen: (previous, current) =>
          current.status == MoveStudentStatus.moved,
      listener: (context, state) => Navigator.of(context).pop(state.movedTo),
      builder: (context, state) {
        final options = state.options;
        final cubit = context.read<MoveStudentCubit>();
        final today = cubit.today;
        final date = _date ?? today;
        if (options == null) {
          final failure = state.failure;
          return AlertDialog(
            content: failure == null
                ? const SizedBox(height: 120, child: LoadingView())
                : Text(
                    failureMessage(l10n, failure),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          );
        }
        final working = state.status == MoveStudentStatus.moving;
        final failure = state.failure;
        return AlertDialog(
          title: Text(l10n.studentMoveTitle(options.firstName)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  options.current == null
                      ? l10n.studentMoveNoGroup
                      : l10n.studentMoveCurrent(options.current!.name),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (options.destinations.isEmpty)
                  Text(l10n.studentMoveNoDestination)
                else ...[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.studentMoveTo,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  RadioGroup<GroupId>(
                    groupValue: _target,
                    onChanged: (value) => setState(() => _target = value),
                    child: Column(
                      children: [
                        for (final choice in options.destinations)
                          RadioListTile<GroupId>(
                            key: ValueKey('move-target:${choice.id.value}'),
                            value: choice.id,
                            title: Text(choice.name),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _pickDate(today),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(l10n.studentMoveFrom),
                  ),
                  Text(
                    dates.formatMediumDate(date),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    failureMessage(l10n, failure),
                    style: TextStyle(color: theme.colorScheme.error),
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
              onPressed: working || _target == null
                  ? null
                  : () => cubit.submit(
                      studentId: widget.studentId,
                      toGroupId: _target!,
                      on: date,
                    ),
              child: Text(l10n.studentMoveConfirm),
            ),
          ],
        );
      },
    );
  }
}
