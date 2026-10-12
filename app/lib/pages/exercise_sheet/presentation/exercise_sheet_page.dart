import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/exercise_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fiche source d'un exercice du catalogue (bloc fourni par l'appelant).
class ExerciseSheetPage extends StatelessWidget {
  const ExerciseSheetPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ExerciseSheetBloc, ExerciseSheetState>(
      builder: (context, state) {
        final failure = state.failure;
        switch (state.status) {
          case ExerciseSheetStatus.loading:
            return const Scaffold(body: LoadingView());
          case ExerciseSheetStatus.failure:
            return Scaffold(
              body: ErrorView(message: failureMessage(l10n, failure!)),
            );
          case ExerciseSheetStatus.ready:
            return ScrollPage(
              title: l10n.exerciseSheetTitle,
              onBack: onBack,
              backLabel: l10n.suggestTitle,
              children: [ExerciseSheetView(sheet: state.sheet!)],
            );
        }
      },
    );
  }
}
