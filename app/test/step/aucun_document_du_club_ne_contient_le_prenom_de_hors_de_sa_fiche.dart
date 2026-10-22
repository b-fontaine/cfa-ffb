import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucunDocumentDuClubNeContientLePrenomDeHorsDeSaFiche(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  bool mentions(Object? value) => switch (value) {
    String() => value == name,
    List<Object?>() => value.any(mentions),
    Map<Object?, Object?>() => value.values.any(mentions),
    _ => false,
  };
  final fiche = 'clubs/c1/students/${OperationsWorld.idOf(name)}';
  for (final entry in world.server.documents.entries) {
    if (entry.key == fiche) continue;
    expect(mentions(entry.value), isFalse, reason: entry.key);
  }
}
