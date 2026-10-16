import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clé de la séance guidée [sheet] lancée pour les enfants (les scénarios
/// n'en ouvrent qu'une).
RunKey guidedKey(String sheet) =>
    RunKey(sheetId: SheetId(sheet), audience: Audience.children);

/// Usage: la séance guidée {'posture-1'} est commencée à l'étape {2}
Future<void> laSeanceGuideeEstCommenceeALetape(
  WidgetTester tester,
  String sheet,
  num step,
) async {
  final cubit = getIt<RunSheetSessions>().of(guidedKey(sheet));
  await tester.runAsync(cubit.load);
  cubit.showStep(step.toInt());
}
