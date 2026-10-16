import 'dart:async';
import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_step_titles.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/timer_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'run_bottom_bar.dart';
part 'run_guide_header.dart';
part 'run_outline.dart';
part 'run_session_info.dart';
part 'run_step_views.dart';

/// Largeur à partir de laquelle une étape passe sur deux colonnes (tablette
/// en paysage) : schéma à gauche, texte à droite.
const double _wideStepWidth = 720;

/// Largeur sous laquelle la barre basse passe en version téléphone (flèches de
/// part et d'autre de « Noter les résultats »).
const double _compactWidth = 600;

/// Hauteur (à texte normal) à partir de laquelle la frise des phases est
/// épinglée hors du défilement ; elle est multipliée par le facteur de texte.
const double _pinnedMinHeight = 600;

/// Hauteur fixe de l'écran hors schéma : en-tête compact (48), barre basse
/// (72) et marges (16) ; s'y ajoutent trois rangées qui grandissent avec le
/// texte (frise, ligne de phase, bouton « Montrer »).
const double _chromeHeight = 48 + 72 + 16;
const double _chromeRowHeight = 56;

/// Facteur de texte à partir duquel la barre basse empile ses boutons.
const double _largeTextScale = 1.3;

/// Ce que les éléments d'une étape doivent savoir du guide : son mode
/// (« Mener » ou « Relecture ») et l'action « Montrer » de l'étape courante,
/// absente quand l'étape n'a rien à montrer.
class _GuideScope extends InheritedWidget {
  const _GuideScope({
    required this.mode,
    required this.onShow,
    required this.mediaMaxHeight,
    required super.child,
  });

  final RunMode mode;
  final VoidCallback? onShow;

  /// Hauteur que le schéma et ses commandes ne dépassent pas pour rester
  /// visibles sans défiler ; `null` quand l'écran est trop bas pour l'épingler
  /// (le contenu défile alors).
  final double? mediaMaxHeight;

  static _GuideScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GuideScope>()!;

  @override
  bool updateShouldNotify(_GuideScope oldWidget) =>
      mode != oldWidget.mode ||
      (onShow == null) != (oldWidget.onShow == null) ||
      mediaMaxHeight != oldWidget.mediaMaxHeight;
}

/// La séance guidée : un en-tête compact (retour, titre de l'étape, position,
/// menu, frise des phases, phase et minuteur), l'étape courante (schéma en
/// premier) et une barre basse « Précédent / Noter les résultats / Suivant ».
///
/// [state] est un état prêt (déroulé chargé). Les compteurs, le score et le
/// minuteur passent par le [RunSheetCubit] du contexte ; [onStep] demande une
/// étape (précédent, suivant, sommaire, frise : l'appelant la montre et la
/// reporte dans l'adresse), [onShow] ouvre la présentation, [onFinish] termine
/// la séance (après confirmation, par le menu ou par la dernière étape),
/// [onRecord] ouvre la saisie des résultats de l'exercice courant, [onBack]
/// quitte le guide sans le terminer, [onModeChanged] bascule entre « Mener » et
/// « Relecture » (l'appelant l'applique au cubit et le reporte dans l'adresse),
/// [onResume] et [onRestart] répondent à la proposition de reprise d'une
/// séance déjà commencée.
///
/// À placer dans un parent à hauteur bornée : le contenu défile, l'en-tête et
/// la barre basse restent en place.
class RunSheetView extends StatelessWidget {
  const RunSheetView({
    required this.state,
    required this.onStep,
    required this.onShow,
    required this.onFinish,
    required this.onRecord,
    required this.onBack,
    required this.onModeChanged,
    this.onResume,
    this.onRestart,
    super.key,
  });

