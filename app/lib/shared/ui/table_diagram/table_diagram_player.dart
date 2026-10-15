import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Schéma d'exercice animé : lecture, pause, rejouer, vitesse ×0,5 / ×1 / ×2.
///
/// Les billes avancent à vitesse constante sur le tracé (voir
/// `DiagramTimeline`). Avec `MediaQuery.disableAnimations`, le schéma montre
/// l'image finale, immobile ; les boutons restent utilisables et lancent la
/// lecture à la demande. Sans tir à dérouler, seul le schéma est affiché.
///
/// [maxHeight] (px) borne la hauteur de l'ensemble schéma + commandes : le
/// schéma prend ce que les commandes laissent, sans passer sous 120 px (au-delà
/// de cette borne, l'ensemble garde sa hauteur naturelle et la page défile).
class TableDiagramPlayer extends StatefulWidget {
  const TableDiagramPlayer({
    required this.spec,
    required this.semanticLabel,
    this.showGrid = true,
    this.showHeadString = true,
    this.maxHeight,
    super.key,
  });

  final TableDiagramSpec spec;

  /// Description de l'exercice pour les lecteurs d'écran.
  final String semanticLabel;

  final bool showGrid;
  final bool showHeadString;

  /// Hauteur maximale de l'ensemble schéma + commandes ; sans borne si absente.
  final double? maxHeight;

  @override
  State<TableDiagramPlayer> createState() => _TableDiagramPlayerState();
}

class _TableDiagramPlayerState extends State<TableDiagramPlayer>
    with SingleTickerProviderStateMixin {
  static const _speeds = [0.5, 1.0, 2.0];

  /// `null` quand le schéma est invalide (état d'erreur affiché).
  DiagramTimeline? _timeline;
  late final AnimationController _controller;
  double _speed = 1;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _timeline = _timelineOf(widget.spec);
    // `preserve` : avec « réduire les animations » du système, le contrôleur
    // normal jouerait 20 fois plus vite ; la lecture demandée garde la vitesse
    // choisie (le mouvement n'est lancé que sur action de l'utilisateur).
    _controller = AnimationController(
      vsync: this,
      duration: _scaledDuration(),
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener((_) => setState(() {}));
  }

  static DiagramTimeline? _timelineOf(TableDiagramSpec spec) {
    try {
      return DiagramTimeline.of(spec);
    } on InvalidDiagramException {
      return null;
    }
  }

  Duration _scaledDuration() => Duration(
    microseconds: ((_timeline?.duration.inMicroseconds ?? 0) / _speed).round(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      if (!_controller.isAnimating) _controller.value = reduced ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(TableDiagramPlayer old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec) {
      _controller.stop();
      _timeline = _timelineOf(widget.spec);
      _controller
        ..duration = _scaledDuration()
        ..value = _reducedMotion! ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.isAnimating) {
      // `stop` ne signale aucun changement d'état : le bouton se redessine ici.
      _controller.stop();
      setState(() {});
    } else if (_controller.isCompleted) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  void _replay() => _controller.forward(from: 0);

  void _setSpeed(double speed) {
    final playing = _controller.isAnimating;
    setState(() => _speed = speed);
    _controller.duration = _scaledDuration();
    if (playing) _controller.forward(from: _controller.value);
  }

  String _speedLabel(AppLocalizations l10n, double speed) => switch (speed) {
    0.5 => l10n.diagramSpeedHalf,
    2.0 => l10n.diagramSpeedDouble,
    _ => l10n.diagramSpeedNormal,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeline = _timeline;
    if (timeline == null) return ErrorView(message: l10n.diagramInvalid);
    final diagram = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => TableDiagram(
        spec: widget.spec,
        semanticLabel: widget.semanticLabel,
        frame: timeline.frameAt(_controller.value),
        showGrid: widget.showGrid,
        showHeadString: widget.showHeadString,
      ),
    );
    if (timeline.isEmpty) {
      final bound = widget.maxHeight;
      return bound == null
          ? diagram
          : _FigureAboveControls(
              maxHeight: bound,
              children: [diagram, const SizedBox.shrink()],
            );
    }

    const minimum = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
      ),
    );
    final playing = _controller.isAnimating;
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          style: minimum,
          onPressed: _togglePlay,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          label: Text(playing ? l10n.diagramPause : l10n.diagramPlay),
        ),
        OutlinedButton.icon(
          style: minimum,
          onPressed: _replay,
          icon: const Icon(Icons.replay),
          label: Text(l10n.diagramReplay),
        ),
        SegmentedButton<double>(
          style: minimum,
          showSelectedIcon: false,
          segments: [
            for (final speed in _speeds)
              ButtonSegment(
                value: speed,
                label: Text(_speedLabel(l10n, speed)),
              ),
          ],
          selected: {_speed},
          onSelectionChanged: (selection) => _setSpeed(selection.first),
        ),
      ],
    );
    final maxHeight = widget.maxHeight;
    if (maxHeight != null) {
      return _FigureAboveControls(
        maxHeight: maxHeight,
        children: [diagram, controls],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        diagram,
        const SizedBox(height: AppSpacing.md),
        controls,
      ],
    );
  }
}

/// Le schéma au-dessus de ses commandes, tenant ensemble sous [maxHeight] : les
/// commandes sont mesurées d'abord, le schéma reçoit ce qui reste. Si ce reste
/// est inférieur à [minFigureHeight], le schéma garde sa hauteur naturelle (la
/// page défile) plutôt que de disparaître.
class _FigureAboveControls extends MultiChildRenderObjectWidget {
  const _FigureAboveControls({
    required this.maxHeight,
    required super.children,
  });

  final double maxHeight;

  /// Écart entre le schéma et les commandes.
  static const double gap = AppSpacing.md;

  static const double minFigureHeight = 120;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFigureAboveControls(maxHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFigureAboveControls renderObject,
  ) {
    renderObject.maxHeight = maxHeight;
  }
}

class _FigureParentData extends ContainerBoxParentData<RenderBox>;

class _RenderFigureAboveControls extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FigureParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FigureParentData> {
  _RenderFigureAboveControls(this._maxHeight);

  double _maxHeight;
  double get maxHeight => _maxHeight;
  set maxHeight(double value) {
    if (_maxHeight == value) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FigureParentData) {
      child.parentData = _FigureParentData();
    }
  }

  @override
  void performLayout() {
    final figure = firstChild!;
    final controls = childAfter(figure)!;
    final width = constraints.maxWidth;
    controls.layout(
      BoxConstraints.tightFor(width: width),
      parentUsesSize: true,
    );
    // Sans commandes, pas d'écart.
    final gap = controls.size.height == 0 ? 0.0 : _FigureAboveControls.gap;
    final room = maxHeight - controls.size.height - gap;
    figure.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: room >= _FigureAboveControls.minFigureHeight
            ? room
            : double.infinity,
      ),
      parentUsesSize: true,
    );
    (figure.parentData! as _FigureParentData).offset = Offset.zero;
    (controls.parentData! as _FigureParentData).offset = Offset(
      0,
      figure.size.height + gap,
    );
    size = constraints.constrain(
      Size(width, figure.size.height + gap + controls.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
