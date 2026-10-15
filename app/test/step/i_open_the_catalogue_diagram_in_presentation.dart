import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I open the catalogue diagram {'entrainement-p05-e1'} in presentation
Future<void> iOpenTheCatalogueDiagramInPresentation(
  WidgetTester tester,
  String id,
) => DiagramWorld.openCatalogueDiagramInPresentation(tester, id);
