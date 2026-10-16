import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'efface l'élève {'Léa'}
Future<void> jeffaceLeleve(WidgetTester tester, String student) async {
  await TrackingWorld.current.eraseStudent(student);
}
