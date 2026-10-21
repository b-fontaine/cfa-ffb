import 'package:flutter_test/flutter_test.dart';

import 'le_club_compte_passages.dart';

/// Usage: the club holds {72} passes
Future<void> theClubHoldsPasses(WidgetTester tester, num count) async {
  await leClubComptePassages(tester, count);
}
