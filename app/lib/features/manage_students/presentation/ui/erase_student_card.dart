import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Effacement définitif d'un élève (droit à l'effacement), toujours confirmé.
/// [onErased] est appelé une fois l'élève effacé.
class EraseStudentCard extends StatelessWidget {
  const EraseStudentCard({
    required this.studentId,
    required this.studentName,
    required this.onErased,
    super.key,
  });

  final StudentId studentId;
  final String studentName;
  final VoidCallback onErased;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<StudentErasureBloc, StudentErasureState>(
      listenWhen: (previous, current) =>
          current.status == StudentErasureStatus.erased,
      listener: (context, state) => onErased(),
      builder: (context, state) {
        final failure = state.failure;
        return SectionCard(
          title: l10n.eraseTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.eraseBody(studentName),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: state.status == StudentErasureStatus.working
                    ? null
                    : () async {
                        final bloc = context.read<StudentErasureBloc>();
                        final confirmed = await showConfirmDialog(
                          context,
                          title: l10n.eraseConfirmTitle(studentName),
                          message: l10n.eraseConfirmBody(studentName),
                        );
                        if (confirmed) {
                          bloc.add(
                            StudentErasureEvent.requested(studentId: studentId),
                          );
                        }
                      },
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.eraseAction(studentName)),
              ),
              if (failure != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failureMessage(l10n, failure),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
