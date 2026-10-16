import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'en-tête compte {4} exercices validés sur {70}
Future<void> lenteteCompteExercicesValidesSur(
  WidgetTester tester,
  num validated,
  num total,
) async {
  final header = TrackingWorld.current.sheet.header;
  expect(header.validatedExercises, validated.toInt());
  expect(header.exerciseCount, total.toInt());
}
