import 'package:flutter_test/flutter_test.dart';

import '../support/invitation_world.dart';
import '../support/ui_world.dart';

/// Usage: the invitation code concerns the student {'Léa'}
///
/// L'invitation affichée est liée à la fiche de l'élève et à son groupe.
Future<void> theInvitationCodeConcernsTheStudent(
  WidgetTester tester,
  String name,
) async {
  final student = await UiWorld.studentNamed(name);
  final stored = UiWorld.documents.read(
    'invitations/${shownInvitationCode(tester)}',
  )!;
  expect(stored['studentIds'], [student.id.value]);
  expect(stored['groupIds'], isNotEmpty);
  // La fiche liée a été publiée côté serveur avec son prénom seulement.
  final published = UiWorld.documents.read(
    'clubs/${UiWorld.clubIdOf(UiWorld.defaultClub).value}/students/${student.id.value}',
  );
  expect(published, isNotNull);
  expect(published!['firstName'], name);
  expect(published.keys, containsAll(['firstName', 'audience', 'groupIds']));
}
