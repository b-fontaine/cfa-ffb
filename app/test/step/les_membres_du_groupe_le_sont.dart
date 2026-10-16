import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';
import '../support/tracking_world.dart';

/// Usage: les membres du groupe {'Jeunes'} le {'2026-10-12'} sont {'Léa, Théo'}
Future<void> lesMembresDuGroupeLeSont(
  WidgetTester tester,
  String group,
  String date,
  String names,
) async {
  final target = await GroupOps.groupNamed(group);
  final students = await getIt<StudentRepository>().all();
  final members = target.membersOn(TrackingWorld.date(date));
  expect(
    [
      for (final id in members)
        students.firstWhere((student) => student.id == id).firstName,
    ]..sort(),
    names.trim().isEmpty ? <String>[] : (TrackingWorld.names(names)..sort()),
  );
}
