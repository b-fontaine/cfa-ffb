import 'package:billard_cfa/features/student_showcase/presentation/bloc/linked_students_cubit.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/linked_students_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Accueil d'un parent (« Mes enfants ») ou d'un élève (« Ma progression ») :
/// les élèves liés au compte, chacun menant à sa fiche en parcours. Le cubit
/// est fourni par l'appelant.
class MyChildrenPage extends StatelessWidget {
  const MyChildrenPage({
    required this.studentOwnAccount,
    required this.onShow,
    super.key,
  });

  /// Vrai pour un élève (titre « Ma progression »), faux pour un parent.
  final bool studentOwnAccount;
  final ValueChanged<StudentId> onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: studentOwnAccount
          ? l10n.childrenTitleStudent
          : l10n.childrenTitleGuardian,
      children: [
        BlocBuilder<LinkedStudentsCubit, LinkedStudentsState>(
          builder: (context, state) => switch (state.status) {
            LinkedStudentsStatus.loading => const LoadingView(),
            LinkedStudentsStatus.failed => ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: context.read<LinkedStudentsCubit>().load,
            ),
            LinkedStudentsStatus.ready => LinkedStudentsList(
              students: state.students,
              onShow: onShow,
            ),
          },
        ),
      ],
    );
  }
}
