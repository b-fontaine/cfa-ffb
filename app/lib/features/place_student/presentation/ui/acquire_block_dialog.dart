import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre la boîte « Marquer le bloc acquis » ; elle se ferme d'elle-même une
/// fois le bloc marqué, et affiche les refus sous le sélecteur de date.
Future<void> showAcquireBlockDialog(
  BuildContext context, {
  required StudentId studentId,
  required String blockId,
  required String blockTitle,
  required int exerciseCount,
  required DateTime today,
}) {
  final bloc = context.read<PlacementBloc>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: AcquireBlockDialog(
        studentId: studentId,
        blockId: blockId,
        blockTitle: blockTitle,
        exerciseCount: exerciseCount,
        today: today,
      ),
    ),
  );
}

/// Boîte de positionnement : date du jour par défaut, jamais dans le futur
/// (le refus vient du cas d'usage et s'affiche sous la date).
class AcquireBlockDialog extends StatefulWidget {
  const AcquireBlockDialog({
    required this.studentId,
    required this.blockId,
    required this.blockTitle,
    required this.exerciseCount,
    required this.today,
    super.key,
  });

  final StudentId studentId;
  final String blockId;
  final String blockTitle;
  final int exerciseCount;
  final DateTime today;

  @override
  State<AcquireBlockDialog> createState() => _AcquireBlockDialogState();
}

class _AcquireBlockDialogState extends State<AcquireBlockDialog> {
  late DateTime _date = widget.today;
  bool _submitted = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: widget.today.add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    return BlocConsumer<PlacementBloc, PlacementState>(
      listenWhen: (previous, current) =>
          _submitted && current.status == PlacementStatus.done,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) {
        final working = state.status == PlacementStatus.working;
        final failure = state.failure;
        return AlertDialog(
          title: Text(l10n.placementDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.blockTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.placementDialogBody(widget.exerciseCount),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(l10n.placementDateLabel),
              ),
              Text(
                dates.formatMediumDate(_date),
                style: theme.textTheme.bodyLarge,
              ),
              if (_submitted &&
                  state.status == PlacementStatus.refused &&
                  failure != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failureMessage(l10n, failure),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: working
                  ? null
                  : () {
                      setState(() => _submitted = true);
                      context.read<PlacementBloc>().add(
                        PlacementEvent.markRequested(
                          studentId: widget.studentId,
                          blockId: widget.blockId,
                          date: _date,
                        ),
                      );
                    },
              child: Text(l10n.placementConfirm),
            ),
          ],
        );
      },
    );
  }
}
