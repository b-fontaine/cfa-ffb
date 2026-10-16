import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_step_titles.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/diagram_stage.dart';
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

/// Hauteur minimale (dp) du schéma de table lui-même : assez pour que la
/// table et son médaillon (écrit sous elle quand elle est étroite) tiennent
/// sans que le schéma reprenne sa hauteur naturelle et déborde.
const double _minTableFigure = 240;

/// Hauteur minimale (dp) de la zone d'un schéma de table : le schéma, l'écart
/// et la rangée de commandes du lecteur (lecture, rejouer, vitesse).
const double _minPlayerZone =
    _minTableFigure + AppSpacing.md + AppSpacing.minTouchTarget;

/// Largeur (dp) sous laquelle « Plein écran » se réduit à son icône.
const double _narrowHeader = 560;

/// Clé de la barre précédent/suivant, la même pour la scène et la colonne.
const Key _bottomBarKey = ValueKey('presentation-bottom-bar');

/// Vitesse (px/s) au-delà de laquelle un balayage change d'illustration.
const double _swipeVelocity = 300;

/// Mode présentation : l'illustration de l'étape, agrandie, pour les élèves.
///
/// Aucune note d'animateur, aucune règle, aucune notation : la légende de
/// l'illustration et, quand son élément est une proposition `[Prop]`, le badge
/// « Proposition » (discret mais visible). Les règles du jeu et les minutes
/// se jugent dans le guide. [onPrevious] et [onNext] parcourent les étapes qui
/// ont quelque chose à montrer ; [onClose] revient à la séance guidée.
///
/// Une étape qui montre un seul schéma de table est posée sur une
/// [DiagramStage] (légende réservée, schéma sur le reste) ; les autres
/// gardent la colonne défilante. Le motif de tapis passe derrière tout.
/// [fullscreen] et [onToggleFullscreen] portent le bouton « Plein écran »
/// et la touche F, masqués quand le plein écran n'est pas pris en charge.
class RunPresentationView extends StatelessWidget {
  const RunPresentationView({
    required this.plan,
    required this.step,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    this.fullscreen,
    this.onToggleFullscreen,
    super.key,
  });

  final RunPlan plan;
  final int step;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  /// État du plein écran ; absent, l'entrée est masquée.
  final FullscreenState? fullscreen;
  final VoidCallback? onToggleFullscreen;

  bool _hasPresentable(int from, int direction) {
    var index = from + direction;
    while (index >= 0 && index < plan.stepCount) {
      if (plan.isPresentable(plan.steps[index])) return true;
      index += direction;
    }
    return false;
  }

