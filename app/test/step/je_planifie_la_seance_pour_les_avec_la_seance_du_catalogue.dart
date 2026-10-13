import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je planifie la séance {'Cours'} pour les {'enfants'} avec la séance
/// du catalogue {'demi-bille-2'}
Future<void> jePlanifieLaSeancePourLesAvecLaSeanceDuCatalogue(
  WidgetTester tester,
  String title,
  String audience,
  String sheetId,
) async {
  await getIt<PlanSession>()(
    title: title,
    audience: TrackingWorld.audience(audience),
    sheetId: SheetId(sheetId),
  );
}
