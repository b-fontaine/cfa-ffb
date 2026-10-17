import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
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
/// l'adresse l'étape (et le mode) que l'animateur vient de choisir, [onExport]
/// ouvre l'export PDF de la séance.
///
/// Le plein écran (menu ⋮) vient d'un `FullscreenCubit` fourni par l'appelant.
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
    required this.onExport,
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

  /// Ouvre l'export PDF de la séance (menu ⋮).
  final VoidCallback onExport;

  /// Termine la séance (les étiquettes passent à la saisie) **puis** ouvre
  /// le bilan : il relit la saisie, qui doit déjà les porter. Si elles n'ont
  /// pas pu être données, la séance reste ouverte sur son étape « Bilan ».
  Future<void> _end(RunSheetCubit cubit, SessionId? record) async {
    if (await cubit.endSession()) onFinish(record);
  }

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
                    fullscreen: context.watch<FullscreenCubit>().state,
                    onToggleFullscreen: () =>
                        unawaited(context.read<FullscreenCubit>().toggle()),
                    onBack: onBack,
                    onExport: onExport,
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
                      // Lue avant `endSession()`, qui remet l'état à zéro :
                      // mène au bilan quand une saisie a été ouverte.
                      final record = cubit.state.recordChoice?.recordId;
                      unawaited(_end(cubit, record));
                    },
                    onResume: () {
                      context.read<RunSheetCubit>().resume();
                      onStepChanged(state.step);
                    },
                    onRestart: () =>
                        unawaited(context.read<RunSheetCubit>().restart()),
                    onRecord: (exercise) {
                      final blocks = plan!.recordBlocksFor(exercise);
                      onRecord(exercise, blocks.main, blocks.recall);
                    },
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
