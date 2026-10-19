import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the server refuses the students of the club to the device
///
/// Les règles refusent la lecture des fiches du club (le `member` reste
/// lisible) : un refus, pas une panne du service.
Future<void> theServerRefusesTheStudentsOfTheClubToTheDevice(
  WidgetTester tester,
) async {
  await UiWorld.prepare(tester);
  final club = UiWorld.clubIdOf(UiWorld.defaultClub);
  UiWorld.documents.revoke('clubs/${club.value}/students');
}
