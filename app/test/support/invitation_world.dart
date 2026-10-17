import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/invitation_code_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le code d'invitation affiché à l'écran (sans tirets), lu dans le texte
/// clé [invitationCodeKey] ; échoue s'il n'y en a pas un exactement.
String shownInvitationCode(WidgetTester tester) {
  final finder = find.byKey(invitationCodeKey);
  expect(finder, findsOneWidget, reason: "aucun code d'invitation affiché");
  final text = tester.widget<SelectableText>(finder).data!;
  final code = InvitationCode.tryParse(text);
  expect(code, isNotNull, reason: "code d'invitation illisible : $text");
  return code!.value;
}
