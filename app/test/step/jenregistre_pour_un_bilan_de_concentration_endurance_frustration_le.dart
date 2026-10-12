import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/assess_maturity/domain/record_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jenregistrePourUnBilanDeConcentrationEnduranceFrustrationLe(
  WidgetTester tester,
  String student,
  num concentration,
  num endurance,
  num frustration,
  String date,
) async {
  TrackingWorld.current.assessment = TrackingWorld.valueOf(
    await getIt<RecordAssessment>()(
      studentId: TrackingWorld.studentId(student),
      date: TrackingWorld.date(date),
      today: TrackingWorld.today,
      concentration: concentration.toInt(),
      endurance: endurance.toInt(),
      frustration: frustration.toInt(),
    ),
  );
}