  final RunSheetState state;
  final ValueChanged<int> onStep;
  final VoidCallback onShow;
  final VoidCallback onFinish;
  final ValueChanged<ExerciseRef> onRecord;
  final VoidCallback onBack;
  final ValueChanged<RunMode> onModeChanged;
  final VoidCallback? onResume;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    final step = plan.steps[state.step];
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RunSheetCubit>();
    final mode = state.mode;
    final specs = {
      for (final entry in plan.diagrams.entries)
        entry.key: tableDiagramSpecOf(entry.value),
    };
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final exercise =
        step.kind == RunStepKind.exercise ||
            step.kind == RunStepKind.recallExercise
        ? plan.exerciseOf(step)
        : null;
    return _TimerGuard(
      child: _TimerHaptics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Frise épinglée si la hauteur le permet ; en très grand texte
            // ou sur un écran bas, elle défile avec le contenu plutôt que
            // de le manger.
            final pinned =
                constraints.maxHeight >= _pinnedMinHeight * textScale;
            // Ce qui reste pour le schéma entre l'en-tête et la barre basse
            // (frise, ligne de phase, bouton « Montrer » et marges
            // comptés) : il se montre en entier sans défiler.
            final scale = math.max(1, textScale);
            final mediaMaxHeight = pinned
                ? constraints.maxHeight -
                      (_chromeHeight + 3 * _chromeRowHeight * scale)
                : null;
            final timeline = _Timeline(
              plan: plan,
              step: state.step,
              onStep: onStep,
            );
            final resume = state.resumeOffered
                ? _ResumeOffer(
                    step: state.step + 1,
                    total: plan.stepCount,
                    onResume: onResume,
                    onRestart: onRestart,
                  )
                : null;
            return _GuideScope(
              mode: mode,
              onShow: plan.isPresentable(step) ? onShow : null,
              mediaMaxHeight: mediaMaxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    key: const ValueKey('guide-header'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StepAppBar(
                        title: runStepTitle(l10n, plan, step),
                        position: state.step + 1,
                        total: plan.stepCount,
                        onBack: onBack,
                        actions: [
                          StepAppBarAction(
                            label: l10n.guideOutline,
                            icon: Icons.list_alt_outlined,
                            onSelected: () => unawaited(
                              _showOutline(context, plan, state.step, onStep),
                            ),
                          ),
                          StepAppBarAction(
                            label: l10n.guideModeReview,
                            checked: mode == RunMode.review,
                            onSelected: () => onModeChanged(
                              mode == RunMode.review
                                  ? RunMode.lead
                                  : RunMode.review,
                            ),
                          ),
                          StepAppBarAction(
                            label: l10n.guideSessionInfo,
                            icon: Icons.info_outline,
                            onSelected: () => unawaited(
                              _showSessionInfo(context, plan, step),
                            ),
                          ),
                          StepAppBarAction(
                            label: l10n.guideTimerReset,
                            icon: Icons.restart_alt,
                            enabled: state.timerSeconds > 0,
                            onSelected: cubit.timerReset,
                          ),
                          StepAppBarAction(
                            label: l10n.guideFinish,
                            icon: Icons.stop_circle_outlined,
                            onSelected: () =>
                                unawaited(_confirmFinish(context, onFinish)),
                          ),
                        ],
                      ),
                      if (pinned) timeline,
                      _PhaseTimerRow(plan: plan, state: state),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!pinned) timeline,
                          ?resume,
                          const SizedBox(height: AppSpacing.sm),
                          _StepContent(
                            plan: plan,
                            step: step,
                            state: state,
                            specs: specs,
                          ),
                          if (mode.showsProvenance) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _ThemeTile(sheet: plan.sheet),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    ),
                  ),
                  _BottomBar(
                    step: state.step,
                    stepCount: plan.stepCount,
                    onStep: onStep,
                    onRecord: exercise == null
                        ? null
                        : () => onRecord(exercise.ref),
                    onFinish: () =>
                        unawaited(_confirmFinish(context, onFinish)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Demande confirmation avant de terminer la séance guidée ; rien n'est écrit,
/// annuler ne change rien.
Future<void> _confirmFinish(BuildContext context, VoidCallback onFinish) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.guideFinishTitle,
    message: l10n.guideFinishBody,
  );
  if (confirmed) onFinish();
}

/// Arrête le minuteur quand le guide quitte l'écran : il est indicatif, il ne
/// doit pas tourner dans le vide (saisie des résultats, menu).
class _TimerGuard extends StatefulWidget {
  const _TimerGuard({required this.child});

  final Widget child;

  @override
  State<_TimerGuard> createState() => _TimerGuardState();
}

class _TimerGuardState extends State<_TimerGuard> {
  late final RunSheetCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<RunSheetCubit>();
  }

  @override
  void dispose() {
    unawaited(_cubit.timerPaused());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Vibre une fois quand le minuteur passe à « attention » (moins d'une
/// minute) puis une fois au dépassement : pas à chaque seconde. Sans effet
/// sur un appareil qui ne vibre pas (web, ordinateur).
class _TimerHaptics extends StatelessWidget {
  const _TimerHaptics({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<RunSheetCubit, RunSheetState>(
        listenWhen: (previous, current) =>
            previous.timerTone != current.timerTone &&
            (current.timerTone == TimerTone.attention ||
                current.timerTone == TimerTone.overdue),
        listener: (context, state) => unawaited(HapticFeedback.mediumImpact()),
        child: child,
      );
}

/// Proposition de reprise : la séance a déjà de la progression.
class _ResumeOffer extends StatelessWidget {
  const _ResumeOffer({
    required this.step,
    required this.total,
    required this.onResume,
    required this.onRestart,
  });

  final int step;
  final int total;
  final VoidCallback? onResume;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('resume-offer'),
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.guideResumeOffer(step, total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(l10n.guideResume(step)),
                ),
                OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.guideRestart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thème ludique et notion de la séance, repliables : le thème `[Prop]` est
/// jugeable en contexte sans quitter le guide (mode « Relecture »).
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.sheet});

  final SessionSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      semanticContainer: false,
      child: ExpansionTile(
        key: const ValueKey('theme-tile'),
        title: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.sheetTheme(sheet.theme.name),
              style: theme.textTheme.titleMedium,
            ),
            const _Source(element: 'theme', provenance: Provenance.prop),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sheet.theme.pitch, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.sheetNotion(sheet.notion),
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
