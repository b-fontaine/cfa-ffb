import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the guided session of {'demi-bille-1'} has its timer {'paused'}
///
/// `paused` ou `running`, lu dans le cubit du guide en cours.
Future<void> theGuidedSessionOfHasItsTimer(
  WidgetTester tester,
  String sheet,
  String state,
) async {
  // La pause demandée par la sortie de l'écran est asynchrone : l'annulation
  // du flux périodique se termine dans la zone réelle, on la laisse finir.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  final sessions = getIt<RunSheetSessions>();
  final keys = sessions.runningKeys.where((key) => key.sheetId.value == sheet);
  expect(keys, hasLength(1), reason: 'aucun guide en cours pour $sheet');
  expect(sessions.of(keys.single).state.timerRunning, state == 'running');
}
