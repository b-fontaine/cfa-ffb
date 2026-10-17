import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/pages/sheet_detail/presentation/sheet_detail_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    ValueChanged<Audience>? onExport,
    String backLabel = 'Session catalogue',
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      BlocProvider<SheetDetailBloc>.value(
        value: bloc,
        child: SheetDetailPage(
          backLabel: backLabel,
          onBack: onBack ?? () {},
          onHome: onHome ?? () {},
          onPlan: onPlan ?? (_) {},
          onLaunch: onLaunch ?? (_) {},
          onExport: onExport ?? (_) {},
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

  testWidgets('names the way back that the router gives', (tester) async {
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
    await pump(tester, onBack: () => back++, backLabel: 'Planning');

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

    testWidgets('says the way back is Today when the router says so', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(),
      );

      await pump(tester, backLabel: 'Today');

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Session catalogue'), findsNothing);
    });

    group('actions menu', () {
      String? copied;
      PlatformException? clipboardError;

      setUp(() {
        copied = null;
        clipboardError = null;
      });

      void mockClipboard(WidgetTester tester) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              if (clipboardError != null) throw clipboardError!;
              copied =
                  (call.arguments as Map<Object?, Object?>)['text']! as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
      }

      Future<void> report(WidgetTester tester) async {
        whenListen(
          bloc,
          const Stream<SheetDetailState>.empty(),
          initialState: ready(),
        );
        await pump(tester);
        await tester.tap(find.byKey(const ValueKey('sheet-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report a proposal'));
        await tester.pumpAndSettle();
      }

      testWidgets('is a 48 dp button with a tooltip', (tester) async {
        whenListen(
          bloc,
          const Stream<SheetDetailState>.empty(),
          initialState: ready(),
        );
        await pump(tester);

        final size = tester.getSize(find.byKey(const ValueKey('sheet-menu')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.byTooltip('More actions'), findsOneWidget);
      });

      testWidgets('offers to report a proposal', (tester) async {
        whenListen(
          bloc,
          const Stream<SheetDetailState>.empty(),
          initialState: ready(),
        );
        await pump(tester);

        await tester.tap(find.byKey(const ValueKey('sheet-menu')));
        await tester.pumpAndSettle();

        expect(find.text('Report a proposal'), findsOneWidget);
      });

      testWidgets('copies the identifier of the session and says so', (
        tester,
      ) async {
        mockClipboard(tester);

        await report(tester);

        expect(
          copied,
          'Proposal to review: session demi-bille-1 '
          '(Quantité demi-bille, session 1/2)',
        );
        expect(
          find.text('Session identifier copied: demi-bille-1'),
          findsOneWidget,
        );
      });

      testWidgets('shows the identifier in clear when the copy fails', (
        tester,
      ) async {
        clipboardError = PlatformException(code: 'denied');
        mockClipboard(tester);

        await report(tester);

        expect(copied, isNull);
        expect(
          find.text('Copy failed. Session identifier: demi-bille-1'),
          findsOneWidget,
        );
      });

      testWidgets('is absent while the session loads', (tester) async {
        whenListen(
          bloc,
          const Stream<SheetDetailState>.empty(),
          initialState: state(SheetDetailStatus.loading),
        );
        await pump(tester);

        expect(find.byKey(const ValueKey('sheet-menu')), findsNothing);
      });
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

    testWidgets('opens the PDF export for the audience on screen', (
      tester,
    ) async {
      final exported = <Audience>[];
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: ready(Audience.adults),
      );
      await pump(tester, onExport: exported.add);

      await tester.tap(find.text('Print / export as PDF'));

      expect(exported, [Audience.adults]);
    });

    testWidgets('does not offer the PDF export while the session loads', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SheetDetailState>.empty(),
        initialState: const SheetDetailState(),
      );
      await pump(tester);

      expect(find.text('Print / export as PDF'), findsNothing);
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
