import 'dart:io';

import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les bornes du client sont celles des règles Firestore : un client qui
/// enverrait plus long serait refusé par le serveur, un client plus strict
/// refuserait ce que le serveur accepte.
void main() {
  late String rules;

  setUpAll(() {
    rules = File('../firestore.rules').readAsStringSync();
  });

  test('the club name limit is the one of the rules', () {
    expect(
      rules,
      contains('d.name.size() >= 1 && d.name.size() <= $maxClubNameLength'),
    );
  });

  test('the display name limit is the one of the rules', () {
    expect(
      rules,
      contains(
        'd.displayName.size() >= 1 && d.displayName.size() <= '
        '$maxDisplayNameLength',
      ),
    );
  });

  test('the first name limit is the one of the rules', () {
    expect(
      rules,
      contains(
        'd.firstName.size() >= 1 && d.firstName.size() <= $maxFirstNameLength',
      ),
    );
  });

  test('the audience history bound is the one of the rules', () {
    expect(rules, contains('d.audienceHistory.size() <= $maxAudienceHistory'));
  });

  test('the invitation code bounds are the ones of the rules', () {
    expect(
      rules,
      contains('[A-Z2-7]{$minInvitationCodeLength,$maxInvitationCodeLength}'),
    );
  });

  test(
    'the identifier and exercise number bounds are the ones of the rules',
    () {
      expect(rules, contains('d.groupId.size() <= $maxIdentifierLength'));
      expect(rules, contains('d.seasonId.size() <= $maxIdentifierLength'));
      expect(rules, contains('d.studentId.size() <= $maxIdentifierLength'));
      expect(
        rules,
        contains("presInt(d, 'exerciseNumber', 0, $maxExerciseNumber)"),
      );
    },
  );

  test('the date text of the client is the one accepted by the rules', () {
    // La règle écrit `\\` pour un `\` ; le motif du client est le même texte.
    final ruleRegex = RegExp(r"v\.matches\('([^']+)'\)")
        .firstMatch(rules.substring(rules.indexOf('function isoText')))!
        .group(1)!;
    expect(isoDateText.pattern, ruleRegex);
  });
}
