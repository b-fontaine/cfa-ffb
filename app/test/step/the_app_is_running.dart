import 'package:billard_cfa/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Démarre l'application avec un graphe de dépendances neuf (horloge figée) ;
/// reprend le graphe déjà amorcé par les étapes `Given` du scénario.
Future<void> theAppIsRunning(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}
