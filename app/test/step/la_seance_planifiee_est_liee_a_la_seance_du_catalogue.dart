import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: la séance planifiée {'Cours'} est liée à la séance du catalogue
/// {'demi-bille-2'}
Future<void> laSeancePlanifieeEstLieeALaSeanceDuCatalogue(
  WidgetTester tester,
  String title,
  String sheetId,
) async {
  final sessions = await getIt<SessionRepository>().getAll();
  final session = sessions.singleWhere((s) => s.title == title);
  expect(session.sheetId?.value, sheetId);
}
