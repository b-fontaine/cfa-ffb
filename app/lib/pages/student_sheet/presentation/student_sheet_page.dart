import 'package:billard_cfa/features/manage_students/presentation/ui/erase_student_card.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/student_recall_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/student_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fiche d'un élève : progression par bloc, courbes de performance, exercice
/// suivant et notion à rappeler. Les deux blocs sont fournis par l'appelant.
class StudentSheetPage extends StatelessWidget {
  const StudentSheetPage({
    required this.onBack,
    required this.onEdit,
    required this.onOpenAssessment,
    required this.onErased,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onOpenAssessment;

  /// Appelé quand l'élève vient d'être effacé (la fiche n'existe plus).
  final VoidCallback onErased;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
