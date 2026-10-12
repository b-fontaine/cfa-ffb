import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/student_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ajout ou édition d'un élève. [onSaved] reçoit l'élève enregistré ;
/// [onBack] ramène à l'écran précédent.
class StudentFormPage extends StatelessWidget {
  const StudentFormPage({
    required this.onSaved,
    required this.onBack,
    super.key,
  });

  final ValueChanged<Student> onSaved;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<StudentFormBloc, StudentFormState>(
      listenWhen: (previous, current) =>
          current.status == StudentFormStatus.saved &&
          previous.status != StudentFormStatus.saved,
      listener: (context, state) => onSaved(state.saved!),
      builder: (context, state) {
        final failure = state.failure;
        if (state.status == StudentFormStatus.loading) {
          return const Scaffold(body: LoadingView());
        }
        if (state.status == StudentFormStatus.failure) {
          return Scaffold(
            body: ErrorView(message: failureMessage(l10n, failure!)),
          );
        }
        return ScrollPage(
          title: state.student == null
              ? l10n.studentFormNewTitle
              : l10n.studentFormEditTitle,
          onBack: onBack,
          backLabel: l10n.commonCancel,
          children: const [StudentForm()],
        );
      },
    );
  }
}