  bool get _canToggleFullscreen =>
      (fullscreen?.supported ?? false) && onToggleFullscreen != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = plan.steps[step];
    final title = l10n.presentationTitle(runStepTitle(l10n, plan, current));
    final hasPrevious = _hasPresentable(step, -1);
    final hasNext = _hasPresentable(step, 1);
    final toggle = onToggleFullscreen;
    final stage = _stageOf(context, l10n, current);
    final header = _header(context, l10n);
    final previous = _navButton(
      tooltip: l10n.presentationPrevious,
      icon: Icons.chevron_left,
      label: l10n.presentationPreviousLabel,
      onPressed: hasPrevious ? onPrevious : null,
    );
    final next = _navButton(
      tooltip: l10n.presentationNext,
      icon: Icons.chevron_right,
      label: l10n.presentationNextLabel,
      onPressed: hasNext ? onNext : null,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (hasPrevious) onPrevious();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (hasNext) onNext();
        },
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
        if (_canToggleFullscreen && toggle != null)
          const SingleActivator(LogicalKeyboardKey.keyF): toggle,
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
          child: Stack(
            children: [
              const Positioned.fill(
                child: ClothPattern(key: ValueKey('presentation-cloth')),
              ),
              if (stage != null)
                // Une scène par étape : l'indication de rotation fermée
                // revient à l'étape suivante.
                DiagramStage(
                  key: ValueKey(step),
                  title: title,
                  header: header,
                  figureAspect: BilliardTable.aspect,
                  minFigureHeight: _minPlayerZone,
                  bottomBarKey: _bottomBarKey,
                  figure: stage.figure,
                  caption: stage.caption,
                  badge: plan.isProposal(current)
                      ? const ProposalBadge()
                      : null,
                  previous: previous,
                  next: next,
                )
              else
                _column(context, l10n, current, title, header, previous, next),
            ],
          ),
        ),
      ),
    );
  }

  /// Ligne du haut : position à gauche, plein écran et fermer à droite. Sous
  /// [_narrowHeader] de large, « Plein écran » se réduit à son icône.
  Widget _header(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final presentable = plan.presentableSteps;
    final position = presentable.indexOf(step) + 1;
    final active = fullscreen?.active ?? false;
    final fullscreenLabel = active
        ? l10n.presentationFullscreenExit
        : l10n.presentationFullscreen;
    final scheme = theme.colorScheme;
    // Actif : bleu-tapis plein (état, ADR 0010), au lieu de la teinte douce.
    final activeStyle = active
        ? IconButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          )
        : null;
    final fullscreenIcon = Icon(
      active ? Icons.fullscreen_exit : Icons.fullscreen,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _narrowHeader;
        return Row(
          children: [
            if (position > 0)
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.presentationPosition(position, presentable.length),
                    key: const ValueKey('presentation-position'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              )
            else
              const Spacer(),
            if (_canToggleFullscreen) ...[
              if (narrow)
                IconButton.filledTonal(
                  tooltip: fullscreenLabel,
                  onPressed: onToggleFullscreen,
                  icon: fullscreenIcon,
                  style: activeStyle,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onToggleFullscreen,
                  icon: fullscreenIcon,
                  label: Text(fullscreenLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minTouchTarget),
                    backgroundColor: active ? scheme.primary : null,
                    foregroundColor: active ? scheme.onPrimary : null,
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
            FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              label: Text(l10n.presentationClose),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _navButton({
    required String tooltip,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(_bigTarget),
      ),
    ),
  );

  /// La figure et la légende d'une étape qui montre **un seul schéma de
  /// table**, ou `null` (colonne défilante).
  ({Widget Function(BuildContext, Size) figure, String caption})? _stageOf(
    BuildContext context,
    AppLocalizations l10n,
    RunStep current,
  ) {
    final exercise = plan.exerciseOf(current);
    final diagram = exercise == null ? null : plan.diagrams[exercise.diagramId];
    if (current.isExerciseLike && exercise != null && diagram != null) {
      return (
        caption: diagram.caption,
        figure: (context, zone) => ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: SheetIllustrationView.presentationMaxWidth,
          ),
          child: TableDiagramPlayer(
            maxHeight: zone.height,
            spec: tableDiagramSpecOf(diagram),
            semanticLabel: l10n.exerciseDiagramSemantics(
              exercise.ref.number,
              plan.blockTitle ?? plan.sheet.title,
            ),
          ),
        ),
      );
    }
    final illustrations = plan.presentableIllustrationsOf(current);
    if (illustrations.length != 1) return null;
    final single = illustrations.single;
    // Seuls les schémas de table savent se réduire à la hauteur donnée.
    if (single is! DiagramRefIllustration && single is! TableIllustration) {
      return null;
    }
    final specs = {
      for (final entry in plan.diagrams.entries)
        entry.key: tableDiagramSpecOf(entry.value),
    };
    return (
      caption: single.caption,
      figure: (context, zone) => SheetIllustrationView(
        illustration: single,
        diagrams: specs,
        showCaption: false,
        presentationHeight: zone.height,
      ),
    );
  }

  /// Les étapes sans schéma de table unique : colonne défilante.
  Widget _column(
    BuildContext context,
    AppLocalizations l10n,
    RunStep current,
    String title,
    Widget header,
    Widget previous,
    Widget next,
  ) {
    final theme = Theme.of(context);
    final specs = {
      for (final entry in plan.diagrams.entries)
        entry.key: tableDiagramSpecOf(entry.value),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: AppSpacing.sm),
                _content(context, l10n, current, specs),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          key: _bottomBarKey,
          children: [
            Expanded(child: previous),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: next),
          ],
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    RunStep current,
    Map<String, ui.TableDiagramSpec> specs,
  ) {
    final proposal = plan.isProposal(current);
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
              transparent: true,
              caption: illustration.caption,
              child: SheetIllustrationView(
                illustration: illustration,
                diagrams: specs,
                proposal: proposal,
                showCaption: false,
              ),
            ),
          ),
      ],
    );
  }
}
