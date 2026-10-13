import 'dart:async';

import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_step_titles.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'run_outline.dart';
part 'run_step_views.dart';
part 'run_timer_bar.dart';

/// Largeur à partir de laquelle une étape passe sur deux colonnes (tablette
/// en paysage) : texte à gauche, schéma à droite.
const double _wideStepWidth = 720;

/// Hauteur (à texte normal) à partir de laquelle la barre d'actions est
/// épinglée hors du défilement ; elle est multipliée par le facteur de texte.
const double _pinnedMinHeight = 600;

/// La séance guidée : où on en est, l'étape courante (théorie, exercice,
/// jeu…) avec ses badges « Proposition » en contexte, le minuteur indicatif
/// et la navigation libre entre les étapes.
///
/// [state] est un état prêt (déroulé chargé). Les compteurs, le score et le
/// minuteur passent par le [RunSheetCubit] du contexte ; [onStep] demande une
/// étape (précédent, suivant, sommaire : l'appelant la montre et la reporte
/// dans l'adresse), [onShow] ouvre la présentation, [onFinish] termine la
/// séance (après confirmation), [onRecord] ouvre la saisie des résultats de
/// l'exercice courant, [onResume] et [onRestart] répondent à la proposition de
/// reprise d'une séance déjà commencée.
///
/// La barre d'actions (sommaire, montrer, minuteur, terminer) est épinglée
/// hors du défilement : sur une étape longue, le schéma se montre et le
/// minuteur se lance sans remonter. À placer dans un parent à hauteur
/// bornée : le contenu défile et la navigation reste en bas.
class RunSheetView extends StatelessWidget {
  const RunSheetView({
    required this.state,
    required this.onStep,
    required this.onShow,
    required this.onFinish,
    required this.onRecord,
    this.onResume,
    this.onRestart,
    super.key,
  });

  final RunSheetState state;
  final ValueChanged<int> onStep;
  final VoidCallback onShow;
  final VoidCallback onFinish;
  final ValueChanged<ExerciseRef> onRecord;
  final VoidCallback? onResume;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    final step = plan.steps[state.step];
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final specs = {
      for (final entry in plan.diagrams.entries)
        entry.key: tableDiagramSpecOf(entry.value),
    };
    final isLast = state.step == plan.stepCount - 1;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return _TimerGuard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Épinglée si la hauteur le permet ; en très grand texte ou sur
          // un écran bas, la barre défile avec le contenu plutôt que de
          // le manger.
          final pinned = constraints.maxHeight >= _pinnedMinHeight * textScale;
          final resume = state.resumeOffered
              ? _ResumeOffer(
                  step: state.step + 1,
                  total: plan.stepCount,
                  onResume: onResume,
                  onRestart: onRestart,
                )
              : null;
          final bar = _ActionBar(
            plan: plan,
            state: state,
            onStep: onStep,
            onShow: onShow,
            onFinish: onFinish,
            presentable: plan.isPresentable(step),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pinned) ...[
                ?resume,
                bar,
                const SizedBox(height: AppSpacing.sm),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!pinned) ...[
                        ?resume,
                        bar,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.sheetFullTitle(
                            plan.sheet.title,
                            plan.sheet.part,
                            plan.partCount,
                          ),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.sheetAudienceOption(
                          plan.audience.label(l10n),
                          plan.audience.sessionDuration.inMinutes,
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ThemeTile(sheet: plan.sheet),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.guideStepCounter(state.step + 1, plan.stepCount),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value: (state.step + 1) / plan.stepCount,
                        semanticsLabel: l10n.guideStepCounter(
                          state.step + 1,
                          plan.stepCount,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PhaseLine(plan: plan, step: step),
                      const SizedBox(height: AppSpacing.md),
                      _StepContent(
                        plan: plan,
                        step: step,
                        state: state,
                        specs: specs,
                        onRecord: onRecord,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.step == 0
                          ? null
                          : () => onStep(state.step - 1),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.guidePrevious),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isLast ? null : () => onStep(state.step + 1),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.guideNext),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
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

/// Barre épinglée : sommaire, montrer, terminer, puis le minuteur.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.plan,
    required this.state,
    required this.onStep,
    required this.onShow,
    required this.onFinish,
    required this.presentable,
  });

  final RunPlan plan;
  final RunSheetState state;
  final ValueChanged<int> onStep;
  final VoidCallback onShow;
  final VoidCallback onFinish;

  /// Vrai quand l'étape courante a quelque chose à montrer aux élèves.
  final bool presentable;

  Future<void> _confirmFinish(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.guideFinishTitle,
      message: l10n.guideFinishBody,
    );
    if (confirmed) onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showOutline(context, plan, state.step, onStep),
              icon: const Icon(Icons.list_alt_outlined),
              label: Text(l10n.guideOutline),
            ),
            OutlinedButton.icon(
              onPressed: presentable ? onShow : null,
              icon: const Icon(Icons.slideshow_outlined),
              label: Text(l10n.guideShow),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_confirmFinish(context)),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.guideFinish),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _TimerBar(plan: plan, state: state),
      ],
    );
  }
}

/// Thème ludique et notion de la séance, repliables : le thème `[Prop]` est
/// jugeable en contexte sans quitter le guide.
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
