import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leGroupeDePublicCompteLeleve(
  WidgetTester tester,
  String group,
  String audience,
  String student,
) async {
  await TrackingWorld.current.addStudent(
    group: group,
    audienceName: audience,
    student: student,
  );
}
