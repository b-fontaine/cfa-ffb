import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'archive de la saison compte {3} séances, {3} présences et {2}
///   passages pour les
///   {'enfants'}
Future<void> larchiveDeLaSaisonCompteSeancesPresencesEtPassagesPourLes(
  WidgetTester tester,
  num sessions,
  num presences,
  num attempts,
  String audience,
) async {
  final archive = await getIt<SeasonArchiveRepository>().bySeason(
    TrackingWorld.seasonId,
  );
  expect(archive, isNotNull);
  final block = archive!.audienceOf(TrackingWorld.audience(audience));
  expect(block, isNotNull);
  expect(block!.sessionCount, sessions.toInt());
  expect(block.presenceCount, presences.toInt());
  expect(block.attemptCount, attempts.toInt());
}
