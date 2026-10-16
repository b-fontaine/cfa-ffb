import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the student {'Léa'} leaves the group {'Children group'} on
/// {'2026-10-10'}
///
/// Clôt l'appartenance ouverte : le groupe garde ses séances, plus d'élève.
Future<void> theStudentLeavesTheGroupOn(
  WidgetTester tester,
  String studentName,
  String groupName,
  String date,
) async {
  final student = await UiWorld.studentNamed(studentName);
  await tester.runAsync(() async {
    final repository = getIt<GroupRepository>();
    final group = (await repository.all()).firstWhere(
      (candidate) => candidate.name == groupName,
    );
    await repository.save(
      group.release(studentId: student.id, to: DateTime.parse(date)),
    );
  });
}
