import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jeDemandeLaSeanceSuggereeDuGroupePour(
  WidgetTester tester,
  String group,
  String students,
) async {
  TrackingWorld.current.plan = TrackingWorld.valueOf(
    await getIt<SuggestSession>()(
      groupId: TrackingWorld.groupId(group),
      expectedStudents: {
        for (final name in TrackingWorld.names(students))
          TrackingWorld.studentId(name),
      },
    ),
  );
}
