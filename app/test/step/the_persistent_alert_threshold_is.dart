import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the persistent alert threshold is {3}
///
/// Les règles courantes ont un seuil d'alerte persistante plus bas : relever
/// le seuil d'alerte au-dessus est refusé par `RulesConfig` (aucune
/// exception à l'écran, un message).
Future<void> thePersistentAlertThresholdIs(
  WidgetTester tester,
  num threshold,
) async {
  await UiWorld.prepare(tester);
  final store = getIt<RulesStore>();
  // Une règle qui n'est pas un réglage du club : elle fait partie de la base,
  // que le rechargement des réglages d'un club conserve.
  store.base = store.base.copyWith(persistentAlertThreshold: threshold.toInt());
  store.current = store.current.copyWith(
    persistentAlertThreshold: threshold.toInt(),
  );
}
