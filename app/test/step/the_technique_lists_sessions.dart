import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the technique {'demi-bille'} lists {2} sessions
///
/// Les lignes de séance d'une technique portent la clé `sheet:<technique>-<k>`.
Future<void> theTechniqueListsSessions(
  WidgetTester tester,
  String technique,
  int count,
) async {
  final pattern = RegExp('^sheet:${RegExp.escape(technique)}-\\d+\$');
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          pattern.hasMatch((widget.key! as ValueKey<String>).value),
      description: 'séances de la technique $technique',
    ),
    findsNWidgets(count),
  );
}
