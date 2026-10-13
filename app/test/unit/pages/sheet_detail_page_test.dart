import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/pages/sheet_detail/presentation/sheet_detail_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/session_sheet_fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SheetDetailEvent, SheetDetailState>
    implements SheetDetailBloc;

void main() {
  late _MockBloc bloc;

  setUpAll(
    () => registerFallbackValue(
      const SheetDetailEvent.audienceChanged(audience: Audience.children),
    ),
  );
  setUp(() => bloc = _MockBloc());

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onHome,
    ValueChanged<Audience>? onPlan,
    ValueChanged<Audience>? onLaunch,
    bool fromPlanner = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      BlocProvider<SheetDetailBloc>.value(
        value: bloc,
        child: SheetDetailPage(
          fromPlanner: fromPlanner,
          onBack: onBack ?? () {},
          onHome: onHome ?? () {},
          onPlan: onPlan ?? (_) {},
          onLaunch: onLaunch ?? (_) {},
        ),
      ),
    );
  }

  SheetDetailState state(
    SheetDetailStatus status, {
    SheetDetail? detail,
    Failure? failure,
  }) => SheetDetailState(status: status, detail: detail, failure: failure);

  testWidgets('shows the loading state', (tester) async {
    whenListen(
      bloc,
      const Stream<SheetDetailState>.empty(),
      initialState: state(SheetDetailStatus.loading),
    );

    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the not found page and leads home', (tester) async {
    var home = 0;
    whenListen(
      bloc,
      const Stream<SheetDetailState>.empty(),
      initialState: state(SheetDetailStatus.notFound),
    );
    await pump(tester, onHome: () => home++);

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));

    expect(home, 1);
  });

  testWidgets('shows a localized message on failure', (tester) async {
    whenListen(
      bloc,
      const Stream<SheetDetailState>.empty(),
      initialState: state(
        SheetDetailStatus.failure,
        failure: const InvariantViolation(InvariantCode.invalidSheet),
      ),
    );

    await pump(tester);

    expect(find.byType(Text), findsWidgets);
    expect(find.textContaining('Page not found'), findsNothing);
  });

  testWidgets('names the planner as the way back when opened from it', (
    tester,
  ) async {
    var back = 0;
    final sheet = buildSheet();
    whenListen(
      bloc,
      const Stream<SheetDetailState>.empty(),
      initialState: state(
        SheetDetailStatus.ready,
        detail: SheetDetail(
          sheet: sheet,
          partCount: 2,
          timings: {
            for (final a in Audience.values)
              a: sheetTiming(sheet, audience: a, shapes: RulesConfig().shapes),
          },
        ),
      ),
    );
    await pump(tester, onBack: () => back++, fromPlanner: true);

    await tester.tap(find.text('Planning'));

    expect(back, 1);
    expect(find.text('Session catalogue'), findsNothing);
  });

  testWidgets('retries or goes back from a failure', (tester) async {
    var back = 0;
    whenListen(
      bloc,
      const Stream<SheetDetailState>.empty(),
      initialState: state(
        SheetDetailStatus.failure,
        failure: const InvariantViolation(InvariantCode.invalidSheet),
      ),
    );
    await pump(tester, onBack: () => back++);

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Back'));

    verify(() => bloc.add(const SheetDetailEvent.retried())).called(1);
    expect(back, 1);
  });

  group('ready', () {
    late SheetDetail detail;

    setUp(() {
      final sheet = buildSheet();
      detail = SheetDetail(
        sheet: sheet,
        partCount: 2,
        timings: {
          for (final audience in Audience.values)
            audience: sheetTiming(
              sheet,
              audience: audience,
              shapes: RulesConfig().shapes,
            ),
        },
      );
    });

    SheetDetailState ready([Audience audience = Audience.children]) =>
        SheetDetailState(
          status: SheetDetailStatus.ready,
          audience: audience,
          detail: detail,
        );

    testWidgets('titles the page with the session and its part', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(),
      );

      await pump(tester);

      expect(find.text('Quantité demi-bille, session 1/2'), findsOneWidget);
      expect(find.text('90 min in total (approximate)'), findsOneWidget);
    });

    testWidgets('goes back to the catalogue', (tester) async {
      var back = 0;
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(),
      );
      await pump(tester, onBack: () => back++);

      await tester.tap(find.text('Session catalogue'));

      expect(back, 1);
    });

    testWidgets('plans the session for the audience on screen', (tester) async {
      final planned = <Audience>[];
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(Audience.adults),
      );
      await pump(tester, onPlan: planned.add);

      await tester.tap(find.text('Plan this session'));

      expect(planned, [Audience.adults]);
    });

    testWidgets('launches the guided session for the audience on screen', (
      tester,
    ) async {
      final launched = <Audience>[];
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(Audience.adults),
      );
      await pump(tester, onLaunch: launched.add);

      await tester.tap(find.text('Launch'));

      expect(launched, [Audience.adults]);
    });

    testWidgets('asks the bloc to change the audience', (tester) async {
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(),
      );
      await pump(tester);

      await tester.tap(find.text('Adults · 120 min'));

      verify(
        () => bloc.add(
          const SheetDetailEvent.audienceChanged(audience: Audience.adults),
        ),
      ).called(1);
    });

    testWidgets('shows the minutes of the chosen audience', (tester) async {
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(Audience.adults),
      );

      await pump(tester);

      expect(find.text('120 min in total (approximate)'), findsOneWidget);
    });
  });
}
