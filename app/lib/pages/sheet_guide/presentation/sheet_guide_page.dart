import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Séance guidée d'une séance du catalogue (cubit fourni par l'appelant, qui
/// le garde au-dessus du routeur : les compteurs survivent à la saisie).
///
/// Callbacks de navigation, composés par la couche `app` : [onBack] revient à
/// l'écran d'où le guide a été lancé (Aujourd'hui, Planifiées, Suggestion ou
/// le détail de la séance) sans terminer la séance, [onHome] est proposé quand
/// elle n'existe pas,
/// [onShow] ouvre la présentation à l'étape donnée, [onRecord] ouvre la saisie
/// des résultats de l'exercice (avec le bloc principal de la séance, le bloc
/// du rappel de résultats, celui de l'exercice de rappel quand il diffère ;
/// le guide reste monté : pas d'étape à retrouver), [onFinish] ferme la
/// séance (avec l'identifiant de la saisie ouverte depuis ce guide, s'il y en
/// a une : le routeur mène alors au bilan) et [onStepChanged] reporte dans
/// l'adresse l'étape (et le mode) que l'animateur vient de choisir.
///
/// L'écran est de premier niveau (ni rail ni barre de navigation) : son
/// en-tête compact porte la flèche de retour.
class SheetGuidePage extends StatelessWidget {
  const SheetGuidePage({
    required this.onBack,
    required this.onHome,
    required this.onShow,
    required this.onRecord,
    required this.onFinish,
    required this.onStepChanged,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onHome;
  final ValueChanged<int> onShow;
  final void Function(
    ExerciseRef exercise,
    String mainBlockId,
    String? recallBlockId,
  )
  onRecord;
  final ValueChanged<SessionId?> onFinish;
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
            // Pas de `ResponsiveBody` : l'en-tête compact va jusqu'au bord ;
            // la vue pose elle-même ses marges.
            body: SafeArea(
              top: false,
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: RunSheetView(
                    state: state,
                    onBack: onBack,
                    onStep: (step) {
                      context.read<RunSheetCubit>().showStep(step);
                      onStepChanged(step);
                    },
                    onModeChanged: (mode) {
                      final cubit = context.read<RunSheetCubit>()
                        ..modeChanged(mode);
                      // Le mode fait partie de l'adresse (lien, reprise).
                      onStepChanged(cubit.state.step);
                    },
                    onShow: () => onShow(state.step),
                    onFinish: () {
                      final cubit = context.read<RunSheetCubit>();
                      // Lue avant `finish()`, qui remet l'état à zéro :
                      // mène au bilan quand une saisie a été ouverte.
                      final record = cubit.state.recordChoice?.recordId;
                      unawaited(cubit.finish());
                      onFinish(record);
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
              ),
            ),
          ),
        };
      },
    );
  }
}
