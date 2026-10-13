import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motifs qui rendent une séance « à valider » (`ReviewReason.counts`).
const _counted = ['game', 'exercise', 'initiation', 'recall'];

/// Usage: the session {'demi-bille-1'} is not marked to validate
Future<void> theSessionIsNotMarkedToValidate(
  WidgetTester tester,
  String id,
) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  for (final reason in _counted) {
    expect(find.byKey(ValueKey('review:$id:$reason')), findsNothing);
  }
}
