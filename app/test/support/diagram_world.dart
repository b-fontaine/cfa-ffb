import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monde des scénarios du design system : un composant est posé seul dans une
/// application localisée avec le thème réel. Le parcours intégré à la fiche
/// d'un exercice passe par `UiWorld` (`exercise_sheet_diagram.feature`). La
/// langue suit celle de l'appareil, comme dans l'application.
class DiagramWorld {
  DiagramWorld._();

  /// Largeur du schéma : celle d'une tablette en portrait.
  static const double width = 450;

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
