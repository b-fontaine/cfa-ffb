import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/track_progress/domain/get_exercise_curve.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jouvreLaCourbeDePour(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  TrackingWorld.current.curve = TrackingWorld.valueOf(
    await getIt<GetExerciseCurve>()(
      studentId: TrackingWorld.studentId(student),
      exercise: TrackingWorld.exercise(exercise),
    ),
  );
}
