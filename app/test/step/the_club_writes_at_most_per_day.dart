import 'package:flutter_test/flutter_test.dart';

import 'le_plafond_decritures_par_jour_est_de.dart';

/// Usage: the club writes at most {60} per day
Future<void> theClubWritesAtMostPerDay(WidgetTester tester, num writes) async {
  await lePlafondDecrituresParJourEstDe(tester, writes);
}
