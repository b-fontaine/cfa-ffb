import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Finder dot(int k) => find.byKey(ValueKey('pass-dot-$k'));

  testWidgets('shows the pocketed count as x/n text', (tester) async {
    await pumpUi(
      tester,
      PassDots(value: const [true, false, true], total: 5, onChanged: (_) {}),
    );

    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets('hides the x/n text on request, keeping the dots', (
    tester,
  ) async {
    await pumpUi(
      tester,
      PassDots(
        value: const [true, false],
        total: 4,
        showScore: false,
        onChanged: (_) {},
      ),
    );

    expect(find.text('1/4'), findsNothing);
    expect(find.byKey(const ValueKey('pass-dot-4')), findsOneWidget);
  });

  testWidgets('draws one dot per attempt, filled when pocketed', (
    tester,
  ) async {
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 4, onChanged: (_) {}),
    );

    expect(find.byKey(const ValueKey('pass-dot-filled')), findsNWidgets(1));
    expect(find.byKey(const ValueKey('pass-dot-empty')), findsNWidgets(3));
  });

  testWidgets('every dot is a touch target of at least 48 dp', (tester) async {
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 3, onChanged: (_) {}),
    );

    for (var k = 1; k <= 3; k++) {
      final size = tester.getSize(dot(k));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('tapping a dot reports the toggled outcomes', (tester) async {
    List<bool>? reported;
    await pumpUi(
      tester,
      PassDots(
        value: const [true, false, false],
        total: 3,
        onChanged: (next) => reported = next,
      ),
    );

    await tester.tap(dot(2));

    expect(reported, [true, true, false]);
  });

  testWidgets('tapping a pocketed dot misses it', (tester) async {
    List<bool>? reported;
    await pumpUi(
      tester,
      PassDots(
        value: const [true],
        total: 2,
        onChanged: (next) => reported = next,
      ),
    );

    await tester.tap(dot(1));

    expect(reported, [false, false]);
  });

  testWidgets('read-only ignores taps', (tester) async {
    var calls = 0;
    await pumpUi(
      tester,
      PassDots(
        value: const [true],
        total: 2,
        readOnly: true,
        onChanged: (_) => calls++,
      ),
    );

    await tester.tap(dot(1));

    expect(calls, 0);
  });

  testWidgets('without onChanged it is disabled and ignores taps', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const PassDots(value: [true], total: 2));

    await tester.tap(dot(1));

    expect(find.text('1/2'), findsOneWidget);
    expect(
      tester.getSemantics(dot(1)),
      isSemantics(
        label: 'Attempt 1 of 2: pocketed',
        hasEnabledState: true,
        isEnabled: false,
        isButton: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('exposes one labelled button per dot in English', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 2, onChanged: (_) {}),
    );

    expect(find.bySemanticsLabel('Attempt 1 of 2: pocketed'), findsOneWidget);
    expect(find.bySemanticsLabel('Attempt 2 of 2: missed'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('exposes the labels in French', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 2, onChanged: (_) {}),
      locale: const Locale('fr'),
    );

    expect(find.bySemanticsLabel('Essai 1 sur 2 : empochée'), findsOneWidget);
    expect(find.bySemanticsLabel('Essai 2 sur 2 : manquée'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('exposes the overall value in a container', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 2, onChanged: (_) {}),
    );

    expect(find.bySemanticsLabel('1 of 2 pocketed'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wraps many dots on a 320 dp wide screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(
      tester,
      PassDots(value: const [], total: 20, onChanged: (_) {}),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PassDots)).width, lessThanOrEqualTo(320));
  });

  testWidgets('does not mark a dot as pocketed by colour alone', (
    tester,
  ) async {
    await pumpUi(
      tester,
      PassDots(value: const [true, false], total: 2, onChanged: (_) {}),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
