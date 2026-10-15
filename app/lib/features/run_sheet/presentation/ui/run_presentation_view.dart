import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_step_titles.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hauteur des boutons précédent/suivant : larges, pour une tablette posée
/// devant les élèves.
const double _bigTarget = 56;

/// Hauteur (px) sous laquelle le schéma n'est plus borné : la page défile.
const double _minFigureHeight = 160;

/// Hauteur (px) réservée au badge « Proposition » sous la figure.
const double _badgeHeight = 48;

/// Facteur d'agrandissement du texte de `PresentationScope` (sa valeur par
/// défaut) : la légende est écrite avec.
const double _presentationScale = 1.5;

/// Vitesse (px/s) au-delà de laquelle un balayage change d'illustration.
const double _swipeVelocity = 300;

/// Mode présentation : l'illustration de l'étape, agrandie, pour les élèves.
///
/// Aucune note d'animateur, aucune règle, aucune notation : la légende de
/// l'illustration et, quand son élément est une proposition `[Prop]`, le badge
/// « Proposition » (discret mais visible). Les règles du jeu et les minutes
/// se jugent dans le guide. [onPrevious] et [onNext] parcourent les étapes qui
/// ont quelque chose à montrer ; [onClose] revient à la séance guidée.
class RunPresentationView extends StatelessWidget {
  const RunPresentationView({
    required this.plan,
    required this.step,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    super.key,
  });

  final RunPlan plan;
  final int step;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  bool _hasPresentable(int from, int direction) {
    var index = from + direction;
    while (index >= 0 && index < plan.stepCount) {
      if (plan.isPresentable(plan.steps[index])) return true;
      index += direction;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = plan.steps[step];
    final title = runStepTitle(l10n, plan, current);
    final specs = {
      for (final entry in plan.diagrams.entries)
        entry.key: tableDiagramSpecOf(entry.value),
    };
    final presentable = plan.presentableSteps;
    final position = presentable.indexOf(step) + 1;
    final hasPrevious = _hasPresentable(step, -1);
    final hasNext = _hasPresentable(step, 1);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (hasPrevious) onPrevious();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (hasNext) onNext();
        },
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Un balayage change d'illustration : vers la gauche, la suivante.
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -_swipeVelocity && hasNext) onNext();
            if (velocity > _swipeVelocity && hasPrevious) onPrevious();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (position > 0)
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.presentationPosition(
                            position,
                            presentable.length,
                          ),
                          key: const ValueKey('presentation-position'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    label: Text(l10n.presentationClose),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.presentationTitle(title),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _content(
                          context,
                          l10n,
                          current,
                          specs,
                          figureHeight: _figureHeight(
                            context,
                            constraints,
                            l10n.presentationTitle(title),
                            current,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: l10n.presentationPrevious,
                      child: FilledButton.tonalIcon(
                        onPressed: hasPrevious ? onPrevious : null,
                        icon: const Icon(Icons.chevron_left),
                        label: Text(l10n.presentationPreviousLabel),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(_bigTarget),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Tooltip(
                      message: l10n.presentationNext,
                      child: FilledButton.tonalIcon(
                        onPressed: hasNext ? onNext : null,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(l10n.presentationNextLabel),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(_bigTarget),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hauteur (px) de [text] écrit en [style] sur [width] px, texte agrandi.
  static double _textHeight(
    BuildContext context,
    String text,
    TextStyle? style,
    double width, {
    double scale = 1,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(scaler.scale(1) * scale),
    )..layout(maxWidth: math.max(0, width));
    return painter.height;
  }

  /// Hauteur maximale du schéma et de ses commandes pour qu'ils tiennent avec
  /// leur légende dans la hauteur disponible [constraints], au-dessus de la
  /// barre précédent/suivant ; `null` (hauteur naturelle, la page défile)
  /// quand il n'y a pas un seul schéma de table à légender.
  double? _figureHeight(
    BuildContext context,
    BoxConstraints constraints,
    String title,
    RunStep current,
  ) {
    if (!constraints.hasBoundedHeight) return null;
    final String caption;
    final exercise = plan.exerciseOf(current);
    final diagram = exercise == null ? null : plan.diagrams[exercise.diagramId];
    if (current.isExerciseLike && exercise != null && diagram != null) {
      caption = diagram.caption;
    } else {
      final illustrations = plan.presentableIllustrationsOf(current);
      if (illustrations.length != 1) return null;
      final single = illustrations.single;
      // Seuls les schémas de table savent se réduire à la hauteur donnée.
      if (single is! DiagramRefIllustration && single is! TableIllustration) {
        return null;
      }
      caption = single.caption;
    }
    final theme = Theme.of(context);
    final reserved =
        _textHeight(
          context,
          title,
          theme.textTheme.titleLarge,
          constraints.maxWidth,
        ) +
        AppSpacing.sm +
        2 * AppSpacing.lg +
        AppSpacing.md +
        _textHeight(
          context,
          caption,
          theme.textTheme.headlineSmall,
          constraints.maxWidth - 2 * AppSpacing.lg,
          scale: _presentationScale,
        ) +
        (plan.isProposal(current) ? _badgeHeight : 0);
    final available = constraints.maxHeight - reserved;
    // Trop peu de place : hauteur naturelle, la page défile.
    return available >= _minFigureHeight ? available : null;
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    RunStep current,
    Map<String, ui.TableDiagramSpec> specs, {
    double? figureHeight,
  }) {
    final proposal = plan.isProposal(current);
    if (current.isExerciseLike) {
      final exercise = plan.exerciseOf(current);
      final diagram = exercise == null
          ? null
          : plan.diagrams[exercise.diagramId];
      if (exercise != null && diagram != null) {
        return PresentationScope(
          caption: diagram.caption,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: SheetIllustrationView.presentationMaxWidth,
                ),
                child: TableDiagramPlayer(
                  maxHeight: figureHeight,
                  spec: tableDiagramSpecOf(diagram),
                  semanticLabel: l10n.exerciseDiagramSemantics(
                    exercise.ref.number,
                    plan.blockTitle ?? plan.sheet.title,
                  ),
                ),
              ),
              if (proposal) ...[
                const SizedBox(height: AppSpacing.sm),
                const ProposalBadge(),
              ],
            ],
          ),
        );
      }
    }
    final illustrations = plan.presentableIllustrationsOf(current);
    if (illustrations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.presentationNothing,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final illustration in illustrations)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PresentationScope(
              caption: illustration.caption,
              child: SheetIllustrationView(
                illustration: illustration,
                diagrams: specs,
                proposal: proposal,
                showCaption: false,
                presentationHeight: figureHeight,
              ),
            ),
          ),
      ],
    );
  }
}
