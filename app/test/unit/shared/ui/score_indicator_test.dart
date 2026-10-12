import 'package:billard_cfa/shared/ui/score_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the score as x/n text', (tester) async {
    await pumpUi(tester, const ScoreIndicator(score: 3, total: 5));

    expect(find.text('3/5'), findsOneWidget);
  });

  testWidgets('draws one dot per attempt, filled up to the score', (
    tester,
  ) async {
    await pumpUi(tester, const ScoreIndicator(score: 2, total: 4));

    expect(find.byKey(const ValueKey('score-dot-filled')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('score-dot-empty')), findsNWidgets(2));
  });

  testWidgets('exposes a spoken label in English', (tester) async {
    await pumpUi(tester, const ScoreIndicator(score: 3, total: 5));

    expect(find.bySemanticsLabel('3 out of 5'), findsOneWidget);
  });

  testWidgets('exposes a spoken label in French', (tester) async {
    await pumpUi(
      tester,
      const ScoreIndicator(score: 3, total: 5),
      locale: const Locale('fr'),
    );

    expect(find.bySemanticsLabel('3 sur 5'), findsOneWidget);
  });

  testWidgets('accepts a zero score', (tester) async {
    await pumpUi(tester, const ScoreIndicator(score: 0, total: 3));

    expect(find.byKey(const ValueKey('score-dot-filled')), findsNothing);
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('accepts a perfect score', (tester) async {
    await pumpUi(tester, const ScoreIndicator(score: 3, total: 3));

    expect(find.byKey(const ValueKey('score-dot-empty')), findsNothing);
    expect(find.text('3/3'), findsOneWidget);
  });

  test('rejects a score above the total', () {
    expect(() => ScoreIndicator(score: 4, total: 3), throwsAssertionError);
  });

  test('rejects a negative score', () {
    expect(() => ScoreIndicator(score: -1, total: 3), throwsAssertionError);
  });

  test('rejects an empty total', () {
    expect(() => ScoreIndicator(score: 0, total: 0), throwsAssertionError);
  });
}
