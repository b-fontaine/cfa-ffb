import 'package:flutter_test/flutter_test.dart';

import '../support/account_deletion_world.dart';
import '../support/ui_world.dart';

/// Usage: nothing of {'coach@example.org'} is kept on the device
///
/// Ni club retenu, ni journal des invitations émises, ni code d'invitation
/// gardé : aucune clé du stockage local ne nomme encore ce compte.
Future<void> nothingOfIsKeptOnTheDevice(
  WidgetTester tester,
  String email,
) async {
  final uid = AccountDeletionWorld.uidOf(email).value;
  expect(UiWorld.store.entries.keys.where((key) => key.contains(uid)), isEmpty);
}
