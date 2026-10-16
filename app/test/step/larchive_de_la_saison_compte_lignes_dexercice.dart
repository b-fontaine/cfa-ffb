import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'archive de la saison compte {1} lignes d'exercice
Future<void> larchiveDeLaSaisonCompteLignesDexercice(
  WidgetTester tester,
  num count,
) async {
  final archive = await getIt<SeasonArchiveRepository>().bySeason(
    TrackingWorld.seasonId,
  );
  expect(archive?.exercises.length ?? 0, count.toInt());
}
