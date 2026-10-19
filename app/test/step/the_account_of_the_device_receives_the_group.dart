import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the account of the device receives the group {'Children group'}
///
/// Un autre appareil ajoute le groupe au `member` du compte de l'appareil : le
/// rôle et le club restent les mêmes, seul le périmètre change. L'appareil
/// relit ses clubs (`AuthCubit.refresh`, comme après un renommage), ce qui
/// ferme les flux épinglés à l'ancien périmètre : l'écran doit se réabonner.
Future<void> theAccountOfTheDeviceReceivesTheGroup(
  WidgetTester tester,
  String groupName,
) async {
  final groups = await UiWorld.seedGraph<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  final account = UiWorld.auth.accountOf(UiWorld.defaultEmail)!;
  final path =
      'clubs/${UiWorld.clubIdOf(UiWorld.defaultClub).value}/members/'
      '${account.id.value}';
  final stored = UiWorld.documents.read(path)!;
  UiWorld.documents.seed(path, {
    ...stored,
    'groupIds': [group.id.value],
  });
  await tester.runAsync(getIt<AuthCubit>().refresh);
  await UiWorld.settle(tester);
}
