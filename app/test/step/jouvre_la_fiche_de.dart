import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre la fiche de {'Léa'}
Future<void> jouvreLaFicheDe(WidgetTester tester, String student) async {
  await TrackingWorld.current.openSheet(student);
}
