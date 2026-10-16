import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phase timeline is shown below the text
/// {'90 min in total (approximate)'}
Future<void> thePhaseTimelineIsShownBelowTheText(
  WidgetTester tester,
  String text,
) async {
  final timeline = find.byType(PhaseTimeline);
  expect(timeline, findsOneWidget);
  final anchor = find.text(text);
  expect(anchor, findsOneWidget);
  expect(
    tester.getTopLeft(timeline).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(anchor).dy),
    reason: 'la frise doit être sous « $text »',
  );
}
