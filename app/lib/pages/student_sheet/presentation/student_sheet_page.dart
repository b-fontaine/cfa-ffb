import 'package:billard_cfa/features/manage_students/presentation/ui/erase_student_card.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/ui/acquire_block_dialog.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/student_recall_card.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/student_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fiche d'un élève : progression par bloc, courbes de performance, exercice
/// suivant et notion à rappeler. Les blocs (fiche, rappel, effacement,
/// positionnement) sont fournis par l'appelant ; [today] est lu à
/// l'ouverture de la boîte et borne la date du positionnement. La page
/// compose le positionnement (ADR 0008) : boîte de dialogue, confirmation,
/// retour par `SnackBar` et rechargement de la fiche et de la notion à
/// rappeler.
class StudentSheetPage extends StatelessWidget {
  const StudentSheetPage({
    required this.onBack,
    required this.onEdit,
    required this.onOpenAssessment,
    required this.onErased,
    required this.today,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onOpenAssessment;

  /// Appelé quand l'élève vient d'être effacé (la fiche n'existe plus).
  final VoidCallback onErased;
  final DateTime Function() today;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<PlacementBloc, PlacementState>(
      // Un refus de marquage s'affiche sous la date de la boîte, pas ici.
      listenWhen: (previous, current) =>
          current.status == PlacementStatus.done ||
          (current.status == PlacementStatus.refused &&
              current.action == PlacementAction.revoke),
      listener: _onPlacement,
      child: _sheet(context, l10n),
    );
  }

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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.sheetEdit),
                    ),
                    FilledButton.icon(
                      onPressed: onOpenAssessment,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.sheetOpenAssessment),
                    ),
                  ],
                ),
                BlocBuilder<StudentRecallBloc, StudentRecallState>(
                  builder: (context, recall) => StudentSheetView(
                    sheet: sheet,
                    recall: recall.status == RecallStatus.ready
                        ? StudentRecallCard(advice: recall.advice)
                        : null,
                    onMarkAcquired: (blockId) => _mark(context, sheet, blockId),
                    onRevokeAcquired: (blockId) =>
                        _revoke(context, sheet, blockId),
                  ),
                ),
                EraseStudentCard(
                  studentId: sheet.student.id,
                  studentName: sheet.student.firstName,
                  onErased: onErased,
                ),
              ],
            );
        }
      },
    );
  }
}
