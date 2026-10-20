import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leClubCompteUnGroupeExistantConfieAUnAutreEnseignant(
  WidgetTester tester,
  String name,
) async {
  ImportWorld.current.seedClubGroup(
    id: 'g-${name.toLowerCase()}',
    name: name,
    audience: name == 'Mardi' ? 'adults' : 'children',
    teacher: 'u-other',
  );
}
