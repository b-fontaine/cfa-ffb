import 'package:billard_cfa/shared/ui/student_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the name, the detail and one icon per status', (
    tester,
  ) async {
    const icons = {
      StudentChipStatus.todo: Icons.radio_button_unchecked,
      StudentChipStatus.missed: Icons.remove_circle_outline,
      StudentChipStatus.reached: Icons.check_circle_outline,
    };
    for (final MapEntry(key: status, value: icon) in icons.entries) {
      await pumpUi(
        tester,
        StudentChip(
          name: 'Zoé',
          detail: '2/5',
          status: status,
          statusLabel: status.name,
        ),
      );

      expect(find.text('Zoé'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
    }
  });

  testWidgets('is at least 48 dp high and never clips a long name', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: StudentChip(
          name: 'Marie-Charlotte de la Fontaine-Beauregard',
          status: StudentChipStatus.todo,
          statusLabel: 'todo',
          maxWidth: 120,
        ),
      ),
    );

    final size = tester.getSize(find.byType(StudentChip));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, lessThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces the name and the status as one label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const StudentChip(
        name: 'Zoé',
        status: StudentChipStatus.reached,
        statusLabel: 'reached',
        semanticsLabel: 'Zoé, 3 of 5, reached',
      ),
    );

    expect(find.bySemanticsLabel('Zoé, 3 of 5, reached'), findsOneWidget);
    handle.dispose();
  });
}
