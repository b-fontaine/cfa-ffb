import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Hugo'} a déjà {10} entrées dans son historique de public
Future<void> aDejaEntreesDansSonHistoriqueDePublic(
  WidgetTester tester,
  String student,
  int entries,
) async {
  final repository = getIt<StudentRepository>();
  var current = (await repository.byId(TrackingWorld.studentId(student)))!;
  while (current.audienceHistory.length < entries) {
    current = current.changeAudience(
      current.currentAudience == Audience.children
          ? Audience.adults
          : Audience.children,
      current.audienceHistory.last.effectiveFrom.add(const Duration(days: 30)),
    );
  }
  await repository.save(current);
}
