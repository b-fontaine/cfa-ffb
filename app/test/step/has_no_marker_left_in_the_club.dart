import 'package:flutter_test/flutter_test.dart';

import '../support/account_deletion_world.dart';
import '../support/ui_world.dart';

/// Usage: {'coach@example.org'} has no marker left in the club {'Test club'}
///
/// Aucun marqueur d'import ni d'opération dont l'identifiant finit par l'uid
/// du compte ne reste dans le club.
Future<void> hasNoMarkerLeftInTheClub(
  WidgetTester tester,
  String email,
  String club,
) async {
  final uid = AccountDeletionWorld.uidOf(email).value;
  final root = 'clubs/${UiWorld.clubIdOf(club).value}';
  final left = UiWorld.documents.documents.keys.where(
    (path) =>
        (path.startsWith('$root/imports/') ||
            path.startsWith('$root/operations/')) &&
        path.endsWith('_$uid'),
  );
  expect(left, isEmpty);
}
