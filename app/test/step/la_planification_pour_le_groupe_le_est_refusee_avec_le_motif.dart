import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';
import '../support/tracking_world.dart';

/// Usage: la planification pour le groupe {'Jeunes'} le {'2026-10-12'} est
///   refusée avec le motif
///   {'seasonClosed'}
Future<void> laPlanificationPourLeGroupeLeEstRefuseeAvecLeMotif(
  WidgetTester tester,
  String group,
  String date,
  String code,
) async {
  try {
    await getIt<PlanSession>()(
      title: 'Posture',
      date: TrackingWorld.date(date),
      audience: Audience.children,
      groupId: (await GroupOps.groupNamed(group)).id,
    );
    fail('la planification aurait dû être refusée');
  } on InvariantViolation catch (violation) {
    expect(violation.code.name, code);
  }
}
