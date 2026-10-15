import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monde des scénarios du design system : un composant est posé seul dans une
/// application localisée avec le thème réel. Le parcours intégré à la fiche
/// d'un exercice passe par `UiWorld` (`exercise_sheet_diagram.feature`). La
/// langue suit celle de l'appareil, comme dans l'application.
class DiagramWorld {
  DiagramWorld._();

  /// Largeur par défaut du schéma : celle d'une tablette en portrait.
  static const double defaultWidth = 450;

  /// Largeur du schéma ; l'étape « le schéma fait N px de large » la change
  /// pour la durée du scénario.
  static double width = defaultWidth;

  /// Description parlée de l'exercice, fournie par l'appelant.
  static const semanticLabel = 'Full ball: pot the yellow ball';

  /// Blanche (4 ; 3,2) -> (4 ; 2,2) puis bille jaune (4 ; 2) -> poche
  /// du milieu : 3 cases, soit 1 s à ×1 (3 cases par seconde).
  static const _fullBall = TableDiagramSpec(
    id: 'full-ball',
    balls: [
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(4, 3.2),
        role: DiagramBallRole.cue,
      ),
      DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(4, 2),
        label: 'x4',
      ),
    ],
    steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm)],
  );

  /// Blanche (7,6 ; 2) contre la bande de droite, jouée vers la gauche : la
  /// queue a son talon derrière la bande si on ne la raccourcit pas.
  static const _againstTheRail = TableDiagramSpec(
    id: 'against-the-rail',
    balls: [
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(7.6, 2),
        role: DiagramBallRole.cue,
      ),
      DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
    ],
    steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tl)],
  );

  static const _ballsToObserve = TableDiagramSpec(
    id: 'balls-to-observe',
    balls: [DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(1, 1))],
  );

  static const _outsideTheTable = TableDiagramSpec(
    id: 'outside',
    balls: [
      DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 9)),
    ],
  );

  static TableDiagramSpec exercise(String name) => switch (name) {
    'full ball' => _fullBall,
    'balls to observe' => _ballsToObserve,
    'shot against the rail' => _againstTheRail,
    'ball outside the table' => _outsideTheTable,
    _ => throw ArgumentError('exercice inconnu : $name'),
  };

  static TableDiagramSpec _current = _fullBall;
  static DiagramPoint? _noted;

  /// Affiche [child] dans l'application (langue de l'appareil).
  static Future<void> show(WidgetTester tester, Widget child) async {
    _noted = null;
    _current = _fullBall;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  static Future<void> openDiagram(WidgetTester tester, String name) async {
    final spec = exercise(name);
    await show(
      tester,
      TableDiagramPlayer(spec: spec, semanticLabel: semanticLabel),
    );
    _current = spec;
  }

  /// Ouvre le schéma [name] sous un `PresentationScope` sans agrandissement
  /// (facteur 1) : seule la taille minimale des étiquettes s'applique.
  static Future<void> openDiagramInPresentation(
    WidgetTester tester,
    String name,
  ) async {
    final spec = exercise(name);
    await show(
      tester,
      PresentationScope(
        scale: 1,
        child: TableDiagram(spec: spec, semanticLabel: semanticLabel),
      ),
    );
    _current = spec;
  }

  /// Taille (px logiques, texte agrandi compris) de chaque étiquette du schéma.
  static List<double> labelFontSizes(WidgetTester tester) => [
    for (final element in _labelElements())
      () {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byElementPredicate((e) => e == element),
            matching: find.byType(RichText),
          ),
        );
        final size = paragraph.text.style!.fontSize!;
        return paragraph.textScaler.scale(size);
      }(),
  ];

  static Iterable<Element> _labelElements() => find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> &&
        (key.value.startsWith('annotation-') ||
            key.value.startsWith('ghost-label-') ||
            key.value.startsWith('ghost-mark-') ||
            key.value.startsWith('ball-label-'));
  }).evaluate();

  /// Rectangle du médaillon de quantité de bille, ou `null` s'il est absent.
  static Rect? insetRect(WidgetTester tester) {
    final finder = find.byKey(const ValueKey('contact-inset'));
    return finder.evaluate().isEmpty ? null : tester.getRect(finder);
  }

  /// Vrai si le médaillon est écrit sous la table (aucune place libre dessus).
  static bool insetIsBelowTheTable(WidgetTester tester) =>
      insetRect(tester)!.top >=
      tester.getRect(find.byType(BilliardTable)).bottom;

  /// Éléments du schéma (trajectoires, billes, cercles, étiquettes) que
  /// recouvre le médaillon ; vide s'il est lisible.
  static List<String> insetCollisions(WidgetTester tester) {
    final rect = insetRect(tester)!;
    final diagram = tester.widget<TableDiagram>(find.byType(TableDiagram));
    final spec = diagram.spec;
    final tableFinder = find.byType(BilliardTable);
    final origin = tester.getTopLeft(tableFinder);
    final geometry = TableGeometry.fitting(tester.getSize(tableFinder));
    Offset px(DiagramPoint p) => geometry.toPixel(Offset(p.x, p.y)) + origin;

    final found = <String>[];
    for (final arrow in spec.arrows) {
      for (var i = 0; i + 1 < arrow.path.length; i++) {
        if (_segmentHitsRect(px(arrow.path[i]), px(arrow.path[i + 1]), rect)) {
          found.add('arrow ${arrow.id}');
        }
      }
    }
    final discs = <(String, Offset, double)>[
      for (final b in spec.balls)
        ('ball ${b.id}', px(b.at), geometry.radiusPxOf(b.color)),
      for (final g in spec.ghosts)
        ('ghost ${g.id}', px(g.at), geometry.ghostRadiusPx),
    ];
    for (final (what, center, radius) in discs) {
      final nearest = Offset(
        center.dx.clamp(rect.left, rect.right),
        center.dy.clamp(rect.top, rect.bottom),
      );
      if ((nearest - center).distance < radius) found.add(what);
    }
    for (final element in _labelElements()) {
      final other = tester.getRect(
        find.byElementPredicate((e) => e == element),
      );
      if (rect.overlaps(other)) {
        found.add('label ${(element.widget.key! as ValueKey<String>).value}');
      }
    }
    return found;
  }

  /// Diagrammes transcrits dont l'état initial montre une queue : pour chacun,
  /// les coins du talon sont-ils dans la table (rails compris) ? Renvoie les
  /// identifiants qui sortent.
  static Future<List<String>> cuesOutsideTheTable(WidgetTester tester) async {
    final library = await tester.runAsync(
      AssetDiagramRepository.fromBundle().load,
    );
    final outside = <String>[];
    for (final diagram in library!.diagrams) {
      final spec = tableDiagramSpecOf(diagram);
      await show(
        tester,
        TableDiagramPlayer(spec: spec, semanticLabel: semanticLabel),
      );
      if (find.byType(BilliardCue).evaluate().isEmpty) continue;
      if (!cueIsInsideTable(tester)) outside.add(diagram.id);
    }
    return outside;
  }

  /// Vrai si les deux coins du talon de la queue affichée sont dans la table.
  static bool cueIsInsideTable(WidgetTester tester) {
    final cue = tester.widget<BilliardCue>(find.byType(BilliardCue));
    final tip = tester.getRect(find.byType(BilliardCue)).centerRight;
    final table = tester.getRect(find.byType(BilliardTable));
    final direction = Offset(math.cos(cue.angle), math.sin(cue.angle));
    final side = Offset(-direction.dy, direction.dx);
    final butt = tip - direction * cue.length;
    const slack = 0.01;
    return [
      butt + side * cue.thickness / 2,
      butt - side * cue.thickness / 2,
    ].every((corner) => table.inflate(slack).contains(corner));
  }

  /// Ouvre le schéma transcrit [id] du catalogue (asset réel).
  static Future<void> openCatalogueDiagram(
    WidgetTester tester,
    String id,
  ) async {
    final spec = await _catalogueSpec(tester, id);
    await show(
      tester,
      TableDiagramPlayer(spec: spec, semanticLabel: semanticLabel),
    );
    _current = spec;
  }

  /// Ouvre le schéma transcrit [id] du catalogue sous un `PresentationScope`
  /// (texte agrandi de 1,5 : celui de la salle).
  static Future<void> openCatalogueDiagramInPresentation(
    WidgetTester tester,
    String id,
  ) async {
    final spec = await _catalogueSpec(tester, id);
    await show(
      tester,
      PresentationScope(
        child: TableDiagram(spec: spec, semanticLabel: semanticLabel),
      ),
    );
    _current = spec;
  }

  static Future<TableDiagramSpec> _catalogueSpec(
    WidgetTester tester,
    String id,
  ) async {
    final library = await tester.runAsync(
      AssetDiagramRepository.fromBundle().load,
    );
    final diagram = library!.byId(id);
    if (diagram == null) throw ArgumentError('schéma inconnu : $id');
    return tableDiagramSpecOf(diagram);
  }

  /// Parcourt les schémas à billes du catalogue, posés à la largeur courante,
  /// à plat puis en présentation ; [check] renvoie les défauts de chacun, qui
  /// sont rassemblés (`id (mode) : défaut`). Renvoie aussi le nombre de
  /// schémas parcourus dans [onCount] (un parcours vide ne prouve rien).
  static Future<List<String>> catalogueProblems(
    WidgetTester tester,
    List<String> Function(WidgetTester tester) check, {
    void Function(int count)? onCount,
    List<bool> modes = const [false, true],
  }) async {
    final library = await tester.runAsync(
      AssetDiagramRepository.fromBundle().load,
    );
    final problems = <String>[];
    var count = 0;
    for (final diagram in library!.diagrams) {
      final spec = tableDiagramSpecOf(diagram);
      if (spec.balls.isEmpty) continue;
      count++;
      for (final presentation in modes) {
        final diagramWidget = TableDiagram(
          spec: spec,
          semanticLabel: semanticLabel,
        );
        await show(
          tester,
          presentation
              ? PresentationScope(child: diagramWidget)
              : diagramWidget,
        );
        final mode = presentation ? 'présentation' : 'à plat';
        problems.addAll([
          for (final problem in check(tester))
            '${diagram.id} ($mode, ${width.round()} px) : $problem',
        ]);
      }
    }
    onCount?.call(count);
    return problems;
  }

  /// Étiquettes (billes, cercles, annotations) affichées par le schéma.
  static int labelCount(WidgetTester tester) => _labelElements().length;

  /// Géométrie de la table affichée.
  static TableGeometry geometry(WidgetTester tester) =>
      TableGeometry.fitting(tester.getSize(find.byType(BilliardTable)));

  /// Étiquettes (repères, lettres de bille, annotations) qui recouvrent une
  /// trajectoire, une bille, un cercle ou une autre étiquette, en cases du
  /// schéma affiché ; vide si le schéma est lisible.
  static List<String> labelCollisions(WidgetTester tester) {
    final diagram = tester.widget<TableDiagram>(find.byType(TableDiagram));
    final spec = diagram.spec;
    final tableFinder = find.byType(BilliardTable);
    final origin = tester.getTopLeft(tableFinder);
    final geometry = TableGeometry.fitting(tester.getSize(tableFinder));
    Offset px(DiagramPoint p) => geometry.toPixel(Offset(p.x, p.y)) + origin;

    final labels = <String, Rect>{
      for (final element in find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            (key.value.startsWith('annotation-') ||
                key.value.startsWith('ghost-label-') ||
                key.value.startsWith('ball-label-'));
      }).evaluate())
        (element.widget.key! as ValueKey<String>).value: tester.getRect(
          find.byElementPredicate((e) => e == element),
        ),
    };

    final discs = <(String, Offset, double)>[
      for (final b in spec.balls)
        (
          'ball ${b.id}',
          px(diagram.frame?.balls[b.id]?.position ?? b.at),
          geometry.radiusPxOf(b.color),
        ),
      for (final g in spec.ghosts)
        ('ghost ${g.id}', px(g.at), geometry.ghostRadiusPx),
    ];
    final collisions = <String>[];
    final surface = geometry.surface.shift(origin).inflate(0.5);
    for (final MapEntry(key: name, value: rect) in labels.entries) {
      if (rect.left < surface.left ||
          rect.top < surface.top ||
          rect.right > surface.right ||
          rect.bottom > surface.bottom) {
        collisions.add('$name x table edge');
      }
      for (final arrow in spec.arrows) {
        for (var i = 0; i + 1 < arrow.path.length; i++) {
          if (_segmentHitsRect(
            px(arrow.path[i]),
            px(arrow.path[i + 1]),
            rect,
          )) {
            collisions.add('$name x arrow ${arrow.id}');
          }
        }
      }
      for (final (what, center, radius) in discs) {
        final nearest = Offset(
          center.dx.clamp(rect.left, rect.right),
          center.dy.clamp(rect.top, rect.bottom),
        );
        if ((nearest - center).distance < radius - 0.5) {
          collisions.add('$name x $what');
        }
      }
      for (final other in labels.entries) {
        if (other.key.compareTo(name) > 0 && rect.overlaps(other.value)) {
          collisions.add('$name x ${other.key}');
        }
      }
    }
    return collisions;
  }

  static bool _segmentHitsRect(Offset a, Offset b, Rect rect) {
    // Test de séparation (Liang-Barsky) du segment [a, b] avec [rect].
    var t0 = 0.0;
    var t1 = 1.0;
    final d = b - a;
    bool clip(double p, double q) {
      if (p == 0) return q >= 0;
      final r = q / p;
      if (p < 0) {
        if (r > t1) return false;
        t0 = math.max(t0, r);
      } else {
        if (r < t0) return false;
        t1 = math.min(t1, r);
      }
      return true;
    }

    return clip(-d.dx, a.dx - rect.left) &&
        clip(d.dx, rect.right - a.dx) &&
        clip(-d.dy, a.dy - rect.top) &&
        clip(d.dy, rect.bottom - a.dy);
  }

  static DiagramBall _ball(String id) =>
      _current.balls.firstWhere((ball) => ball.id == id);

  static DiagramPoint start(String id) => _ball(id).at;

  static DiagramPoint position(WidgetTester tester, String id) {
    final frame = tester.widget<TableDiagram>(find.byType(TableDiagram)).frame!;
    return frame.balls[id]!.position;
  }

  static bool isPotted(WidgetTester tester, String id) => tester
      .widget<TableDiagram>(find.byType(TableDiagram))
      .frame!
      .balls[id]!
      .pocketed;

  static set noted(DiagramPoint point) => _noted = point;

  static DiagramPoint get noted => _noted!;

  /// Vrai si un nœud sémantique porte exactement cette description parlée.
  static Finder describedAs(String description) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == description,
    description: 'description parlée « $description »',
  );
}
