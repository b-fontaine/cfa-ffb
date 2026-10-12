import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> conservePassagesEnregistres(
  WidgetTester tester,
  String student,
  num count,
) async {
  final attempts = await getIt<AttemptRepository>().forStudent(
    TrackingWorld.studentId(student),
  );
  expect(attempts, hasLength(count.toInt()));
}
