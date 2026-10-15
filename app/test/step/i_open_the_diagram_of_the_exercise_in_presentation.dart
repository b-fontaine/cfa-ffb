import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I open the diagram of the exercise {'full ball'} in presentation
Future<void> iOpenTheDiagramOfTheExerciseInPresentation(
  WidgetTester tester,
  String name,
) => DiagramWorld.openDiagramInPresentation(tester, name);
