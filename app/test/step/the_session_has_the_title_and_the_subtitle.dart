import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'demi-bille-1'} has the title {'Le partage du gâteau'}
/// and the subtitle {'Session 1/2 · Quantité demi-bille'}
///
/// Lit le texte réellement affiché en titre et en sous-titre de la ligne.
Future<void> theSessionHasTheTitleAndTheSubtitle(
  WidgetTester tester,
  String id,
  String title,
  String subtitle,
) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  expect(
    tester.widget<Text>(find.byKey(ValueKey('sheet-title:$id'))).data,
    title,
  );
  expect(
    tester.widget<Text>(find.byKey(ValueKey('sheet-subtitle:$id'))).data,
    subtitle,
  );
}
