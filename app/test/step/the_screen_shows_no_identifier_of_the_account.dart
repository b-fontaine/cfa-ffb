import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';

/// Usage: the screen shows no identifier of the account
Future<void> theScreenShowsNoIdentifierOfTheAccount(WidgetTester tester) async {
  // Ni l'identifiant du compte, ni l'empreinte du fichier : le marqueur ne se
  // montre que comme des lots faits sur des lots prévus.
  expect(find.textContaining(ImportScreenWorld.account), findsNothing);
  final fingerprint = ImportWorld.current.marker()?['fileId'] as String?;
  if (fingerprint != null) {
    expect(find.textContaining(fingerprint.substring(0, 12)), findsNothing);
  }
}
