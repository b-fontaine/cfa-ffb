import 'package:billard_cfa/features/acknowledge_alert/presentation/bloc/acknowledgement_bloc.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/move_student_dialog.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/erase_student_card.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/ui/acquire_block_dialog.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/student_recall_card.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/student_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fiche d'un élève : en-tête (en cours, prochain, alerte), parcours en cases,
/// notion à rappeler, courbes repliées, et en bas les actions rares (modifier,
/// bilan, effacer). Les blocs (fiche, rappel, effacement, positionnement,
/// acquittement) sont fournis par l'appelant ; [today] est lu à l'ouverture de
/// la boîte et borne la date du positionnement.
///
/// La page compose le positionnement (ADR 0008) : boîte de dialogue,
/// confirmation, retour par `SnackBar` et rechargement de la fiche et de la
/// notion à rappeler ; et l'acquittement d'une alerte (ADR 0013) : « Vu » et
/// « Rétablir », retour par `SnackBar` et rechargement de la fiche. [onShow]
/// ouvre la vue « à montrer à l'élève ».
class StudentSheetPage extends StatelessWidget {
  const StudentSheetPage({
    required this.onBack,
    required this.onEdit,
    required this.onOpenAssessment,
    required this.onErased,
    required this.onShow,
    required this.today,
    this.canErase = true,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onOpenAssessment;

  /// Appelé quand l'élève vient d'être effacé (la fiche n'existe plus) : écouté
  /// ici, au-dessus de la fiche qui se recharge en direct.
  final VoidCallback onErased;

  /// Ouvre la vue « à montrer à l'élève ».
  final VoidCallback onShow;
  final DateTime Function() today;

  /// Le rôle peut effacer un élève (directeur et administrateur) : sinon la
  /// carte d'effacement n'est pas proposée (les règles du serveur la
  /// refuseraient).
  final bool canErase;

  Future<void> _mark(BuildContext context, StudentSheet sheet, String blockId) {
    final block = sheet.catalogue.blockById(blockId)!;
    return showAcquireBlockDialog(
      context,
      studentId: sheet.student.id,
      blockId: blockId,
      blockTitle: block.title,
      exerciseCount: block.exercises.length,
      today: today(),
    );
  }

  /// Ouvre la boîte « Changer de groupe » ; l'élève déplacé, un message le dit
  /// et la fiche se relit.
  Future<void> _move(BuildContext context, StudentSheet sheet) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<StudentSheetBloc>();
    final group = await showMoveStudentDialog(
      context,
      studentId: sheet.student.id,
    );
    if (group == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.studentMoved(sheet.student.firstName, group)),
        ),
      );
    bloc.add(const StudentSheetEvent.refreshed());
  }

  Future<void> _revoke(
    BuildContext context,
    StudentSheet sheet,
    String blockId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<PlacementBloc>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.placementRevokeTitle(
        sheet.catalogue.blockById(blockId)!.title,
      ),
      message: l10n.placementRevokeBody,
    );
    if (confirmed) {
      bloc.add(
        PlacementEvent.revokeRequested(
          studentId: sheet.student.id,
          blockId: blockId,
        ),
      );
    }
  }

  void _onPlacement(BuildContext context, PlacementState placement) {
    final l10n = AppLocalizations.of(context);
    final sheet = context.read<StudentSheetBloc>().state.sheet;
    final String message;
    if (placement.status == PlacementStatus.refused) {
      message = failureMessage(l10n, placement.failure!);
    } else if (placement.action == PlacementAction.mark) {
      message = l10n.placementMarked(
        sheet?.catalogue.blockById(placement.blockId!)?.title ??
            placement.blockId!,
      );
    } else {
      message = l10n.placementRevoked;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (placement.status == PlacementStatus.done) {
      context.read<StudentSheetBloc>().add(const StudentSheetEvent.refreshed());
      // La notion à rappeler lit aussi les marqueurs : elle se recalcule.
      final studentId = sheet?.student.id;
      if (studentId != null) {
        context.read<StudentRecallBloc>().add(
          StudentRecallEvent.started(studentId: studentId),
        );
      }
    }
  }

  void _onAcknowledgement(BuildContext context, AcknowledgementState ack) {
    final l10n = AppLocalizations.of(context);
    final message = ack.status == AcknowledgementStatus.refused
        ? failureMessage(l10n, ack.failure!)
        : ack.action == AcknowledgementAction.restore
        ? l10n.sheetAlertRestored
        : l10n.sheetAlertMarkedSeen;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    // La fiche se relit dans les deux cas : un refus signale une alerte qui
    // n'est plus active, que l'écran montrait peut-être encore.
    context.read<StudentSheetBloc>().add(const StudentSheetEvent.refreshed());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<PlacementBloc, PlacementState>(
          // Un refus de marquage s'affiche sous la date de la boîte, pas ici.
          listenWhen: (previous, current) =>
              current.status == PlacementStatus.done ||
              (current.status == PlacementStatus.refused &&
                  current.action == PlacementAction.revoke),
          listener: _onPlacement,
        ),
        BlocListener<AcknowledgementBloc, AcknowledgementState>(
          listenWhen: (previous, current) =>
              current.status == AcknowledgementStatus.done ||
              current.status == AcknowledgementStatus.refused,
          listener: _onAcknowledgement,
        ),
        // La fiche se recharge en direct : elle disparaît avec l'élève (la page
        // peut alors montrer « introuvable » avant que la carte d'effacement ne
        // le dise). L'effacement fini est donc écouté ici, plus haut que la
        // carte, pour ramener toujours à la liste.
        BlocListener<StudentErasureBloc, StudentErasureState>(
          listenWhen: (previous, current) =>
              current.status == StudentErasureStatus.erased,
          listener: (context, state) => onErased(),
        ),
      ],
      child: _sheet(context, l10n),
    );
  }

  void _acknowledge(
    BuildContext context,
    StudentSheet sheet,
    ExerciseRef ref,
  ) => context.read<AcknowledgementBloc>().add(
    AcknowledgementEvent.acknowledgeRequested(
      studentId: sheet.student.id,
      exercise: ref,
    ),
  );

  void _restore(BuildContext context, StudentSheet sheet, ExerciseRef ref) =>
      context.read<AcknowledgementBloc>().add(
        AcknowledgementEvent.restoreRequested(
          studentId: sheet.student.id,
          exercise: ref,
        ),
      );

  Widget _sheet(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<StudentSheetBloc, StudentSheetState>(
      builder: (context, state) {
        final sheet = state.sheet;
        final failure = state.failure;
        switch (state.status) {
          case StudentSheetStatus.loading:
            return const Scaffold(body: LoadingView());
          case StudentSheetStatus.failure:
            return Scaffold(
              body: ErrorView(
                message: failureMessage(l10n, failure!),
                onRetry: () => context.read<StudentSheetBloc>().add(
                  const StudentSheetEvent.refreshed(),
                ),
              ),
            );
          case StudentSheetStatus.ready:
            return ScrollPage(
              title: sheet!.student.firstName,
              onBack: onBack,
              backLabel: l10n.navStudents,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: onShow,
                    icon: const Icon(Icons.slideshow),
                    label: Text(l10n.sheetShow),
                  ),
                ),
                BlocBuilder<StudentRecallBloc, StudentRecallState>(
                  builder: (context, recall) => StudentSheetView(
                    sheet: sheet,
                    recall: recall.status == RecallStatus.ready
                        ? StudentRecallCard(advice: recall.advice)
                        : null,
                    onAcknowledge: (ref) => _acknowledge(context, sheet, ref),
                    onRestore: (ref) => _restore(context, sheet, ref),
                    onMarkAcquired: (blockId) => _mark(context, sheet, blockId),
                    onRevokeAcquired: (blockId) =>
                        _revoke(context, sheet, blockId),
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.sheetEdit),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _move(context, sheet),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.studentMoveAction),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenAssessment,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.sheetOpenAssessment),
                    ),
                  ],
                ),
                if (canErase)
                  EraseStudentCard(
                    studentId: sheet.student.id,
                    studentName: sheet.student.firstName,
                  ),
              ],
            );
        }
      },
    );
  }
}
