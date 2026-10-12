import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leMeilleurResultatEst(WidgetTester tester, String best) async {
  final point = TrackingWorld.current.curve.best!;
  expect('${point.potted}/${point.total}', best);
}
