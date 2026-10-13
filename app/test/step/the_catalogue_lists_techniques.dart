import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue lists {14} techniques
Future<void> theCatalogueListsTechniques(WidgetTester tester, int count) async {
  expect(_keyed('technique:'), findsNWidgets(count));
}

Finder _keyed(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(prefix),
  description: 'widget dont la clé commence par « $prefix »',
);
