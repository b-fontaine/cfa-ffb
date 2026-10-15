import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the setting {'Days before a backup reminder'} shows {30}
Future<void> theSettingShows(
  WidgetTester tester,
  String label,
  num value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is CounterField && widget.label == label,
  );
  expect(field, findsOneWidget, reason: 'réglage « $label » introuvable');
  expect(tester.widget<CounterField>(field).value, value.toInt());
}
