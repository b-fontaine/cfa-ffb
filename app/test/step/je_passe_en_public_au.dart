import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jePasseEnPublicAu(
  WidgetTester tester,
  String student,
  String audience,
  String date,
) async {
  TrackingWorld.current.audienceOutcome = TrackingWorld.valueOf(
    await getIt<ChangeAudience>()(
      studentId: TrackingWorld.studentId(student),
      audience: TrackingWorld.audience(audience),
      effectiveFrom: TrackingWorld.date(date),
    ),
  );
}
