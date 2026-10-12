import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lhistoriqueDePublicDeContientPuis(
  WidgetTester tester,
  String student,
  String first,
  String second,
) async {
  final saved = await getIt<StudentRepository>().byId(
    TrackingWorld.studentId(student),
  );
  final history = saved!.audienceHistory.map(
    (change) => TrackingWorld.audienceLabel(change.audience),
  );
  expect(history, [first, second]);
}
