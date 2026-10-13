import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the cue behind the white ball
Future<void> iSeeTheCueBehindTheWhiteBall(WidgetTester tester) async {
  expect(find.byType(BilliardCue), findsOneWidget);
}
