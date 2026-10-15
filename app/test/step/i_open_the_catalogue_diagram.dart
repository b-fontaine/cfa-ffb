import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I open the catalogue diagram {'entrainement-p05-e1'}
Future<void> iOpenTheCatalogueDiagram(WidgetTester tester, String id) =>
    DiagramWorld.openCatalogueDiagram(tester, id);
