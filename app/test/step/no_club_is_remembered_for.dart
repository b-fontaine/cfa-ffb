import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no club is remembered for {'coach@example.org'}
Future<void> noClubIsRememberedFor(WidgetTester tester, String email) async {
  final account = UiWorld.auth.accountOf(email)!;
  expect(await getIt<ActiveClubMemory>().read(account.id), isNull);
  expect(UiWorld.store.entries, isNot(contains('active_club.${account.id}')));
}
