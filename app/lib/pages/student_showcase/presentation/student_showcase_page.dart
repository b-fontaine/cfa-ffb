import 'package:billard_cfa/features/student_showcase/presentation/bloc/showcase_cubit.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/showcase_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La vue « à montrer à l'élève » : le prénom et le parcours, sans barre de
/// navigation (la route est hors du cadre de navigation) ni chemin vers les
/// autres élèves. « Terminer » et le retour système reviennent à la fiche
/// ([onDone]) ; aucun état « montré » n'est conservé.
class StudentShowcasePage extends StatelessWidget {
  const StudentShowcasePage({
    required this.studentId,
    required this.onDone,
    super.key,
  });

  final StudentId studentId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveBody(
            child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
              builder: (context, state) => switch (state.status) {
                ShowcaseStatus.loading => const LoadingView(),
                ShowcaseStatus.failure => ErrorView(
                  message: failureMessage(l10n, state.failure!),
                  onRetry: () => context.read<ShowcaseCubit>().load(studentId),
                ),
                ShowcaseStatus.ready => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          onPressed: onDone,
                          icon: const Icon(Icons.check),
                          label: Text(l10n.showcaseDone),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ShowcaseView(showcase: state.showcase!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
