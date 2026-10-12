import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lePublicCourantDeEst(
  WidgetTester tester,
  String student,
  String audience,
) async {
  final saved = await getIt<StudentRepository>().byId(
    TrackingWorld.studentId(student),
  );
  expect(TrackingWorld.audienceLabel(saved!.currentAudience), audience);
}
