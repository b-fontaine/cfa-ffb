import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Widget _field({
  int value = 3,
  int min = 0,
  int max = 5,
  ValueChanged<int>? onChanged,
}) => CounterField(
  label: 'Balls potted',
  value: value,
  min: min,
  max: max,
  onChanged: onChanged ?? (_) {},
  decreaseTooltip: 'Fewer',
  increaseTooltip: 'More',
);

void main() {
  testWidgets('shows the label and the value', (tester) async {
    await pumpUi(tester, _field());

    expect(find.text('Balls potted'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('reports the next and previous values', (tester) async {
    final values = <int>[];
    await pumpUi(tester, _field(onChanged: values.add));

    await tester.tap(find.byTooltip('More'));
    await tester.tap(find.byTooltip('Fewer'));

    expect(values, [4, 2]);
  });

  testWidgets('disables the buttons at the bounds', (tester) async {
    await pumpUi(tester, _field(value: 0));
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );

    await pumpUi(tester, _field(value: 5));
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
  });

  testWidgets('buttons are at least 48 dp', (tester) async {
    await pumpUi(tester, _field());

    final size = tester.getSize(find.byTooltip('More'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('announces the label with the value', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _field());

    expect(
      tester.getSemantics(find.byType(CounterField)),
      matchesSemantics(label: 'Balls potted', value: '3'),
    );
    handle.dispose();
  });
}
