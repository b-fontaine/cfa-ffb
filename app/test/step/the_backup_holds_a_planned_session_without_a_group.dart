import 'package:flutter_test/flutter_test.dart';

import 'la_sauvegarde_contient_une_seance_planifiee_sans_groupe.dart';

/// Usage: the backup holds a planned session without a group
Future<void> theBackupHoldsAPlannedSessionWithoutAGroup(
  WidgetTester tester,
) async {
  await laSauvegardeContientUneSeancePlanifieeSansGroupe(tester);
}
