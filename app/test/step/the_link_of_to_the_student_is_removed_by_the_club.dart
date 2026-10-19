import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: the link of {'anne@example.org'} to the student {'Tom'} is removed by
/// the club
///
/// Le club retire **une seule** fiche du `member` du compte : les règles ne
/// laissent plus lire cette fiche, les autres restent lisibles.
Future<void> theLinkOfToTheStudentIsRemovedByTheClub(
  WidgetTester tester,
  String email,
  String student,
) => FamilyWorld.removeLink(tester, email, student);
