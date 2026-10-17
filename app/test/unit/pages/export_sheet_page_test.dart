import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/export_view.dart';
import 'package:billard_cfa/pages/export_sheet/presentation/export_sheet_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../shared/ui/pump_ui.dart';

class _MockCubit extends MockCubit<ExportSheetState>
    implements ExportSheetCubit;

ExportedDocument _exported() => const ExportedDocument(
  document: PrintDocument(
    title: 'Titre',
    language: 'fr',
    pages: [PrintPage(width: 100, height: 140, items: [])],
  ),
  bytes: [1],
  fileName: 'x.pdf',
);

void main() {
  setUpAll(() {
    registerFallbackValue(ExportKind.animator);
    registerFallbackValue(Audience.children);
  });

  late _MockCubit cubit;
  var backs = 0;
  var homes = 0;

  setUp(() {
    cubit = _MockCubit();
    backs = 0;
    homes = 0;
    when(() => cubit.retried()).thenAnswer((_) async {});
    when(() => cubit.kindChanged(any())).thenAnswer((_) async {});
    when(() => cubit.audienceChanged(any())).thenAnswer((_) async {});
    when(() => cubit.save()).thenAnswer((_) async {});
    when(() => cubit.print()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, ExportSheetState state) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      cubit,
      const Stream<ExportSheetState>.empty(),
      initialState: state,
    );
    await pumpUi(
      tester,
      BlocProvider<ExportSheetCubit>.value(
        value: cubit,
        child: ExportSheetPage(onBack: () => backs++, onHome: () => homes++),
      ),
    );
  }

  testWidgets('shows the loading state', (tester) async {
    await pump(tester, const ExportSheetState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ExportView), findsNothing);
  });

  testWidgets('shows the not found page and leads home', (tester) async {
    await pump(tester, const ExportSheetState(status: ExportStatus.notFound));

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));
    expect(homes, 1);
  });

  testWidgets('shows a localized message, retries and goes back', (
    tester,
  ) async {
    await pump(
      tester,
      const ExportSheetState(
        status: ExportStatus.failure,
        failure: InvariantViolation(InvariantCode.unprintableContent),
      ),
    );

    expect(find.textContaining('cannot draw'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    verify(() => cubit.retried()).called(1);
    await tester.tap(find.text('Back'));
    expect(backs, 1);
  });

  group('ready', () {
    ExportSheetState ready() => ExportSheetState(
      status: ExportStatus.ready,
      exported: _exported(),
      canPrint: true,
    );

    testWidgets('titles the page and names the way back', (tester) async {
      await pump(tester, ready());

      expect(find.text('PDF export'), findsOneWidget);
      await tester.tap(find.text('Session'));
      expect(backs, 1);
      expect(find.byType(ExportView), findsOneWidget);
    });

    testWidgets('hands the choices to the cubit', (tester) async {
      await pump(tester, ready());

      await tester.tap(find.text('Results sheets'));
      await tester.tap(find.text('Adults · 120 min'));
      await tester.tap(find.text('Save PDF'));
      await tester.tap(find.text('Print'));

      verify(() => cubit.kindChanged(ExportKind.results)).called(1);
      verify(() => cubit.audienceChanged(Audience.adults)).called(1);
      verify(() => cubit.save()).called(1);
      verify(() => cubit.print()).called(1);
    });
  });
}
