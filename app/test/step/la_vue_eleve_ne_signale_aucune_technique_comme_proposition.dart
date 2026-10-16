import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève ne signale aucune technique comme proposition
///
/// Le modèle de la vue élève n'a aucun champ de provenance ; on contrôle ici
/// les titres montrés. L'écran est gardé par le test de widget et par le
/// scénario d'interface de la fiche.
Future<void> laVueEleveNeSignaleAucuneTechniqueCommeProposition(
  WidgetTester tester,
) async {
  final titles = TrackingWorld.current.showcase.rows.map((row) => row.title);
  expect(titles, isNotEmpty);
  for (final title in titles) {
    expect(title.toLowerCase(), isNot(contains('proposal')));
    expect(title.toLowerCase(), isNot(contains('proposition')));
  }
}
