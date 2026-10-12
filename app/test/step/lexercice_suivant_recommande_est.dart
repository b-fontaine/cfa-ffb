import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lexerciceSuivantRecommandeEst(
  WidgetTester tester,
  String exercise,
) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  expect(recorded.nextExercise, TrackingWorld.exercise(exercise));
}
