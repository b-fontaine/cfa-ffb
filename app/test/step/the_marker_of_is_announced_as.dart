import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the marker of {'posture-1'} is announced as {'Done'}
Future<void> theMarkerOfIsAnnouncedAs(
  WidgetTester tester,
  String id,
  String label,
) async {
  final marker = find.byKey(ValueKey('mark:$id'));
  expect(marker, findsOneWidget);
  final handle = tester.ensureSemantics();
  expect(tester.getSemantics(marker).label, contains(label));
  handle.dispose();
}
