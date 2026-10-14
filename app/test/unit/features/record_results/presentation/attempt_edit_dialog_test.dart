import 'package:billard_cfa/features/record_results/presentation/ui/attempt_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

/// Ouvre la boîte depuis un bouton, comme la liste des passages le fait.
Future<void> _open(
  WidgetTester tester, {
  int potted = 3,
  int total = 5,
  void Function(int potted, int total)? onSave,
}) async {
  await pumpUi(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AttemptEditDialog(
            studentName: 'Léa',
            exerciseTitle: 'Bloc a · exercise 1',
            attempt: attempt(ref('a', 1), potted: potted, total: total),
            rate: rate(),
            onSave: onSave ?? (_, _) {},
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Le bouton d'icône qui porte [tooltip] (l'info-bulle est son descendant).
IconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  testWidgets('starts with the values of the pass', (tester) async {
    await _open(tester, potted: 2, total: 6);

    expect(find.text('Edit the pass'), findsOneWidget);
    expect(find.text('Léa · Bloc a · exercise 1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('reports the corrected values', (tester) async {
    (int, int)? saved;
    await _open(tester, onSave: (potted, total) => saved = (potted, total));

    await tester.tap(find.byTooltip('More balls potted in the correction'));
    await tester.tap(find.byTooltip('More attempts in the correction'));
    await tester.pump();
    await tester.tap(find.text('Save the correction'));

    expect(saved, (4, 6));
  });

  testWidgets('keeps the attempts at least at those of the sheet', (
    tester,
  ) async {
    await _open(tester);

    expect(
      _button(tester, 'Fewer attempts in the correction').onPressed,
      isNull,
    );
    expect(
      _button(tester, 'More attempts in the correction').onPressed,
      isNotNull,
    );
  });

  testWidgets('lowers the potted balls when the total goes under them', (
    tester,
  ) async {
    (int, int)? saved;
    await _open(
      tester,
      potted: 6,
      total: 6,
      onSave: (potted, total) => saved = (potted, total),
    );

    await tester.tap(find.byTooltip('Fewer attempts in the correction'));
    await tester.pump();
    await tester.tap(find.text('Save the correction'));

    expect(saved, (5, 5));
  });

  testWidgets('says when the total differs from the sheet', (tester) async {
    await _open(tester);

    expect(find.textContaining('More attempts than the sheet'), findsNothing);
    await tester.tap(find.byTooltip('More attempts in the correction'));
    await tester.pump();

    expect(find.textContaining('More attempts than the sheet'), findsOneWidget);
  });

  testWidgets('cancelling closes the box without saving', (tester) async {
    var saved = 0;
    await _open(tester, onSave: (_, _) => saved++);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AttemptEditDialog), findsNothing);
    expect(saved, 0);
  });
}
