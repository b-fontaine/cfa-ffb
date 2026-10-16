import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phase timeline is above the phase {'welcome'}
Future<void> thePhaseTimelineIsAboveThePhase(
  WidgetTester tester,
  String phase,
) async {
  final section = find.byKey(ValueKey('phase:$phase'));
  expect(section, findsOneWidget);
  expect(
    tester.getBottomLeft(find.byType(PhaseTimeline)).dy,
    lessThanOrEqualTo(tester.getTopLeft(section).dy),
  );
}
