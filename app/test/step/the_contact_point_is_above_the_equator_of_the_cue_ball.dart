import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the contact point is above the equator of the cue ball
Future<void> theContactPointIsAboveTheEquatorOfTheCueBall(
  WidgetTester tester,
) async {
  final cue = find.byType(BilliardBall).first;
  final contact = find.byKey(const ValueKey('contact-height-contact'));
  expect(contact, findsOneWidget);
  expect(
    tester.getCenter(contact).dy,
    lessThan(tester.getCenter(cue).dy),
    reason: 'the contact marker is above the centre line of the cue ball',
  );
}
