import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: le club compte {1} séances planifiées
Future<void> leClubCompteSeancesPlanifiees(
  WidgetTester tester,
  num count,
) async {
  expect(await getIt<SessionRepository>().getAll(), hasLength(count.toInt()));
}
