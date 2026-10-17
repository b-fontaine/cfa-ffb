import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the device keeps a running state for {'posture-1'}
Future<void> theDeviceKeepsARunningStateFor(
  WidgetTester tester,
  String sheet,
) async {
  final kept = await getIt<RunProgressRepository>().all();
  expect(
    kept.where((progress) => progress.key.sheetId.value == sheet),
    isNotEmpty,
    reason: 'aucun état en cours de « $sheet » n’est gardé',
  );
}
