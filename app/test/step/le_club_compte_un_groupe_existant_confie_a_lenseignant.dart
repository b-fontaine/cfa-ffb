import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leClubCompteUnGroupeExistantConfieALenseignant(
  WidgetTester tester,
  String name,
) async {
  final world = ImportWorld.current;
  final id = 'g-${name.toLowerCase()}';
  world.seedClubGroup(
    id: id,
    name: name,
    audience: name == 'Mardi' ? 'adults' : 'children',
    teacher: 'u-import',
  );
  world.teacherGroups.add(id);
}
