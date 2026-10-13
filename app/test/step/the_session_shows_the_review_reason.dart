import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'demi-bille-1'} shows the review reason {'gameLink'}
Future<void> theSessionShowsTheReviewReason(
  WidgetTester tester,
  String id,
  String reason,
) async {
  expect(find.byKey(ValueKey('review:$id:$reason')), findsOneWidget);
}
