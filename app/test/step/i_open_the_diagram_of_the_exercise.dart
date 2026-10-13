import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I open the diagram of the exercise {'full ball'}
Future<void> iOpenTheDiagramOfTheExercise(
  WidgetTester tester,
  String exercise,
) => DiagramWorld.openDiagram(tester, exercise);
