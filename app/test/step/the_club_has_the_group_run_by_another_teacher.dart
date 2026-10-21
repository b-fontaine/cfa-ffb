import 'package:flutter_test/flutter_test.dart';

import 'le_club_compte_un_groupe_existant_confie_a_un_autre_enseignant.dart';

/// Usage: the club has the group {'Mardi'} run by another teacher
Future<void> theClubHasTheGroupRunByAnotherTeacher(
  WidgetTester tester,
  String name,
) async {
  await leClubCompteUnGroupeExistantConfieAUnAutreEnseignant(tester, name);
}
