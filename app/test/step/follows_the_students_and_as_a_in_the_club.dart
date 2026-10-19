import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: {'anne@example.org'} follows the students {'Léa'} and {'Tom'} as a
/// {'guardian'} in the club {'Test club'}
///
/// Un parent de deux élèves : un seul compte lié aux deux fiches.
Future<void> followsTheStudentsAndAsAInTheClub(
  WidgetTester tester,
  String email,
  String first,
  String second,
  String role,
  String club,
) => FamilyWorld.follow(
  tester,
  email: email,
  role: role,
  club: club,
  students: [first, second],
);
