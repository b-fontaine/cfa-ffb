import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the students {'Léa'} and {'Tom'} are still in the club
///
/// Les fiches restent au club : la suppression d'un compte n'en touche aucune.
Future<void> theStudentsAndAreStillInTheClub(
  WidgetTester tester,
  String first,
  String second,
) async {
  await tester.runAsync(() async {
    for (final name in {first, second}) {
      expect((await UiWorld.studentNamed(name)).firstName, name);
    }
  });
}
