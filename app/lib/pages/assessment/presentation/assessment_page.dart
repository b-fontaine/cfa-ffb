import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/ui/assessment_form.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/ui/audience_change_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bilan de maturité (aide à la décision) et changement de public manuel.
/// Les trois blocs sont fournis par l'appelant ; la fiche est rechargée après
/// chaque enregistrement ou changement.
class AssessmentPage extends StatelessWidget {
  const AssessmentPage({
    required this.onBack,
    required this.today,
    required this.readinessMinScore,
    super.key,
  });

  final VoidCallback onBack;
  final DateTime today;
  final int readinessMinScore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<AssessmentBloc, AssessmentState>(
          listenWhen: (previous, current) =>
              current.status == AssessmentStatus.saved,
          listener: (context, state) => context.read<StudentSheetBloc>().add(
            const StudentSheetEvent.refreshed(),
          ),
        ),
        BlocListener<AudienceChangeBloc, AudienceChangeState>(
          listenWhen: (previous, current) =>
              current.status == AudienceChangeStatus.changed,
          listener: (context, state) => context.read<StudentSheetBloc>().add(
            const StudentSheetEvent.refreshed(),
          ),
        ),
      ],
      child: BlocBuilder<StudentSheetBloc, StudentSheetState>(
        builder: (context, state) {
          final sheet = state.sheet;
          final failure = state.failure;
          switch (state.status) {
            case StudentSheetStatus.loading:
              return const Scaffold(body: LoadingView());
            case StudentSheetStatus.failure:
              return Scaffold(
                body: ErrorView(message: failureMessage(l10n, failure!)),
              );
            case StudentSheetStatus.ready:
              final latest = sheet!.latestAssessment;
              return ScrollPage(
                title: l10n.assessTitle(sheet.student.firstName),
                subtitle: l10n.assessIntro,
                onBack: onBack,
                backLabel: sheet.student.firstName,
                children: [
                  SectionCard(
                    title: l10n.sheetOpenAssessment,
                    child: AssessmentForm(
                      studentId: sheet.student.id,
                      readinessMinScore: readinessMinScore,
                    ),
                  ),
                  SectionCard(
                    title: l10n.assessCount(sheet.assessmentCount),
                    child: latest == null
                        ? Text(l10n.assessNone)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.assessLatest(
                                  dates.formatMediumDate(latest.date),
                                  latest.concentration,
                                  latest.endurance,
                                  latest.frustration,
                                ),
                              ),
                              if (latest.comment != null)
                                Text(l10n.assessLatestComment(latest.comment!)),
                            ],
                          ),
                  ),
                  AudienceChangeCard(student: sheet.student, today: today),
                ],
              );
          }
        },
      ),
    );
  }
}
