import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the device keeps no running state for {'posture-1'}
///
/// Aucune séance guidée en cours n'est gardée sur l'appareil pour cette
/// séance du catalogue (lecture du dépôt, pas de l'écran).
Future<void> theDeviceKeepsNoRunningStateFor(
  WidgetTester tester,
  String sheet,
) async {
  final kept = await getIt<RunProgressRepository>().all();
  expect(
    kept.where((progress) => progress.key.sheetId.value == sheet),
    isEmpty,
    reason: 'un état en cours de « $sheet » est gardé',
  );
}
