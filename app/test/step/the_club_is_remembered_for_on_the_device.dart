import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club {'Club Lyon'} is remembered for {'coach@example.org'} on
/// the device
///
/// Le club actif retenu par un lancement précédent (rôle d'enseignant, sauf si
/// le compte a une appartenance connue pour ce club).
Future<void> theClubIsRememberedForOnTheDevice(
  WidgetTester tester,
  String club,
  String email,
) async {
  await UiWorld.prepare(tester);
  final account = UiWorld.auth.accountOf(email)!;
  final known = await getIt<MembershipsSource>().membershipsOf(account.id);
  final membership = known.firstWhere(
    (m) => m.clubName == club,
    orElse: () => UiWorld.membership(club, 'director'),
  );
  await getIt<ActiveClubMemory>().write(account.id, membership);
}
