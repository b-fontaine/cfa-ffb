import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the section {'Frequent mistakes (instructor)'} is {'folded'}
///
/// Une section repliable est `folded` (son contenu n'est pas construit) ou
/// `open`.
Future<void> theSectionIs(
  WidgetTester tester,
  String title,
  String state,
) async {
  final tile = find.ancestor(
    of: find.text(title),
    matching: find.byType(ExpansionTile),
  );
  expect(tile, findsOneWidget, reason: 'section « $title » absente');
  final first = tester.widget<ExpansionTile>(tile).children.first;
  final built = find.byWidget(first).evaluate().isNotEmpty;
  expect(built, state == 'open', reason: 'section « $title » : $state attendu');
}
