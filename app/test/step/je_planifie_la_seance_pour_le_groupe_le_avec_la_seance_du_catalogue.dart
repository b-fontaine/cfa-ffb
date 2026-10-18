import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je planifie la séance {'Cours'} pour le groupe {'Jeunes'} le
/// {'2026-10-19'} avec la séance du catalogue {'demi-bille-2'}
Future<void> jePlanifieLaSeancePourLeGroupeLeAvecLaSeanceDuCatalogue(
  WidgetTester tester,
  String title,
  String group,
  String date,
  String sheetId,
) async {
  final groupId = TrackingWorld.groupId(group);
  await getIt<PlanSession>()(
    title: title,
    date: TrackingWorld.date(date),
    sheetId: SheetId(sheetId),
    groupId: groupId,
  );
}
