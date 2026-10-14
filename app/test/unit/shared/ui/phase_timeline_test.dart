import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

const _adults = [
  PhaseTimelineEntry(label: 'Warm-up', minutes: 10),
  PhaseTimelineEntry(label: 'Notion', minutes: 15),
  PhaseTimelineEntry(label: 'Training', minutes: 45),
  PhaseTimelineEntry(label: 'Game', minutes: 35),
  PhaseTimelineEntry(label: 'Review', minutes: 15),
];

void main() {
  Finder phase(int k) => find.byKey(ValueKey('phase-$k'));

  Widget timeline({
    List<PhaseTimelineEntry> phases = _adults,
    int current = 1,
    ValueChanged<int>? onSelected,
  }) => PhaseTimeline(
    phases: phases,
    currentIndex: current,
    onSelected: onSelected ?? (_) {},
  );

  testWidgets('widths are proportional to the minutes', (tester) async {
    await pumpUi(tester, timeline());

    final training = tester.getSize(phase(3)).width;
    final game = tester.getSize(phase(4)).width;
    final notion = tester.getSize(phase(2)).width;
    expect(training / game, closeTo(45 / 35, 0.05));
    expect(training / notion, closeTo(3, 0.1));
  });

  testWidgets('a short phase never goes under 48 dp', (tester) async {
    await pumpUi(
      tester,
      timeline(
        phases: const [
          PhaseTimelineEntry(label: 'A', minutes: 2),
          PhaseTimelineEntry(label: 'B', minutes: 88),
        ],
        current: 0,
      ),
    );

    expect(tester.getSize(phase(1)).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(phase(1)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('three, five and six phases fit at 320 dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final count in [3, 5, 6]) {
      final phases = [
        for (var i = 0; i < count; i++)
          PhaseTimelineEntry(
            label: 'Phase longue numéro $i',
            minutes: 90 ~/ count,
          ),
      ];
      await pumpUi(tester, timeline(phases: phases, current: 0));

      expect(tester.takeException(), isNull);
      for (var k = 1; k <= count; k++) {
        expect(tester.getSize(phase(k)).width, greaterThanOrEqualTo(48));
        expect(tester.getRect(phase(k)).right, lessThanOrEqualTo(320));
      }
    }
  });

  testWidgets('tapping a phase reports its zero-based index', (tester) async {
    int? selected;
    await pumpUi(tester, timeline(onSelected: (index) => selected = index));

    await tester.tap(phase(4));

    expect(selected, 3);
  });

  testWidgets('announces position, label, minutes and current state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, timeline());

    expect(
      find.bySemanticsLabel('Phase 2 of 5: Notion, 15 min, current'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Phase 3 of 5: Training, 45 min'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the current phase differs by more than its colour', (
    tester,
  ) async {
    await pumpUi(tester, timeline());

    BoxDecoration decoration(int k) =>
        tester
                .widget<Ink>(
                  find.descendant(of: phase(k), matching: find.byType(Ink)),
                )
                .decoration!
            as BoxDecoration;
    final current = decoration(2);
    final other = decoration(3);
    expect(
      (current.border! as Border).top.width,
      greaterThan((other.border! as Border).top.width),
    );
    final text = tester.widget<Text>(
      find.descendant(of: phase(2), matching: find.text('Notion')),
    );
    expect(text.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('a long label is truncated but stays in the semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = 'Entraînement approfondi des trajectoires complexes';
    await pumpUi(
      tester,
      timeline(
        phases: const [
          PhaseTimelineEntry(label: long, minutes: 45),
          PhaseTimelineEntry(label: 'Jeu', minutes: 45),
        ],
        current: 0,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('Phase 1 of 2: $long, 45 min, current'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('works with a 90-minute total', (tester) async {
    await pumpUi(
      tester,
      timeline(
        phases: const [
          PhaseTimelineEntry(label: 'Warm-up', minutes: 5),
          PhaseTimelineEntry(label: 'Notion', minutes: 10),
          PhaseTimelineEntry(label: 'Training', minutes: 35),
          PhaseTimelineEntry(label: 'Game', minutes: 30),
          PhaseTimelineEntry(label: 'Review', minutes: 10),
        ],
      ),
    );

    expect(find.text('35 min'), findsOneWidget);
  });

  test('rejects an empty list of phases', () {
    expect(
      () =>
          PhaseTimeline(phases: const [], currentIndex: 0, onSelected: (_) {}),
      throwsAssertionError,
    );
  });
}
