import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Future<void> _open(WidgetTester tester, ValueNotifier<bool?> result) async {
  await pumpUi(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async => result.value = await showConfirmDialog(
          context,
          title: 'Sure?',
          message: 'Really.',
        ),
        child: const Text('ask'),
      ),
    ),
  );
  await tester.tap(find.text('ask'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title and the message', (tester) async {
    await _open(tester, ValueNotifier<bool?>(null));

    expect(find.text('Sure?'), findsOneWidget);
    expect(find.text('Really.'), findsOneWidget);
  });

  testWidgets('returns true on confirm', (tester) async {
    final result = ValueNotifier<bool?>(null);
    await _open(tester, result);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result.value, isTrue);
  });

  testWidgets('returns false on cancel', (tester) async {
    final result = ValueNotifier<bool?>(null);
    await _open(tester, result);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result.value, isFalse);
  });

  testWidgets('returns false when dismissed', (tester) async {
    final result = ValueNotifier<bool?>(null);
    await _open(tester, result);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(result.value, isFalse);
  });
}
