import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/student_pass_row.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

final _spec = ExerciseSpec(
  ref: ref('a', 1),
  rate: SuccessRate(successes: 4, attempts: 6),
);

Widget _row({
  List<(int, int)> passes = const [],
  int passed = 0,
  void Function(int, int)? onSubmit,
  String? refused,
  SuccessRate? rate,
}) => StudentPassRow(
  studentName: 'Léa',
  spec: rate == null ? _spec : ExerciseSpec(ref: ref('a', 1), rate: rate),
  passes: [
    for (final (i, (potted, total)) in passes.indexed)
      attempt(
        ref('a', 1),
        potted: potted,
        total: total,
        passIndex: i + 1,
        id: 'p$i',
      ),
  ],
  passedCount: passed,
  maxPasses: 2,
  passesRequired: 5,
  onSubmit: onSubmit ?? (_, _) {},
  refusedMessage: refused,
);

void main() {
  testWidgets('taps four dots out of six then submits 4 of 6', (tester) async {
    int? potted;
    int? total;
    await pumpUi(
      tester,
      _row(
        onSubmit: (p, t) {
          potted = p;
          total = t;
        },
      ),
    );
    for (final k in [1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey('pass-dot-$k')));
      await tester.pump();
    }
    await tester.tap(find.text('Record the pass'));

    expect((potted, total), (4, 6));
    expect(find.text('0 of 5 successful passes'), findsOneWidget);
  });

  testWidgets('shows each pass with its result in words', (tester) async {
    await pumpUi(tester, _row(passes: [(4, 6), (2, 6)], passed: 1));

    expect(find.text('Pass 1: 4 of 6, reached'), findsOneWidget);
    expect(find.text('Pass 2: 2 of 6, missed'), findsOneWidget);
    expect(find.text('1 of 5 successful passes'), findsOneWidget);
    expect(find.text('Record the pass'), findsNothing);
    expect(find.text('Maximum reached for this session'), findsOneWidget);
  });

  testWidgets('keeps the attempts below the dots, changeable', (tester) async {
    int? total;
    await pumpUi(tester, _row(onSubmit: (_, t) => total = t));

    expect(find.text('Attempts: 6 (sheet)'), findsOneWidget);
    expect(find.byTooltip('More attempts for Léa'), findsNothing);

    await tester.tap(find.text('Change for this pass'));
    await tester.pump();
    await tester.tap(find.byTooltip('More attempts for Léa'));
    await tester.pump();

    expect(find.text('Attempts: 7 (sheet: 6)'), findsOneWidget);
    expect(find.byKey(const ValueKey('pass-dot-7')), findsOneWidget);
    await tester.tap(find.text('Record the pass'));
    expect(total, 7);
  });

  testWidgets('every dot keeps a 48 dp target', (tester) async {
    await pumpUi(tester, _row());

    final size = tester.getSize(find.byKey(const ValueKey('pass-dot-1')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('under 600 dp the row is compact and still records', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? potted;
    int? total;
    await pumpUi(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: _row(
          onSubmit: (p, t) {
            potted = p;
            total = t;
          },
        ),
      ),
    );

    final box = find
        .descendant(
          of: find.byType(StudentPassRow),
          matching: find.byType(DecoratedBox),
        )
        .first;
    // Six essais : les boutons passent à la ligne, deux lignes de 48 dp.
    expect(tester.getSize(box).height, lessThan(110));
    expect(find.text('Record the pass'), findsNothing);
    expect(find.byTooltip('Record the pass of Léa'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    for (final k in [1, 2, 3]) {
      await tester.tap(find.byKey(ValueKey('pass-dot-$k')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('pass-submit')));

    expect([potted, total], [3, 6]);
  });

  testWidgets('under 600 dp the attempts open from the tune button', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(tester, _row());

    expect(find.text('Attempts: 6 (sheet)'), findsNothing);
    await tester.tap(find.byTooltip('Change the attempts for Léa'));
    await tester.pump();

    expect(find.text('Attempts: 6 (sheet)'), findsOneWidget);
  });

  group('a refused pass', () {
    const message = 'Too many passes for this exercise.';

    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    void expectInAttentionAlert(WidgetTester tester) {
      final alert = find.widgetWithText(AppAlert, message);
      expect(alert, findsOneWidget);
      expect(tester.widget<AppAlert>(alert).level, AlertLevel.attention);
      expect(find.text('Warning'), findsOneWidget);
      final style = tester.widget<Text>(find.text(message)).style;
      expect(
        style?.color,
        isNot(Theme.of(tester.element(alert)).colorScheme.error),
      );
    }

    testWidgets('is an attention alert, not red text, on a tablet', (
      tester,
    ) async {
      await pumpUi(tester, _row(refused: message));

      expectInAttentionAlert(tester);
    });

    testWidgets('is an attention alert, not red text, on a phone', (
      tester,
    ) async {
      phone(tester);
      await pumpUi(tester, _row(refused: message));

      expectInAttentionAlert(tester);
    });
  });

  group('the compact row on a phone', () {
    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    double heightOf(WidgetTester tester) => tester
        .getSize(find.byKey(const ValueKey('student-row-compact')))
        .height;

    testWidgets('holds four attempts on one 48 dp line', (tester) async {
      phone(tester);
      await pumpUi(tester, _row(rate: SuccessRate(successes: 3, attempts: 4)));

      expect(heightOf(tester), lessThan(2 * 48));
    });

    testWidgets('wraps six attempts or more on two 48 dp lines', (
      tester,
    ) async {
      phone(tester);
      await pumpUi(tester, _row());

      expect(heightOf(tester), greaterThanOrEqualTo(2 * 48));
      expect(heightOf(tester), lessThan(3 * 48));
    });

    testWidgets('unfolds the custom attempts and keeps the summary', (
      tester,
    ) async {
      phone(tester);
      await pumpUi(tester, _row());
      await tester.tap(find.byTooltip('Change the attempts for Léa'));
      await tester.pump();
      await tester.tap(find.byTooltip('More attempts for Léa'));
      await tester.pump();

      expect(find.text('Attempts: 7 (sheet: 6)'), findsOneWidget);
      expect(
        find.text(
          'More attempts than the sheet: the target is judged proportionally.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Change the attempts for Léa'));
      await tester.pump();

      expect(find.byType(CounterField), findsNothing);
      expect(find.text('Attempts: 7 (sheet: 6)'), findsOneWidget);
    });
  });

  group('the attempts counter bounds', () {
    Future<void> open(WidgetTester tester, {SuccessRate? rate}) async {
      await pumpUi(tester, _row(rate: rate));
      await tester.tap(find.text('Change for this pass'));
      await tester.pump();
    }

    IconButton button(WidgetTester tester, String tooltip) =>
        tester.widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == tooltip,
          ),
        );

    testWidgets('cannot go below the sheet', (tester) async {
      await open(tester);

      expect(button(tester, 'Fewer attempts for Léa').onPressed, isNull);
      expect(find.text('6'), findsWidgets);
      expect(find.byKey(const ValueKey('pass-dot-6')), findsOneWidget);
      expect(find.byKey(const ValueKey('pass-dot-7')), findsNothing);
    });

    testWidgets('goes up to the maximum of 16 attempts, not beyond', (
      tester,
    ) async {
      await open(tester);
      for (var i = 6; i < SuccessRate.maxAttempts; i++) {
        await tester.tap(find.byTooltip('More attempts for Léa'));
        await tester.pump();
      }

      expect(find.text('Attempts: 16 (sheet: 6)'), findsOneWidget);
      expect(button(tester, 'More attempts for Léa').onPressed, isNull);
      expect(find.byKey(const ValueKey('pass-dot-16')), findsOneWidget);
      expect(find.byKey(const ValueKey('pass-dot-17')), findsNothing);
      expect(tester.widget<CounterField>(find.byType(CounterField)).max, 16);
    });
  });
}
