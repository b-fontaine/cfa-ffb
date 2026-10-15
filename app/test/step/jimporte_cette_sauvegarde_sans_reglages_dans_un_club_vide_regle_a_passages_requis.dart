import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage:
///   j'importe cette sauvegarde sans réglages
///   dans un club vide réglé à {3} passages requis
Future<void>
jimporteCetteSauvegardeSansReglagesDansUnClubVideRegleAPassagesRequis(
  WidgetTester tester,
  num passes,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(
    tester,
    world.backupWithoutSettings(2),
    settings: ClubSettings.defaults.copyWith(passesRequired: passes.toInt()),
  );
}
