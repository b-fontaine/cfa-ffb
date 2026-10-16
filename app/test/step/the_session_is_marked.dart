import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'posture-1'} is marked {'done'}
///
/// `done`, `next` ou `upcoming`.
Future<void> theSessionIsMarked(
  WidgetTester tester,
  String id,
  String mark,
) async {
  final marker = find.byKey(ValueKey('mark:$id'));
  expect(marker, findsOneWidget, reason: 'aucun marqueur sur $id');
  expect(
    tester.widget<JourneyMarker>(marker).mark,
    JourneyMark.values.byName(mark),
  );
}
