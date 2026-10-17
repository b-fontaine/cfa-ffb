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

  test('the invitation code bounds are the ones of the rules', () {
    expect(
      rules,
      contains('[A-Z2-7]{$minInvitationCodeLength,$maxInvitationCodeLength}'),
    );
  });
}
