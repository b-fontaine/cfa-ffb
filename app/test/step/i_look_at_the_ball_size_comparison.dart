import 'package:billard_cfa/shared/ui/ball_size_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the ball size comparison
Future<void> iLookAtTheBallSizeComparison(WidgetTester tester) =>
    DiagramWorld.show(tester, const BallSizeComparison());
