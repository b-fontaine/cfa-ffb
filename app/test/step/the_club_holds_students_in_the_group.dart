import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the club holds {3} students in the group {'Jeudi'}
Future<void> theClubHoldsStudentsInTheGroup(
  WidgetTester tester,
  num count,
  String group,
) async {
  final id = 'g-${group.toLowerCase()}';
  final world = ImportWorld.current;
  final inGroup = [
    for (final entry in world.server.documents.entries)
      if (entry.key.contains('/students/') &&
          (entry.value['groupIds']! as List).contains(id))
        entry.key,
  ];
  expect(inGroup.length, count);
}
