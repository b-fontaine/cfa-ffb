import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Séance guidée d'une séance du catalogue (cubit fourni par l'appelant, qui
/// le garde au-dessus du routeur : les compteurs survivent à la saisie).
///
/// Callbacks de navigation, composés par la couche `app` : [onBack] revient à
/// la séance du catalogue, [onHome] est proposé quand elle n'existe pas,
/// [onShow] ouvre la présentation à l'étape donnée, [onRecord] ouvre la saisie
/// des résultats de l'exercice (avec le bloc principal de la séance, le bloc
/// du rappel de résultats, celui de l'exercice de rappel quand il diffère ;
/// le guide reste monté : pas d'étape à retrouver), [onFinish] ferme la
/// séance et [onStepChanged] reporte dans l'adresse l'étape que l'animateur
/// vient de choisir. [fromPlanner] dit
/// que le guide a été lancé depuis une séance planifiée : « Retour » mène
/// alors au planificateur, et le libellé le dit.
class SheetGuidePage extends StatelessWidget {
  const SheetGuidePage({
    required this.onBack,
    required this.onHome,
    required this.onShow,
    required this.onRecord,
    required this.onFinish,
    required this.onStepChanged,
    this.fromPlanner = false,
    super.key,
  });

  final bool fromPlanner;

  final VoidCallback onBack;
  final VoidCallback onHome;
  final ValueChanged<int> onShow;
  final void Function(
    ExerciseRef exercise,
    String mainBlockId,
    String? recallBlockId,
  )
  onRecord;
  final VoidCallback onFinish;
  final ValueChanged<int> onStepChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<RunSheetCubit, RunSheetState>(
      builder: (context, state) {
        final plan = state.plan;
        return switch (state.status) {
          RunStatus.loading => const Scaffold(body: LoadingView()),
          RunStatus.notFound => MissingPageView(onHome: onHome),
          RunStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => unawaited(context.read<RunSheetCubit>().load()),
            ),
          ),
          RunStatus.ready => Scaffold(
            body: SafeArea(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          fromPlanner
                              ? l10n.plannerTitle
                              : l10n.sheetFullTitle(
                                  plan!.sheet.title,
                                  plan.sheet.part,
                                  plan.partCount,
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RunSheetView(
                        state: state,
                        onStep: (step) {
                          context.read<RunSheetCubit>().showStep(step);
                          onStepChanged(step);
                        },
                        onShow: () => onShow(state.step),
                        onFinish: () {
                          unawaited(context.read<RunSheetCubit>().finish());
                          onFinish();
                        },
                        onResume: () {
                          context.read<RunSheetCubit>().resume();
                          onStepChanged(state.step);
                        },
                        onRestart: () =>
                            unawaited(context.read<RunSheetCubit>().restart()),
                        onRecord: (exercise) => onRecord(
                          exercise,
                          plan!.sheet.catalogueBlock,
                          exercise.blockId != plan.sheet.catalogueBlock
                              ? exercise.blockId
                              : plan.recallBlockId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}
