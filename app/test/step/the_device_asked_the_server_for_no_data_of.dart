import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: the device asked the server for no data of {'Marc'}
///
/// Aucune lecture, écoute ni écriture de l'appareil ne vise cet élève (son
/// identifiant ne figure dans aucune demande).
Future<void> theDeviceAskedTheServerForNoDataOf(
  WidgetTester tester,
  String name,
) async {
  final id = await FamilyWorld.studentId(tester, name);
  expect(FamilyWorld.requests, isNotEmpty);
  expect(
    FamilyWorld.requests.where((request) => request.contains(id)),
    isEmpty,
    reason: 'une demande vise $name',
  );
}
