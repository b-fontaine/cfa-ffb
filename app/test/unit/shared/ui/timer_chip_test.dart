import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:billard_cfa/shared/ui/timer_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  group('timerToneFor', () {
    test('is neutral from one minute up', () {
      expect(timerToneFor(const Duration(minutes: 1)), TimerTone.neutral);
      expect(timerToneFor(const Duration(minutes: 30)), TimerTone.neutral);
    });

    test('is attention just under one minute', () {
      expect(
        timerToneFor(const Duration(seconds: 59, milliseconds: 999)),
        TimerTone.attention,
      );
    });

    test('is attention at exactly zero', () {
      expect(timerToneFor(Duration.zero), TimerTone.attention);
    });

    test('is overdue as soon as the time is negative', () {
      expect(timerToneFor(const Duration(milliseconds: -1)), TimerTone.overdue);
      expect(timerToneFor(const Duration(minutes: -3)), TimerTone.overdue);
    });
  });

  group('formatTimer', () {
    test('formats mm:ss with zero padding', () {
      expect(formatTimer(const Duration(minutes: 7, seconds: 5)), '07:05');
    });

    test('keeps counting minutes past 59', () {
      expect(formatTimer(const Duration(minutes: 90)), '90:00');
    });

    test('prefixes an overdue time with +', () {
      expect(formatTimer(const Duration(seconds: -65)), '+01:05');
    });

    test('shows zero as 00:00', () {
      expect(formatTimer(Duration.zero), '00:00');
    });
  });

  Color background(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('timer-chip')),
                  )
                  .decoration
              as BoxDecoration)
          .color!;

  testWidgets('shows the time in titleLarge', (tester) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: false,
        onToggle: () {},
      ),
    );

    final text = tester.widget<Text>(find.text('02:00'));
    final expected = Theme.of(tester.element(find.text('02:00')))
        .textTheme
        .titleLarge!;
    expect(text.style?.fontSize, expected.fontSize);
  });

  testWidgets('uses a neutral background above one minute', (tester) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: true,
        onToggle: () {},
      ),
    );

    final scheme = Theme.of(tester.element(find.text('02:00'))).colorScheme;
    expect(background(tester), scheme.surfaceContainerHighest);
  });

  testWidgets('uses the attention colour under one minute', (tester) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(seconds: 30),
        running: true,
        onToggle: () {},
      ),
    );

    final theme = Theme.of(tester.element(find.text('00:30')));
    expect(background(tester), theme.extension<StatusColors>()!.attention);
  });

  testWidgets('uses the error container when overdue', (tester) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(seconds: -10),
        running: true,
        onToggle: () {},
      ),
    );

    final scheme = Theme.of(tester.element(find.text('+00:10'))).colorScheme;
    expect(background(tester), scheme.errorContainer);
  });

  testWidgets('shows a warning icon off neutral, none when neutral', (
    tester,
  ) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 5),
        running: true,
        onToggle: () {},
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(seconds: 10),
        running: true,
        onToggle: () {},
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('the toggle button is at least 48 dp and calls onToggle', (
    tester,
  ) async {
    var calls = 0;
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: false,
        onToggle: () => calls++,
      ),
    );

    final button = find.byType(IconButton);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(calls, 1);
  });

  testWidgets('the button shows play when paused and pause when running', (
    tester,
  ) async {
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: false,
        onToggle: () {},
      ),
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byTooltip('Start the timer'), findsOneWidget);

    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: true,
        onToggle: () {},
      ),
    );
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byTooltip('Pause the timer'), findsOneWidget);
  });

  testWidgets('labels the time for assistive technologies', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(minutes: 2),
        running: true,
        onToggle: () {},
      ),
    );

    expect(find.bySemanticsLabel('Time remaining: 02:00'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('labels an overdue time in French', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      TimerChip(
        remaining: const Duration(seconds: -5),
        running: true,
        onToggle: () {},
      ),
      locale: const Locale('fr'),
    );

    expect(find.bySemanticsLabel('Temps dépassé de 00:05'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'only announces at thresholds: live region is empty when neutral',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(
        tester,
        TimerChip(
          remaining: const Duration(minutes: 5),
          running: true,
          onToggle: () {},
        ),
      );
      expect(find.bySemanticsLabel('Less than one minute left'), findsNothing);
      expect(find.bySemanticsLabel('Time is up'), findsNothing);

      await pumpUi(
        tester,
        TimerChip(
          remaining: const Duration(seconds: 20),
          running: true,
          onToggle: () {},
        ),
      );
      expect(
        find.bySemanticsLabel('Less than one minute left'),
        findsOneWidget,
      );

      await pumpUi(
        tester,
        TimerChip(
          remaining: const Duration(seconds: -1),
          running: true,
          onToggle: () {},
        ),
      );
      expect(find.bySemanticsLabel('Time is up'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('the time label does not change the live region within a tone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Future<String?> live(int seconds) async {
      await pumpUi(
        tester,
        TimerChip(
          remaining: Duration(seconds: seconds),
          running: true,
          onToggle: () {},
        ),
      );
      final node = tester.getSemantics(
        find.byKey(const ValueKey('timer-chip-live')),
      );
      return node.label;
    }

    expect(await live(30), await live(29));
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
        child: TimerChip(
          remaining: const Duration(seconds: -125),
          running: true,
          onToggle: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
