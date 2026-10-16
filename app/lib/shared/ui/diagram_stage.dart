import 'package:billard_cfa/shared/lib/stage_fit.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/rotate_hint.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scène de présentation d'un schéma : en-tête, titre, schéma, badge, légende
/// et barre précédent/suivant (ADR 0017).
///
/// La mise en page **réserve elle-même** ce qui est fixe : la légende (et le
/// badge) sont placés d'abord à leur hauteur naturelle, le schéma reçoit le
/// reste, sans aucune mesure de texte recopiée à la main (cause de F1). Si ce
/// reste est inférieur à [minFigureHeight], la scène défile plutôt que
/// d'écraser le schéma (un schéma qui ne tient pas dans sa zone, commandes du
/// lecteur comprises, grandit de même) ; l'en-tête et la barre basse restent
/// en place.
///
/// Sous [compactHeight] (téléphone en paysage), le titre visuel passe dans la
/// barre basse ; sous [shortHeight] de haut ou [narrowWidth] de large, le
/// titre et la légende se réduisent d'un cran. Le titre reste, dans tous les
/// cas, l'unique en-tête sémantique.
///
/// En portrait, quand la largeur borne le schéma ([figureAspect]), un bandeau
/// [RotateHint] invite à tourner l'appareil ; il se ferme pour l'étape (donner
/// une `key` par étape réaffiche le bandeau à la suivante).
class DiagramStage extends StatefulWidget {
  const DiagramStage({
    required this.title,
    required this.header,
    required this.figure,
    required this.figureAspect,
    required this.previous,
    required this.next,
    this.caption,
    this.badge,
    this.minFigureHeight = defaultMinFigureHeight,
    this.bottomBarKey = const ValueKey('diagram-stage-bottom-bar'),
    super.key,
  }) : assert(figureAspect > 0, 'figureAspect doit être > 0'),
       assert(minFigureHeight > 0, 'minFigureHeight doit être > 0');

  /// Titre de l'étape.
  final String title;

  /// Ligne du haut (position, boutons Plein écran et Fermer), à sa hauteur
  /// naturelle.
  final Widget header;

  /// Le schéma, construit pour la zone [Size] qui lui est donnée (largeur et
  /// hauteur maximales). Il est centré dans la zone.
  final Widget Function(BuildContext context, Size zone) figure;

  /// Rapport largeur / hauteur du schéma, pour l'indication de rotation.
  final double figureAspect;

  /// Légende, écrite en gros sur un panneau.
  final String? caption;

  /// Badge sous le schéma (par exemple « Proposition »).
  final Widget? badge;

  /// Boutons de la barre basse.
  final Widget previous;
  final Widget next;

  /// Hauteur minimale (dp) de la zone du schéma : en dessous, la scène défile.
  /// Une figure à commandes y ajoute la hauteur de ses commandes.
  final double minFigureHeight;

  /// Clé de la barre basse, que l'écran qui emploie la scène peut remplacer
  /// par la sienne (un test vise alors l'écran, pas le composant).
  final Key bottomBarKey;

  /// Valeur par défaut de [minFigureHeight].
  static const double defaultMinFigureHeight = 160;

  /// Hauteur (dp) sous laquelle la scène est compacte.
  static const double compactHeight = 480;

  /// Hauteur (dp) sous laquelle les textes de la scène se réduisent d'un cran.
  static const double shortHeight = 640;

  /// Largeur (dp) sous laquelle les textes de la scène se réduisent d'un cran.
  static const double narrowWidth = 600;

  @override
  State<DiagramStage> createState() => _DiagramStageState();
}

