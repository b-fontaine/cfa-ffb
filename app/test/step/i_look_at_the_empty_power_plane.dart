import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the empty power plane
Future<void> iLookAtTheEmptyPowerPlane(WidgetTester tester) =>
    DiagramWorld.show(tester, const PowerRatio());
