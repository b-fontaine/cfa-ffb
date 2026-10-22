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
/// [onErased] est appelé une fois l'élève effacé ; une page dont la fiche se
/// recharge en direct (elle disparaît avec l'élève) écoute plutôt le bloc
/// d'effacement elle-même et ne le fournit pas.
///
/// Dans un club synchronisé, l'effacement se fait par étapes : la carte montre
/// l'avancement (annoncé aux lecteurs d'écran), permet de l'arrêter entre deux
/// étapes et de le **reprendre** (coupure de connexion, plafond du jour,
/// fermeture de l'application) ; un effacement commencé est proposé à la
/// reprise dès l'ouverture de la fiche, sans nouvelle confirmation.
class EraseStudentCard extends StatefulWidget {
  const EraseStudentCard({
    required this.studentId,
    required this.studentName,
    this.onErased,
    super.key,
  });

  final StudentId studentId;
  final String studentName;
  final VoidCallback? onErased;

  @override
  State<EraseStudentCard> createState() => _EraseStudentCardState();
}

class _EraseStudentCardState extends State<EraseStudentCard> {
  @override
  void initState() {
    super.initState();
    context.read<StudentErasureBloc>().add(
      StudentErasureEvent.inspected(studentId: widget.studentId),
    );
  }

  Future<void> _confirmAndErase(
    BuildContext context,
    StudentErasureState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<StudentErasureBloc>();
    final name = widget.studentName;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.eraseConfirmTitle(name),
      message: state.synchronized
          ? l10n.eraseConfirmClubBody(name)
          : l10n.eraseConfirmBody(name),
    );
    if (confirmed) {
      bloc.add(StudentErasureEvent.requested(studentId: widget.studentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = widget.studentName;
    return BlocConsumer<StudentErasureBloc, StudentErasureState>(
      listenWhen: (previous, current) =>
          current.status == StudentErasureStatus.erased,
      listener: (context, state) => widget.onErased?.call(),
      builder: (context, state) {
        final failure = state.failure;
        final working = state.status == StudentErasureStatus.working;
        final resumable =
            state.inProgress &&
            state.status != StudentErasureStatus.erased &&
            !working;
        final notice = switch (state.status) {
          StudentErasureStatus.interrupted => l10n.eraseInterrupted,
          StudentErasureStatus.stopped => l10n.eraseStopped,
          StudentErasureStatus.paused => l10n.erasePaused,
          _ when resumable => l10n.eraseResumeNotice(name),
          _ => null,
        };
        return SectionCard(
          title: l10n.eraseTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.synchronized
                    ? l10n.eraseClubBody(name, state.preview.total)
                    : l10n.eraseBody(name),
                style: theme.textTheme.bodyMedium,
              ),
              if (state.synchronized) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.eraseClubLimits, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (notice != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(notice, style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (working) ...[
                Semantics(
                  liveRegion: true,
                  label: l10n.eraseProgress(state.done, state.total),
                  child: LinearProgressIndicator(
                    value: state.total == 0 ? null : state.done / state.total,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.eraseProgress(state.done, state.total),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.synchronized)
                  OutlinedButton.icon(
                    onPressed: () => context.read<StudentErasureBloc>().add(
                      const StudentErasureEvent.stopRequested(),
                    ),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: Text(l10n.eraseStop),
                  ),
              ] else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: state.status == StudentErasureStatus.idle
                      ? null
                      : resumable
                      ? () => context.read<StudentErasureBloc>().add(
                          StudentErasureEvent.requested(
                            studentId: widget.studentId,
                          ),
                        )
                      : () => _confirmAndErase(context, state),
                  icon: Icon(
                    resumable
                        ? Icons.play_arrow_outlined
                        : Icons.delete_forever_outlined,
                  ),
                  label: Text(
                    resumable ? l10n.eraseResume : l10n.eraseAction(name),
                  ),
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
