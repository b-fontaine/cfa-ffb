import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Léa'} has every block acquired on {'2026-10-12'}
///
/// Marque chaque bloc du catalogue acquis par le vrai cas d'usage.
Future<void> hasEveryBlockAcquiredOn(
  WidgetTester tester,
  String name,
  String date,
) async {
  await UiWorld.prepare(tester);
  final catalogue = await tester.runAsync(
    () => getIt<CatalogueRepository>().load(),
  );
  for (final block in catalogue!.blocks) {
    await UiWorld.seedAcquired(tester, name, block.id, DateTime.parse(date));
  }
}
