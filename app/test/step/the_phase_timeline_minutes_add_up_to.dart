import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phase timeline minutes add up to {90}
Future<void> thePhaseTimelineMinutesAddUpTo(
  WidgetTester tester,
  num minutes,
) async {
  final timeline = tester.widget<PhaseTimeline>(find.byType(PhaseTimeline));
  expect(
    timeline.phases.fold<int>(0, (sum, phase) => sum + phase.minutes),
    minutes.toInt(),
  );
  expect(timeline.phases, hasLength(5));
}
