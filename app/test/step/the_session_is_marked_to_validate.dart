import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motifs qui rendent une séance « à valider » (`ReviewReason.counts`).
const _counted = ['game', 'exercise', 'initiation', 'recall'];

/// Usage: the session {'posture-1'} is marked to validate
Future<void> theSessionIsMarkedToValidate(
  WidgetTester tester,
  String id,
) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  final marked = [
    for (final reason in _counted)
      if (find.byKey(ValueKey('review:$id:$reason')).evaluate().isNotEmpty)
        reason,
  ];
  expect(marked, isNotEmpty);
}
