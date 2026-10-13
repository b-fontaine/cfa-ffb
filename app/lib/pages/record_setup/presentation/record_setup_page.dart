import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
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

/// La séance ouverte (ou reprise) et le choix qui l'a ouverte : le groupe, la
/// date et les élèves absents, que la séance guidée retient pour ne pas les
/// redemander à chaque exercice.
typedef OpenedRecord = ({
  SessionId id,
  GroupId group,
  DateTime date,
  Set<StudentId> absent,
});

/// Ouverture d'une séance : groupe, date et élèves présents. [onOpened] reçoit
/// la séance ouverte (ou reprise) et le choix qui l'a ouverte. Le groupe, les
/// présents et la date vivent dans [RosterSelectionCubit] et
/// [SessionDateCubit], fournis
/// par le routeur ; [today] borne le choix de la date. [onBackToGuide], quand
/// la saisie vient d'une séance guidée, y ramène sans rien ouvrir.
class RecordSetupPage extends StatelessWidget {
  const RecordSetupPage({
    required this.today,
    required this.onOpened,
    required this.onAddStudents,
    this.mainBlockId,
    this.recallBlockId,
    this.onBackToGuide,
    super.key,
  });

  final DateTime today;
  final ValueChanged<OpenedRecord> onOpened;
  final VoidCallback onAddStudents;
  final String? mainBlockId;
  final String? recallBlockId;
  final VoidCallback? onBackToGuide;

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<SessionDateCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state,
      firstDate: DateTime(2000),
      lastDate: today.add(const Duration(days: 366)),
    );
    if (picked != null) cubit.changed(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    return BlocListener<OpenSessionBloc, OpenSessionState>(
      listenWhen: (previous, current) =>
          current.status == OpenSessionStatus.opened,
      listener: (context, state) {
        final session = state.session!;
        onOpened((
          id: session.id,
          group: session.groupId,
          date: session.date,
          absent: context.read<RosterSelectionCubit>().state.absent,
        ));
      },
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveBody(
            child: BlocBuilder<StudentsBloc, StudentsState>(
              builder: (context, state) {
                final failure = state.failure;
                switch (state.status) {
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
                    return BlocBuilder<
                      RosterSelectionCubit,
                      RosterSelectionState
                    >(
                      builder: (context, selectionState) {
                        final selection = selectionState.resolve(
                          state.club!.eligibleGroups,
                        );
                        if (selection == null) return _empty(l10n);
                        return _form(
                          context,
                          dates,
                          state.club!.eligibleGroups,
                          selection,
                        );
                      },
                    );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeader(title: l10n.recordTitle),
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

  Widget _form(
    BuildContext context,
    MaterialLocalizations dates,
    List<GroupOverview> groups,
    RosterSelection selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final date = context.watch<SessionDateCubit>().state;
    final opening = context.select<OpenSessionBloc, bool>(
      (bloc) => bloc.state.status == OpenSessionStatus.opening,
    );
    final refused = context.select<OpenSessionBloc, Failure?>(
      (bloc) => bloc.state.failure,
    );
    final roster = context.read<RosterSelectionCubit>();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBackToGuide != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onBackToGuide,
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.guideBackToGuide),
              ),
            ),
          PageHeader(title: l10n.recordTitle, subtitle: l10n.recordSubtitle),
          const SizedBox(height: AppSpacing.md),
          RosterPicker(
            groups: groups,
            selectedGroupId: selection.group.group.id,
            present: selection.present,
            onGroupSelected: roster.groupSelected,
            onPresenceChanged: roster.presenceChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.recordDate, style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Expanded(child: Text(dates.formatMediumDate(date))),
              TextButton(
                onPressed: () => _pickDate(context),
                child: Text(l10n.recordChangeDate),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: opening || selection.present.isEmpty
                ? null
                : () => context.read<OpenSessionBloc>().add(
                    OpenSessionEvent.requested(
                      groupId: selection.group.group.id,
                      date: date,
                      present: selection.present,
                      mainBlockId: mainBlockId,
                      recallBlockId: recallBlockId,
                    ),
                  ),
            child: Text(l10n.recordOpen),
          ),
          if (refused != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(l10n, refused),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
