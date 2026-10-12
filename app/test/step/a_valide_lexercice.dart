import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/track_progress/domain/get_exercise_curve.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aValideLexercice(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  // Le chargement du catalogue est de l'E/S réelle : hors du faux temps.
  final curve = await tester.runAsync(
    () => getIt<GetExerciseCurve>()(
      studentId: TrackingWorld.studentId(student),
      exercise: TrackingWorld.exercise(exercise),
    ),
  );
  expect(TrackingWorld.valueOf(curve!).passesToValidation, isNotNull);
}
