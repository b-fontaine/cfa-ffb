import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session title is {'La puissance, session 1/2'}
///
/// Le premier champ de saisie de la page est le titre de la séance.
Future<void> theSessionTitleIs(WidgetTester tester, String title) async {
  final field = tester.widget<TextField>(find.byType(TextField).first);
  expect(field.controller!.text, title);
}
