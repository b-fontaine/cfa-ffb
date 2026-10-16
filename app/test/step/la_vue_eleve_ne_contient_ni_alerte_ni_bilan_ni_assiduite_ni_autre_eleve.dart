import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève ne contient ni alerte, ni bilan, ni assiduité, ni
///   autre élève
Future<void> laVueEleveNeContientNiAlerteNiBilanNiAssiduiteNiAutreEleve(
  WidgetTester tester,
) async {
  final text = TrackingWorld.current.showcase.toString().toLowerCase();
  for (final forbidden in [
    'alert',
    'failure',
    'echec',
    'comment',
    'assessment',
    'maturity',
    'attendance',
    'théo',
  ]) {
    expect(text, isNot(contains(forbidden)), reason: forbidden);
  }
}
