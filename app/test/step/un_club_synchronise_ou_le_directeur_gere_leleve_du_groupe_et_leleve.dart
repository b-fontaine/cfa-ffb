import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unClubSynchroniseOuLeDirecteurGereLeleveDuGroupeEtLeleve(
  WidgetTester tester,
  String first,
  String groupName,
  String second,
) async {
  final world = OperationsWorld.open();
  await world.seeding((w) async {
    w.seedDirector();
    await w.seedSeason();
    await w.seedGroup(groupName);
    await w.seedStudent(first, groupName: groupName);
    await w.seedStudent(second, groupName: groupName);
  });
}
