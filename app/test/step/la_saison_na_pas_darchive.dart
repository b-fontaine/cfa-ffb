import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la saison n'a pas d'archive
Future<void> laSaisonNaPasDarchive(WidgetTester tester) async {
  expect(
    await getIt<SeasonArchiveRepository>().bySeason(TrackingWorld.seasonId),
    isNull,
  );
}
