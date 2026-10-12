import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/session_plan_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_picker.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Séance suggérée pour un groupe : élèves attendus, déroulé minuté,
/// exercices (liens vers leur fiche), rappel. [onRecord] ouvre la saisie des
/// résultats de la séance proposée.
class SuggestedSessionPage extends StatelessWidget {
  const SuggestedSessionPage({
    required this.onOpenSource,
    required this.onRecord,
    required this.onAddStudents,
    super.key,
  });

  final ValueChanged<ExerciseRef> onOpenSource;
  final void Function(
    GroupId groupId,
    String mainBlockId,
    String? recallBlockId,
  )
  onRecord;
  final VoidCallback onAddStudents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: BlocBuilder<StudentsBloc, StudentsState>(
            builder: (context, students) {
              final failure = students.failure;
              switch (students.status) {
                case StudentsStatus.loading:
                  return const LoadingView();
                case StudentsStatus.failure:
                  return ErrorView(
                    message: failureMessage(l10n, failure!),
                    onRetry: () => context.read<StudentsBloc>().add(
                      const StudentsEvent.refreshed(),
                    ),
                  );
                case StudentsStatus.ready:
                  final groups = students.club!.eligibleGroups;
                  if (groups.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(title: l10n.suggestTitle),
                        Expanded(
                          child: EmptyState(
                            message: l10n.recordNoGroups,
                            icon: Icons.groups_outlined,
                            action: FilledButton(
                              onPressed: onAddStudents,
                              child: Text(l10n.recordGoStudents),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return BlocBuilder<
                    RosterSelectionCubit,
                    RosterSelectionState
                  >(
                    builder: (context, selectionState) => _content(
                      context,
                      groups,
                      selectionState.resolve(groups)!,
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<GroupOverview> groups,
    RosterSelection selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final roster = context.read<RosterSelectionCubit>();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: l10n.suggestTitle, subtitle: l10n.suggestSubtitle),
          const SizedBox(height: AppSpacing.md),
          RosterPicker(
            groups: groups,
            selectedGroupId: selection.group.group.id,
            present: selection.present,
            studentsLabel: l10n.suggestExpected,
            onGroupSelected: roster.groupSelected,
            onPresenceChanged: roster.presenceChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: selection.present.isEmpty
                ? null
                : () => context.read<SuggestedSessionBloc>().add(
                    SuggestedSessionEvent.requested(
                      groupId: selection.group.group.id,
                      expectedStudents: selection.present,
                    ),
                  ),
            child: Text(l10n.suggestAction),
          ),
          const SizedBox(height: AppSpacing.md),
          BlocBuilder<SuggestedSessionBloc, SuggestedSessionState>(
            builder: (context, state) {
              final failure = state.failure;
              final plan = state.plan;
              switch (state.status) {
                case SuggestedStatus.idle:
                  return const SizedBox.shrink();
                case SuggestedStatus.loading:
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: LoadingView(),
                  );
                case SuggestedStatus.failure:
                  return Text(
                    failureMessage(l10n, failure!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                case SuggestedStatus.ready:
                  return SessionPlanView(
                    plan: plan!,
                    exercises: state.exercises,
                    recall: state.recall,
                    onOpenSource: onOpenSource,
                    onRecord: () => onRecord(
                      state.groupId!,
                      plan.mainBlockId,
                      plan.recallBlockId,
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}
