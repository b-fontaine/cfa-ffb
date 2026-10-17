import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/review_session/domain/set_session_tags.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je pose les étiquettes {'tooLong,toRedo'} sur la séance saisie du
/// groupe {'Jeunes'} le {'2026-10-19'}
///
/// Passe par le cas d'usage du bilan (le même que l'écran).
Future<void> jePoseLesEtiquettesSurLaSeanceSaisieDuGroupeLe(
  WidgetTester tester,
  String codes,
  String group,
  String date,
) async {
  final record = (await TrackingWorld.recordsOn(group, date)).single;
  TrackingWorld.valueOf(
    await getIt<SetSessionTags>()(record.id, TrackingWorld.tags(codes)),
  );
}
