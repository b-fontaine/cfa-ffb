import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation {'GUARDIANCODE'} invites a {'guardian'} to the club
/// {'Test club'} for the student {'Léa'}
///
/// Invitation valable liée à la fiche de l'élève et à ses groupes du jour.
Future<void> theInvitationInvitesAToTheClubForTheStudent(
  WidgetTester tester,
  String code,
  String role,
  String club,
  String studentName,
) async {
  await UiWorld.prepare(tester);
  final student = await UiWorld.studentNamed(studentName);
  UiWorld.seedInvitation(
    code: code,
    club: club,
    role: role,
    studentIds: [student.id.value],
    groupIds: await UiWorld.currentGroupIdsOf(student.id),
  );
}
