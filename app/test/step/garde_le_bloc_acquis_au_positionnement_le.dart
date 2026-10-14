import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> gardeLeBlocAcquisAuPositionnementLe(
  WidgetTester tester,
  String student,
  String block,
  String date,
) async {
  final acquired = await getIt<AcquisitionRepository>().forStudent(
    TrackingWorld.studentId(student),
  );

  expect(acquired.map((a) => a.blockId), [block]);
  expect(acquired.single.date, TrackingWorld.date(date));
}
