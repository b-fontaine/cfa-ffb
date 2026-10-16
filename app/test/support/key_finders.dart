import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widgets dont la clé texte commence par [prefix] (`path-cell-`, …) : les
/// scénarios retrouvent les cases, les lignes et les cellules par la clé que
/// leur donne l'interface, sans dépendre de leur type.
Finder byKeyPrefix(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

/// Clé d'une case du parcours pour l'exercice « puissance 1 ».
Key pathCellKey(String exercise) =>
    ValueKey('path-cell-${exercise.replaceAll(' ', '-')}');
