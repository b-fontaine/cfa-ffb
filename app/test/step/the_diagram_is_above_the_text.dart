import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the diagram is above the text {'Set-up: …'}
///
/// Le schéma (et ses commandes) précède le texte de l'étape : il est la
/// première chose lue, avant la mise en place et la consigne.
Future<void> theDiagramIsAboveTheText(WidgetTester tester, String text) async {
  final media = tester.getRect(find.byKey(const ValueKey('step-media')));
  final line = tester.getRect(find.textContaining(text));
  expect(media.bottom, lessThanOrEqualTo(line.top + 0.5));
}
