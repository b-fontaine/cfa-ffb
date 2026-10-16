import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la saison compte les groupes {'Jeunes, Mercredi'}
Future<void> laSaisonCompteLesGroupes(WidgetTester tester, String names) async {
  final groups = await getIt<GroupRepository>().all();
  expect(
    [for (final group in groups) group.name]..sort(),
    TrackingWorld.names(names)..sort(),
  );
}
