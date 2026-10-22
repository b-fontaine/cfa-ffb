import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucunMarqueurNeCiteDeleve(WidgetTester tester) async {
  final world = OperationsWorld.current;
  final markers = world.markers();
  expect(markers, isNotEmpty);
  bool mentions(Object? value) => switch (value) {
    String() => value.contains('s-e') || RegExp(r'E\d{3}').hasMatch(value),
    List<Object?>() => value.any(mentions),
    Map<Object?, Object?>() => value.values.any(mentions),
    _ => false,
  };
  for (final entry in markers.entries) {
    expect(mentions(entry.key), isFalse, reason: entry.key);
    expect(mentions(entry.value), isFalse, reason: entry.key);
  }
}
