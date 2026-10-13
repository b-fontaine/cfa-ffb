import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the content cannot be edited
///
/// Lecture seule : ni champ de saisie, ni case, ni bouton de modification ou
/// de suppression.
Future<void> theContentCannotBeEdited(WidgetTester tester) async {
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(TextFormField), findsNothing);
  expect(find.byType(Checkbox), findsNothing);
  expect(find.byType(Switch), findsNothing);
  expect(find.byType(Radio<Object>), findsNothing);
  expect(find.byType(Slider), findsNothing);
  for (final label in const ['Edit', 'Delete', 'Remove', 'Modifier']) {
    expect(find.textContaining(label), findsNothing, reason: label);
  }
}
