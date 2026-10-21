import 'package:flutter_test/flutter_test.dart';

import 'le_club_compte_un_groupe_existant_confie_a_lenseignant.dart';

/// Usage: the club has the group {'Jeudi'} run by the teacher
Future<void> theClubHasTheGroupRunByTheTeacher(
  WidgetTester tester,
  String name,
) async {
  await leClubCompteUnGroupeExistantConfieALenseignant(tester, name);
}
