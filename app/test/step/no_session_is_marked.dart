import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no session is marked
Future<void> noSessionIsMarked(WidgetTester tester) async {
  expect(find.byType(JourneyMarker), findsNothing);
}
