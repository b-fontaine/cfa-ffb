import 'package:billard_cfa/features/manage_groups/presentation/ui/group_form_dialog.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

void main() {
  GroupFormResult? result;
  var closed = false;

  Future<void> open(WidgetTester tester, {required bool creating}) async {
    result = null;
    closed = false;
    await pumpUi(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showGroupFormDialog(
              context,
              creating: creating,
              initialName: creating ? '' : 'Wednesday',
            );
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('creating asks for a name and an audience', (tester) async {
    await open(tester, creating: true);

    expect(find.text('New group'), findsOneWidget);
    expect(find.text('Children'), findsOneWidget);
    expect(find.text('Adults'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('group-name')), ' Soir ');
    await tester.tap(find.text('Adults'));
    await tester.tap(find.text('Create the group'));
    await tester.pumpAndSettle();

    expect(result, (name: 'Soir', audience: Audience.adults));
  });

  testWidgets('renaming shows the name only, already filled in', (
    tester,
  ) async {
    await open(tester, creating: false);

    expect(find.text('Rename the group'), findsOneWidget);
    expect(find.text('Children'), findsNothing);
    expect(find.text('Wednesday'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('group-name')), 'Friday');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Friday');
  });

  testWidgets('a blank name keeps the dialog open', (tester) async {
    await open(tester, creating: true);

    await tester.enterText(find.byKey(const ValueKey('group-name')), '   ');
    await tester.tap(find.text('Create the group'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.text('New group'), findsOneWidget);
  });

  testWidgets('cancelling returns nothing', (tester) async {
    await open(tester, creating: true);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });
}