class _DiagramStageState extends State<DiagramStage> {
  bool _hintDismissed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < DiagramStage.compactHeight;
        // Téléphone ou petite tablette : textes un cran plus petits, pour que
        // légende et schéma tiennent ensemble.
        final small =
            compact ||
            constraints.maxWidth < DiagramStage.narrowWidth ||
            constraints.maxHeight < DiagramStage.shortHeight;
        final title = Semantics(
          header: true,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: small
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge,
          ),
        );
        return Column(
          key: const ValueKey('diagram-stage'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.header,
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, zone) => _scene(
                  context,
                  zone,
                  compact,
                  small,
                  compact ? null : title,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              key: widget.bottomBarKey,
              children: [
                Expanded(flex: compact ? 2 : 1, child: widget.previous),
                const SizedBox(width: AppSpacing.md),
                if (compact) ...[
                  Expanded(flex: 3, child: title),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(flex: compact ? 2 : 1, child: widget.next),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _scene(
    BuildContext context,
    BoxConstraints zone,
    bool compact,
    bool small,
    Widget? title,
  ) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final showHint =
        !_hintDismissed &&
        media.orientation == Orientation.portrait &&
        isWidthLimited(
          width: zone.maxWidth,
          height: zone.maxHeight,
          aspect: widget.figureAspect,
        );
    final caption = widget.caption;
    final badge = widget.badge;
    final hint = showHint
        // Posé hors de la scène des élèves (sémantique, texte à sa taille) :
        // il s'adresse à l'animateur, pas aux élèves.
        ? RotateHint(onDismiss: () => setState(() => _hintDismissed = true))
        : null;
    final scene = LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: PresentationScope(
          transparent: true,
          padding: EdgeInsets.zero,
          child: _StageBody(
            viewportHeight: viewport.maxHeight,
            minFigureHeight: widget.minFigureHeight,
            title: title,
            figure: LayoutBuilder(
              key: const ValueKey('diagram-stage-figure'),
              // La zone est la hauteur minimale reçue : le schéma peut la
              // dépasser s'il ne tient pas (voir _RenderStageBody).
              builder: (context, box) => Center(
                child: widget.figure(
                  context,
                  Size(box.maxWidth, box.minHeight),
                ),
              ),
            ),
            footer: caption == null && badge == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (badge != null) ...[
                        Center(child: badge),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (caption != null)
                        PresentationCaption(
                          key: const ValueKey('diagram-stage-caption'),
                          text: caption,
                          padding: EdgeInsets.all(
                            compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                          style: small
                              ? theme.textTheme.bodyLarge
                              : theme.textTheme.headlineSmall,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (hint == null) return scene;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hint,
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: scene),
      ],
    );
  }
}

enum _Slot { title, figure, footer }

/// Le corps défilant de la scène : titre, schéma puis légende. Le
/// titre et la légende sont mesurés d'abord ; le schéma reçoit ce
/// qui reste de [viewportHeight], au moins [DiagramStage.minFigureHeight].
class _StageBody extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _StageBody({
    required this.viewportHeight,
    required this.minFigureHeight,
    required this.figure,
    this.title,
    this.footer,
  });

  final double viewportHeight;
  final double minFigureHeight;
  final Widget? title;
  final Widget figure;
  final Widget? footer;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.title => title,
    _Slot.figure => figure,
    _Slot.footer => footer,
  };

  @override
  SlottedContainerRenderObjectMixin<_Slot, RenderBox> createRenderObject(
    BuildContext context,
  ) => _RenderStageBody(viewportHeight, minFigureHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderStageBody renderObject) {
    renderObject
      ..viewportHeight = viewportHeight
      ..minFigureHeight = minFigureHeight;
  }
}

class _RenderStageBody extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderStageBody(this._viewportHeight, this._minFigureHeight);

  static const double _gap = AppSpacing.md;

  double _viewportHeight;
  double get viewportHeight => _viewportHeight;
  set viewportHeight(double value) {
    if (_viewportHeight == value) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  double _minFigureHeight;
  double get minFigureHeight => _minFigureHeight;
  set minFigureHeight(double value) {
    if (_minFigureHeight == value) return;
    _minFigureHeight = value;
    markNeedsLayout();
  }

  RenderBox get _figure => childForSlot(_Slot.figure)!;

  /// Ce qui est mesuré avant le schéma, de haut en bas.
  List<RenderBox> get _above => [?childForSlot(_Slot.title)];

  /// Ce qui est mesuré avant le schéma, mais posé dessous.
  List<RenderBox> get _below => [?childForSlot(_Slot.footer)];

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason: 'La hauteur du schéma dépend de son contenu (LayoutBuilder).',
      ),
      'dry layout impossible',
    );
    return Size.zero;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final wide = BoxConstraints(minWidth: width, maxWidth: width);
    // Les parties fixes d'abord, à leur hauteur naturelle.
    double fixed = 0;
    for (final child in [..._above, ..._below]) {
      child.layout(wide, parentUsesSize: true);
      fixed += child.size.height + _gap;
    }
    final room = _viewportHeight - fixed;
    final zone = room < _minFigureHeight ? _minFigureHeight : room;
    // Le schéma reçoit la zone comme hauteur minimale : s'il ne peut pas y
    // tenir (commandes du lecteur comprises), il grandit et la scène défile
    // plutôt que de le laisser déborder sur la légende.
    _figure.layout(wide.copyWith(minHeight: zone), parentUsesSize: true);
    var y = 0.0;
    void place(RenderBox child) {
      (child.parentData! as BoxParentData).offset = Offset(0, y);
      y += child.size.height + _gap;
    }

    _above.forEach(place);
    place(_figure);
    _below.forEach(place);
    size = constraints.constrain(Size(width, y - _gap));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
