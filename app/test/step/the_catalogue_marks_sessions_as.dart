import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue marks {1} sessions as {'next'}
Future<void> theCatalogueMarksSessionsAs(
  WidgetTester tester,
  num count,
  String mark,
) async {
  final wanted = JourneyMark.values.byName(mark);
  final marked = tester
      .widgetList<JourneyMarker>(
        find.byType(JourneyMarker, skipOffstage: false),
      )
      .where((marker) => marker.mark == wanted);
  expect(marked, hasLength(count.toInt()), reason: 'marqueurs « $mark »');
}
