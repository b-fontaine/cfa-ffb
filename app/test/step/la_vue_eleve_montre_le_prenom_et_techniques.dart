import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève montre le prénom {'Léa'} et {15} techniques
Future<void> laVueEleveMontreLePrenomEtTechniques(
  WidgetTester tester,
  String firstName,
  num count,
) async {
  final showcase = TrackingWorld.current.showcase;
  expect(showcase.firstName, firstName);
  expect(showcase.rows, hasLength(count.toInt()));
}
