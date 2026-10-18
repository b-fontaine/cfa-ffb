import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je planifie la séance suivante le {'2026-10-19'}
Future<void> jePlanifieLaSeanceSuivanteLe(
  WidgetTester tester,
  String date,
) async {
  final world = TrackingWorld.current;
  final review = TrackingWorld.valueOf(world.reviewResult);
  final sheet = world.nextSheet.sheet!.option;
  world.planResult = await runGuarded(
    () => getIt<PlanSession>()(
      title: sheet.title,
      date: TrackingWorld.date(date),
      sheetId: sheet.id,
      groupId: review.record.groupId,
    ),
  );
}
