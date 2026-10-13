import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing is recorded
///
/// Lire une séance guidée n'écrit rien : ni séance planifiée, ni séance
/// donnée, ni passage.
Future<void> nothingIsRecorded(WidgetTester tester) async {
  expect(await getIt<SessionRepository>().getAll(), isEmpty);
  expect(await getIt<SessionRecordRepository>().all(), isEmpty);
  expect(await getIt<AttemptRepository>().all(), isEmpty);
}
