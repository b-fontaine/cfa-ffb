import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the power plane with a {'long'} amplitude and a {'fast'}
/// speed
Future<void> iLookAtThePowerPlaneWithAAmplitudeAndASpeed(
  WidgetTester tester,
  String amplitude,
  String speed,
) {
  final a = switch (amplitude) {
    'short' => AmplitudeLevel.short,
    'medium' => AmplitudeLevel.medium,
    'long' => AmplitudeLevel.long,
    _ => throw ArgumentError('amplitude inconnue : $amplitude'),
  };
  final v = switch (speed) {
    'slow' => SpeedLevel.slow,
    'medium' => SpeedLevel.medium,
    'fast' => SpeedLevel.fast,
    _ => throw ArgumentError('vitesse inconnue : $speed'),
  };
  return DiagramWorld.show(
    tester,
    PowerRatio(
      points: [PowerPoint(amplitude: a, speed: v)],
    ),
  );
}
