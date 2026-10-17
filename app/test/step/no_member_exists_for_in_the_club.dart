import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no member exists for {'new@example.org'} in the club {'Test club'}
Future<void> noMemberExistsForInTheClub(
  WidgetTester tester,
  String email,
  String club,
) async {
  final account = UiWorld.auth.accountOf(email)!;
  expect(
    UiWorld.documents.read(
      'clubs/${UiWorld.clubIdOf(club).value}/members/${account.id.value}',
    ),
    isNull,
  );
}
