import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the player figure from above with the head case {'right
/// eye over the cue'}
Future<void> iLookAtThePlayerFigureFromAboveWithTheHeadCase(
  WidgetTester tester,
  String headCase,
) {
  final value = switch (headCase) {
    'right eye over the cue' => HeadCase.rightEyeOverCue,
    'cue between the eyes' => HeadCase.cueBetweenEyes,
    'left eye over the cue' => HeadCase.leftEyeOverCue,
    _ => throw ArgumentError('place de la tête inconnue : $headCase'),
  };
  return DiagramWorld.show(
    tester,
    PlayerFigure(view: PlayerView.top, headCase: value),
  );
}
