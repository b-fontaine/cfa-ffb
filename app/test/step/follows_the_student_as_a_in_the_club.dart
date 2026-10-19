import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in
/// the club {'Test club'}
///
/// Le compte (créé, adresse vérifiée) est parent ou élève de cette fiche ; ses
/// groupes sont ceux où l'élève est membre aujourd'hui (comme à l'invitation).
Future<void> followsTheStudentAsAInTheClub(
  WidgetTester tester,
  String email,
  String student,
  String role,
  String club,
) => FamilyWorld.follow(
  tester,
  email: email,
  role: role,
  club: club,
  students: [student],
);
