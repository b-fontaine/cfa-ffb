import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the remembered club of {'coach@example.org'} is {'Club Lyon'}
Future<void> theRememberedClubOfIs(
  WidgetTester tester,
  String email,
  String club,
) async {
  final account = UiWorld.auth.accountOf(email)!;
  final remembered = await getIt<ActiveClubMemory>().read(account.id);
  expect(remembered?.clubName, club);
}
