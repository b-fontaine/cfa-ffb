import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pump_ui.dart';

// Blanche (4 ; 3,2) -> (4 ; 2,2) : 1 ; cible (4 ; 2) -> poche tm : 2.
// À 3 cases par seconde : 1 s à ×1.
const _spec = TableDiagramSpec(
  id: 'player',
  balls: [
    DiagramBall(
      id: 'w',
      color: BallKind.white,
      at: DiagramPoint(4, 3.2),
      role: DiagramBallRole.cue,
    ),
    DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
  ],
  steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm)],
);

const _static = TableDiagramSpec(
  id: 'static',
  balls: [DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(1, 1))],
);

Widget _player([TableDiagramSpec spec = _spec]) => Center(
  child: SizedBox(
    width: 450,
    child: TableDiagramPlayer(spec: spec, semanticLabel: 'Full ball'),
  ),
);

DiagramPoint _white(WidgetTester tester) => tester
    .widget<TableDiagram>(find.byType(TableDiagram))
    .frame!
    .balls['w']!
    .position;

bool _pocketed(WidgetTester tester) => tester
    .widget<TableDiagram>(find.byType(TableDiagram))
    .frame!
    .balls['y1']!
    .pocketed;

DiagramPoint _object(WidgetTester tester) => tester
    .widget<TableDiagram>(find.byType(TableDiagram))
    .frame!
    .balls['y1']!
    .position;

double _y(DiagramPoint p) => p.y;

