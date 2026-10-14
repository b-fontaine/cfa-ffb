import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, StepAppBar bar) =>
      pumpUi(tester, Scaffold(appBar: bar));

  const menu = ValueKey('step-app-bar-menu');

  testWidgets('shows the title and the position as n/total', (tester) async {
    await pumpBar(
      tester,
      const StepAppBar(title: 'Training', position: 6, total: 9),
    );

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('6/9'), findsOneWidget);
  });

  test('is at most 56 dp high', () {
    const bar = StepAppBar(title: 'T', position: 1, total: 2);

    expect(bar.preferredSize.height, lessThanOrEqualTo(56));
  });

  testWidgets('renders at most 56 dp high', (tester) async {
    await pumpBar(
      tester,
      StepAppBar(
        title: 'Training',
        position: 6,
        total: 9,
        onBack: () {},
        actions: [StepAppBarAction(label: 'Summary', onSelected: () {})],
      ),
    );

    expect(
      tester.getSize(find.byType(StepAppBar)).height,
      lessThanOrEqualTo(56),
    );
  });

  testWidgets('has no menu without actions', (tester) async {
    await pumpBar(
      tester,
      const StepAppBar(title: 'Training', position: 1, total: 9),
    );

    expect(find.byKey(menu), findsNothing);
  });

  testWidgets('lists the injected actions and calls the chosen one', (
    tester,
  ) async {
    final called = <String>[];
    await pumpBar(
      tester,
      StepAppBar(
        title: 'Training',
        position: 6,
        total: 9,
        actions: [
          StepAppBarAction(label: 'Summary', onSelected: () => called.add('s')),
          StepAppBarAction(label: 'Finish', onSelected: () => called.add('f')),
        ],
      ),
    );

    await tester.tap(find.byKey(menu));
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(called, ['f']);
  });

  testWidgets('shows a back button only when onBack is given', (tester) async {
    var backs = 0;
    await pumpBar(
      tester,
      const StepAppBar(title: 'Training', position: 1, total: 9),
    );
    expect(find.byTooltip('Back'), findsNothing);

    await pumpBar(
      tester,
      StepAppBar(
        title: 'Training',
        position: 1,
        total: 9,
        onBack: () => backs++,
      ),
    );
    await tester.tap(find.byTooltip('Back'));

    expect(backs, 1);
  });

  testWidgets('shows a close button when onClose is given', (tester) async {
    var closes = 0;
    await pumpBar(
      tester,
      StepAppBar(
        title: 'Training',
        position: 1,
        total: 9,
        onClose: () => closes++,
      ),
    );

    await tester.tap(find.byTooltip('Close'));

    expect(closes, 1);
  });

  testWidgets('the title is a header and the position is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBar(
      tester,
      const StepAppBar(title: 'Training', position: 6, total: 9),
    );

    expect(find.bySemanticsLabel('Step 6 of 9'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Training')),
      matchesSemantics(label: 'Training', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('a long title is ellipsised without overflow at 320 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpBar(
      tester,
      StepAppBar(
        title: 'Entraînement approfondi des trajectoires complexes à la bande',
        position: 12,
        total: 12,
        onBack: () {},
        actions: [StepAppBarAction(label: 'Summary', onSelected: () {})],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
