import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'historique de public de {'Hugo'} compte {10} entrées
Future<void> lhistoriqueDePublicDeCompteEntrees(
  WidgetTester tester,
  String student,
  int count,
) async {
  final saved = await getIt<StudentRepository>().byId(
    TrackingWorld.studentId(student),
  );
  expect(saved!.audienceHistory, hasLength(count));
}
