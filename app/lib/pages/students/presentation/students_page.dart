import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/club_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Liste des élèves du club par groupe, avec public et alertes.
class StudentsPage extends StatelessWidget {
  const StudentsPage({
    required this.onOpenStudent,
    required this.onOpenGroup,
    required this.onAddStudent,
    super.key,
  });

  final ValueChanged<StudentId> onOpenStudent;
  final ValueChanged<GroupId> onOpenGroup;
  final VoidCallback onAddStudent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: BlocBuilder<StudentsBloc, StudentsState>(
            builder: (context, state) {
              final club = state.club;
              final failure = state.failure;
              return switch (state.status) {
                StudentsStatus.loading => const LoadingView(),
                StudentsStatus.failure => ErrorView(
                  message: failureMessage(l10n, failure!),
                  onRetry: () => context.read<StudentsBloc>().add(
                    const StudentsEvent.refreshed(),
                  ),
                ),
                StudentsStatus.ready =>
                  club!.groups.isEmpty && club.unassigned.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageHeader(
                              title: l10n.studentsTitle,
                              subtitle: l10n.studentsSubtitle,
                            ),
                            Expanded(
                              child: EmptyState(
                                message: l10n.studentsEmpty,
                                icon: Icons.groups_outlined,
                                action: FilledButton.icon(
                                  onPressed: onAddStudent,
                                  icon: const Icon(Icons.person_add_alt),
                                  label: Text(l10n.studentsAdd),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageHeader(
                                title: l10n.studentsTitle,
                                subtitle: l10n.studentsSubtitle,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FilledButton.icon(
                                  onPressed: onAddStudent,
                                  icon: const Icon(Icons.person_add_alt),
                                  label: Text(l10n.studentsAdd),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ClubList(
                                club: club,
                                onOpenStudent: onOpenStudent,
                                onOpenGroup: onOpenGroup,
                              ),
                            ],
                          ),
                        ),
              };
            },
          ),
        ),
      ),
    );
  }
}
