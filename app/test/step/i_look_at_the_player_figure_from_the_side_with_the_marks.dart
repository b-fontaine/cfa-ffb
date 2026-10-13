import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the player figure from the side with the marks {'feet,
/// head'}
Future<void> iLookAtThePlayerFigureFromTheSideWithTheMarks(
  WidgetTester tester,
  String marks,
) {
  final focus = [
    for (final name in marks.split(','))
      switch (name.trim()) {
        'feet' => PlayerMark.feet,
        'legs' => PlayerMark.legsAndHips,
        'head' => PlayerMark.head,
        'forearm' => PlayerMark.backForearm,
        'bridge' => PlayerMark.bridgeHand,
        'cue' => PlayerMark.cue,
        _ => throw ArgumentError('repère inconnu : $name'),
      },
  ];
  return DiagramWorld.show(tester, PlayerFigure(focus: focus));
}
