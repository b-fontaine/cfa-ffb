import 'package:flutter_test/flutter_test.dart';

/// Usage: the guide timer has run {541} seconds
///
/// Lance le minuteur du guide, laisse passer [seconds] secondes (horloge de
/// test) puis le met en pause : aucun minuteur ne reste en attente. Les
/// secondes s'ajoutent d'un appel à l'autre.
Future<void> theGuideTimerHasRunSeconds(
  WidgetTester tester,
  num seconds,
) async {
  await tester.tap(find.byTooltip('Start the timer'));
  await tester.pump();
  await tester.pump(Duration(seconds: seconds.toInt()));
  await tester.tap(find.byTooltip('Pause the timer'));
  await tester.pumpAndSettle();
}
