import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';
import '../support/tracking_world.dart';

/// Usage: {'Zoé'} est membre du groupe {'Jeunes'}
Future<void> estMembreDuGroupe(
  WidgetTester tester,
  String student,
  String group,
) async {
  final found = await GroupOps.studentNamed(student);
  expect(found, isNotNull, reason: 'élève introuvable : $student');
  final target = await GroupOps.groupNamed(group);
  expect(target.isMemberOn(found!.id, TrackingWorld.today), isTrue);
}