void main() {
  testWidgets('offers play, replay and three speeds, localised', (
    tester,
  ) async {
    await pumpUi(tester, _player());
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Speed ×0.5'), findsOneWidget);
    expect(find.text('Speed ×1'), findsOneWidget);
    expect(find.text('Speed ×2'), findsOneWidget);

    await pumpUi(tester, _player(), locale: const Locale('fr'));
    expect(find.text('Lire'), findsOneWidget);
    expect(find.text('Rejouer'), findsOneWidget);
    expect(find.text('Vitesse ×0,5'), findsOneWidget);
  });

  testWidgets('gives every control a touch target of at least 48 dp', (
    tester,
  ) async {
    await pumpUi(tester, _player());
    for (final label in [
      'Play',
      'Replay',
      'Speed ×0.5',
      'Speed ×1',
      'Speed ×2',
    ]) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton || w is InkResponse,
        ),
      );
      final size = tester.getSize(button.first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('shows the initial layout, paused', (tester) async {
    await pumpUi(tester, _player());
    expect(_y(_white(tester)), closeTo(3.2, 1e-9));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('plays the shot at constant speed, then stops on the end', (
    tester,
  ) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // d = 1,5 : la blanche est arrivée en (4 ; 2,2).
    expect(_y(_white(tester)), closeTo(2.2, 1e-6));
    expect(_pocketed(tester), isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    expect(_pocketed(tester), isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('pauses and resumes where it stopped', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Play'), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    // 100 ms à ×1 : d = 0,3.
    expect(_y(_white(tester)), closeTo(2.9, 1e-6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_y(_white(tester)), closeTo(2.9, 1e-6));
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_y(_white(tester)), closeTo(2.6, 1e-6));
    await tester.pumpAndSettle();
  });

  testWidgets('replays from the start', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(_pocketed(tester), isTrue);

    await tester.tap(find.text('Replay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_pocketed(tester), isFalse);
    // 50 ms à ×1 : d = 0,15.
    expect(_y(_white(tester)), closeTo(3.05, 1e-6));
    await tester.pumpAndSettle();
    expect(_pocketed(tester), isTrue);
  });

  testWidgets('plays again from the start when it had finished', (
    tester,
  ) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_pocketed(tester), isFalse);
    await tester.pumpAndSettle();
  });

  // Longueur 3 à 3 cases par seconde : 1000 ms à ×1. À d = 0,75 la blanche est
  // en y = 2,45 ; à d = 1,5 elle est arrivée en 2,2 et la cible est en 1,5.
  Future<void> expectAt(
    WidgetTester tester, {
    required double white,
    required double object,
  }) async {
    expect(_y(_white(tester)), closeTo(white, 1e-6));
    expect(_y(_object(tester)), closeTo(object, 1e-6));
  }

  SegmentedButton<double> segments(WidgetTester tester) => tester
      .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));

  testWidgets('selects ×1 by default', (tester) async {
    await pumpUi(tester, _player());
    expect(segments(tester).selected, {1.0});
  });

  testWidgets('at ×1 the shot is at d = 0.75 after 250 ms', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await expectAt(tester, white: 2.45, object: 2);
    await tester.pumpAndSettle();
  });

  testWidgets('at ×2 the shot is at d = 1.5 after 250 ms', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Speed ×2'));
    await tester.pump();
    expect(segments(tester).selected, {2.0});

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await expectAt(tester, white: 2.2, object: 1.5);
    expect(_pocketed(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_pocketed(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('at ×0.5 the shot is at d = 1.5 after 1000 ms', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Speed ×0.5'));
    await tester.pump();
    expect(segments(tester).selected, {0.5});

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await expectAt(tester, white: 2.45, object: 2);
    await tester.pump(const Duration(milliseconds: 500));
    await expectAt(tester, white: 2.2, object: 1.5);
    expect(_pocketed(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_pocketed(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('goes back to ×1 after ×2', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Speed ×2'));
    await tester.pump();
    await tester.tap(find.text('Speed ×1'));
    await tester.pump();
    expect(segments(tester).selected, {1.0});

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await expectAt(tester, white: 2.45, object: 2);
    await tester.pumpAndSettle();
  });

  testWidgets('changing the speed while playing keeps the position', (
    tester,
  ) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // d = 0,6.
    await expectAt(tester, white: 2.6, object: 2);

    await tester.tap(find.text('Speed ×2'));
    await tester.pump();
    await expectAt(tester, white: 2.6, object: 2);

    // Reste 0,8 de la course à 500 ms : 100 ms plus tard, d = 1,2.
    await tester.pump(const Duration(milliseconds: 100));
    await expectAt(tester, white: 2.2, object: 1.8);
    await tester.pumpAndSettle();
    expect(_pocketed(tester), isTrue);
  });

  testWidgets('with reduced motion, shows the final image and stays still', (
    tester,
  ) async {
    await pumpUi(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: _player(),
        ),
      ),
    );

    expect(_pocketed(tester), isTrue);
    expect(_y(_white(tester)), closeTo(2.2, 1e-9));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with reduced motion, the controls still work', (tester) async {
    await pumpUi(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: _player(),
        ),
      ),
    );

    await tester.tap(find.text('Replay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_pocketed(tester), isFalse);
    await tester.pumpAndSettle();
    expect(_pocketed(tester), isTrue);
  });

  testWidgets(
    'with the system reduced motion setting, replay still runs at the '
    'selected speed',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpUi(tester, _player());
      expect(_pocketed(tester), isTrue);

      await tester.tap(find.text('Replay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // 250 ms à ×1 : d = 0,75, la bille n'est pas encore empochée.
      expect(_pocketed(tester), isFalse);
      expect(_y(_white(tester)), closeTo(2.45, 1e-6));
      await tester.pumpAndSettle();
      expect(_pocketed(tester), isTrue);
    },
  );

  testWidgets('follows the reduced motion preference when it changes', (
    tester,
  ) async {
    Widget app({required bool reduce}) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: _player(),
      ),
    );

    await pumpUi(tester, app(reduce: true));
    expect(_pocketed(tester), isTrue);
    await pumpUi(tester, app(reduce: false));
    expect(_pocketed(tester), isFalse);
    expect(_y(_white(tester)), closeTo(3.2, 1e-9));
  });

  testWidgets('shows only the diagram when there is nothing to play', (
    tester,
  ) async {
    await pumpUi(tester, _player(_static));
    expect(find.byType(TableDiagram), findsOneWidget);
    expect(find.text('Play'), findsNothing);
    expect(find.text('Replay'), findsNothing);
  });

  testWidgets('rebuilds the timeline when the spec changes', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(_pocketed(tester), isTrue);

    await pumpUi(tester, _player(_static));
    expect(find.text('Play'), findsNothing);

    await pumpUi(tester, _player());
    expect(_pocketed(tester), isFalse);
  });

  testWidgets('takes the duration of the new spec', (tester) async {
    // Deux fois le même tir : longueur 6, soit 2000 ms à ×1.
    const twice = TableDiagramSpec(
      id: 'twice',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(4, 3.2)),
        DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
      ],
      steps: [
        DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm),
        DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm),
      ],
    );
    await pumpUi(tester, _player());
    await pumpUi(tester, _player(twice));

    await tester.tap(find.text('Play'));
    await tester.pump();
    // Après 1100 ms, le premier tir est fini : le second a commencé (d = 3,3,
    // soit 0,3 dans le second tir) et la cible est remise en place.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_y(_white(tester)), closeTo(2.9, 1e-6));
    expect(_pocketed(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_pocketed(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('keeps every control and label at a text scale of 2 in 320 px', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: const SingleChildScrollView(
            child: TableDiagramPlayer(spec: _spec, semanticLabel: 'Full ball'),
          ),
        ),
      ),
      locale: const Locale('fr'),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(SegmentedButton<double>)).right,
      lessThanOrEqualTo(320),
    );
    for (final label in [
      'Lire',
      'Rejouer',
      'Vitesse ×0,5',
      'Vitesse ×1',
      'Vitesse ×2',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton || w is InkResponse,
        ),
      );
      final size = tester.getSize(button.first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(
        tester.getRect(button.first).right,
        lessThanOrEqualTo(320),
        reason: label,
      );
    }
  });

  testWidgets('disposes its ticker cleanly while playing', (tester) async {
    await pumpUi(tester, _player());
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    await pumpUi(tester, const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes the description of the exercise', (tester) async {
    await pumpUi(tester, _player());
    expect(find.bySemanticsLabel('Full ball'), findsOneWidget);
  });

  testWidgets('shows a localised error for an invalid spec, no controls', (
    tester,
  ) async {
    const bad = TableDiagramSpec(
      id: 'bad',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 9)),
      ],
    );
    await pumpUi(tester, _player(bad));

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(TableDiagram), findsNothing);
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('recovers when the spec becomes valid', (tester) async {
    const bad = TableDiagramSpec(
      id: 'bad',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 9)),
      ],
    );
    await pumpUi(tester, _player(bad));
    expect(find.byType(ErrorView), findsOneWidget);

    await pumpUi(tester, _player());
    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('an equal spec rebuilt by the parent keeps the animation', (
    tester,
  ) async {
    // Valeurs calculées à l'exécution : chaque appel crée une nouvelle
    // instance, égale par valeur mais pas identique.
    TableDiagramSpec copy() {
      final four = double.parse('4');
      final two = double.parse('2');
      return TableDiagramSpec(
        id: 'player',
        balls: [
          DiagramBall(
            id: 'w',
            color: BallKind.white,
            at: DiagramPoint(four, 3.2),
            role: DiagramBallRole.cue,
          ),
          DiagramBall(
            id: 'y1',
            color: BallKind.yellow,
            at: DiagramPoint(four, two),
          ),
        ],
        steps: const [
          DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm),
        ],
      );
    }

    expect(identical(copy(), copy()), isFalse);
    expect(copy(), copy());
    await pumpUi(tester, _player(copy()));
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final before = _white(tester);

    await pumpUi(tester, _player(copy()));
    final after = _white(tester);

    expect(after, before);
    expect(after.y, lessThan(3.2));
  });
}
