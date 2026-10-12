import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the message with a decorative icon', (tester) async {
    await pumpUi(tester, const EmptyState(message: 'Nothing here yet.'));

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('shows a custom icon', (tester) async {
    await pumpUi(
      tester,
      const EmptyState(message: 'No students.', icon: Icons.groups_outlined),
    );

    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);
  });

  testWidgets('shows an optional action', (tester) async {
    await pumpUi(
      tester,
      const EmptyState(message: 'Empty', action: Text('Add')),
    );

    expect(find.text('Add'), findsOneWidget);
  });
}
