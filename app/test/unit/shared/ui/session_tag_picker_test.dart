import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/ui/session_tag_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

const _english = [
  'Game enjoyed',
  'Instructions to rephrase',
  'Too long',
  'Too short',
  'Too hard',
  'Too easy',
  'To do again',
  'Not enough equipment',
];

const _french = [
  'Jeu apprécié',
  'Consigne à reformuler',
  'Trop long',
  'Trop court',
  'Trop difficile',
  'Trop facile',
  'À refaire',
  'Matériel insuffisant',
];

List<String> _labels(WidgetTester tester) => [
  for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip)))
    (chip.label as Text).data!,
];

void main() {
  testWidgets('offers the closed list in English, in display order', (
    tester,
  ) async {
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {}, onChanged: (_) {}),
    );

    expect(_labels(tester), _english);
  });

  testWidgets('offers the closed list in French', (tester) async {
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {}, onChanged: (_) {}),
      locale: const Locale('fr'),
    );

    expect(_labels(tester), _french);
  });

  testWidgets('has no text field: no free text can be typed', (tester) async {
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {}, onChanged: (_) {}),
    );

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('marks the selected labels, with a check mark besides colour', (
    tester,
  ) async {
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {SessionTag.tooLong}, onChanged: (_) {}),
    );

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(
      [for (final chip in chips) chip.selected],
      [for (final tag in SessionTag.values) tag == SessionTag.tooLong],
    );
    expect(chips.every((chip) => chip.showCheckmark ?? true), isTrue);
  });

  testWidgets('tapping a label adds it, tapping a selected one drops it', (
    tester,
  ) async {
    final calls = <Set<SessionTag>>[];
    await pumpUi(
      tester,
      SessionTagPicker(
        selected: const {SessionTag.tooLong},
        onChanged: calls.add,
      ),
    );

    await tester.tap(find.text('To do again'));
    await tester.tap(find.text('Too long'));

    expect(calls, [
      {SessionTag.tooLong, SessionTag.toRedo},
      <SessionTag>{},
    ]);
  });

  testWidgets('does not mutate the set it was given', (tester) async {
    final given = {SessionTag.tooLong};
    await pumpUi(tester, SessionTagPicker(selected: given, onChanged: (_) {}));

    await tester.tap(find.text('To do again'));

    expect(given, {SessionTag.tooLong});
  });

  testWidgets('every chip is at least 48 dp high and wide', (tester) async {
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {}, onChanged: (_) {}),
    );

    for (final chip in find.byType(FilterChip).evaluate()) {
      final size = tester.getSize(find.byWidget(chip.widget));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('is read-only when no callback is given', (tester) async {
    await pumpUi(tester, const SessionTagPicker(selected: {}));

    await tester.tap(find.text('Too long'));
    await tester.pump();

    expect(
      tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .every((chip) => chip.onSelected == null),
      isTrue,
    );
  });

  testWidgets('reads the state of each label to assistive technologies', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      SessionTagPicker(selected: const {SessionTag.toRedo}, onChanged: (_) {}),
    );

    expect(
      tester.getSemantics(find.text('To do again')),
      matchesSemantics(
        label: 'To do again',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('fits a 320 dp wide screen at 200 % text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: SingleChildScrollView(
          child: SessionTagPicker(selected: const {}, onChanged: (_) {}),
        ),
      ),
      locale: const Locale('fr'),
    );

    expect(tester.takeException(), isNull);
  });
}
