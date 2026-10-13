import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue lists {29} sessions
Future<void> theCatalogueListsSessions(WidgetTester tester, int count) async {
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('sheet:'),
      description: 'ligne de séance',
    ),
    findsNWidgets(count),
  );
}
