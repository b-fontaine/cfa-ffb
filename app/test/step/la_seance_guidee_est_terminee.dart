import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'la_seance_guidee_est_commencee_a_letape.dart';

/// Usage: la séance guidée {'posture-1'} est terminée
Future<void> laSeanceGuideeEstTerminee(
  WidgetTester tester,
  String sheet,
) async {
  await getIt<RunSheetSessions>().release(guidedKey(sheet));
}
