import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club {'Test club'} is named {'Club Lyon'}
///
/// Le club (retrouvé par son identifiant d'origine) porte ce nom côté serveur.
Future<void> theClubIsNamed(
  WidgetTester tester,
  String club,
  String name,
) async {
  final stored = UiWorld.documents.read(
    'clubs/${UiWorld.clubIdOf(club).value}',
  );
  expect(stored!['name'], name);
}
