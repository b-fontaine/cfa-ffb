import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/group_choice_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  const choices = [
    GroupChoice(GroupId('a'), 'Wednesday'),
    GroupChoice(GroupId('b'), 'Saturday'),
  ];

  testWidgets('lists every group with a title and a hint', (tester) async {
    await pumpUi(
      tester,
      GroupChoicePicker(choices: choices, selected: null, onChanged: (_) {}),
    );

    expect(find.text('Which group?'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(
      find.text('Several groups fit: choose one, then confirm again.'),
      findsOneWidget,
    );
  });

  testWidgets('reports the chosen group', (tester) async {
    GroupId? chosen;
    await pumpUi(
      tester,
      GroupChoicePicker(
        choices: choices,
        selected: null,
        onChanged: (id) => chosen = id,
      ),
    );

    await tester.tap(find.text('Saturday'));

    expect(chosen, const GroupId('b'));
  });

  testWidgets('marks the selected group', (tester) async {
    await pumpUi(
      tester,
      GroupChoicePicker(
        choices: choices,
        selected: const GroupId('a'),
        onChanged: (_) {},
      ),
    );

    final selected = tester.widget<RadioListTile<GroupId>>(
      find.byKey(const ValueKey('group-choice:a')),
    );
    expect(selected.value, const GroupId('a'));
    expect(find.byType(RadioListTile<GroupId>), findsNWidgets(2));
  });
}
