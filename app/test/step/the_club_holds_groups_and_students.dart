import 'package:flutter_test/flutter_test.dart';

import 'le_club_compte_groupes_et_eleves.dart';

/// Usage: the club holds {2} groups and {6} students
Future<void> theClubHoldsGroupsAndStudents(
  WidgetTester tester,
  num groups,
  num students,
) async {
  await leClubCompteGroupesEtEleves(tester, groups, students);
}
