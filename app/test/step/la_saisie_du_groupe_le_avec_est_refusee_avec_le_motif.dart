import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';
import '../support/tracking_world.dart';

/// Usage: la saisie du groupe {'Jeunes'} le {'2026-10-12'} avec {'Léa'} est
///   refusée avec le
///   motif {'studentNotInGroup'}
Future<void> laSaisieDuGroupeLeAvecEstRefuseeAvecLeMotif(
  WidgetTester tester,
  String group,
  String date,
  String students,
  String code,
) async {
  final result = await getIt<OpenSession>()(
    groupId: (await GroupOps.groupNamed(group)).id,
    date: TrackingWorld.date(date),
    present: {
      if (students.trim().isNotEmpty)
        for (final name in TrackingWorld.names(students))
          TrackingWorld.studentId(name),
    },
  );
  GroupOps.last = result;
  GroupOps.expectRefused(code);
}
