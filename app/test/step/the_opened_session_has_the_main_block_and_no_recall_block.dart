import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the opened session has the main block {'posture'} and no recall
/// block
Future<void> theOpenedSessionHasTheMainBlockAndNoRecallBlock(
  WidgetTester tester,
  String main,
) async {
  final sessions = await getIt<SessionRecordRepository>().all();
  expect(sessions, hasLength(1));
  expect(sessions.single.mainBlockId, main);
  expect(sessions.single.recallBlockId, isNull);
}
