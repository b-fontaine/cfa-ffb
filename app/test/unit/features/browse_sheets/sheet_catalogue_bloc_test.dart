import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/session_sheet_fixtures.dart';

class _MockListSheets extends Mock implements ListSheets;

void main() {
  late _MockListSheets listSheets;
  final catalogue = SheetCatalogue(
    groups: [
      TechniqueGroup(
        rank: 1,
        technique: 'demi-bille',
        title: 'Quantité demi-bille',
        partCount: 1,
        sheets: [buildSheet()],
      ),
    ],
  );

  setUp(() => listSheets = _MockListSheets());

  blocTest<SheetCatalogueBloc, SheetCatalogueState>(
    'loads the catalogue on start',
    setUp: () => when(listSheets.call).thenAnswer((_) async => Ok(catalogue)),
    build: () => SheetCatalogueBloc(listSheets),
    act: (bloc) => bloc.add(const SheetCatalogueEvent.started()),
    expect: () => [
      const SheetCatalogueState(),
      SheetCatalogueState(
        status: SheetCatalogueStatus.ready,
        catalogue: catalogue,
      ),
    ],
  );

  blocTest<SheetCatalogueBloc, SheetCatalogueState>(
    'reports a failure to read the catalogue',
    setUp: () => when(listSheets.call).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.invalidSheet)),
    ),
    build: () => SheetCatalogueBloc(listSheets),
    act: (bloc) => bloc.add(const SheetCatalogueEvent.started()),
    expect: () => [
      const SheetCatalogueState(),
      isA<SheetCatalogueState>()
          .having((s) => s.status, 'status', SheetCatalogueStatus.failure)
          .having((s) => s.failure, 'failure', isA<InvariantViolation>()),
    ],
  );

  blocTest<SheetCatalogueBloc, SheetCatalogueState>(
    'chooses a review filter, switches to another and removes it',
    setUp: () => when(listSheets.call).thenAnswer((_) async => Ok(catalogue)),
    build: () => SheetCatalogueBloc(listSheets),
    act: (bloc) async {
      bloc.add(const SheetCatalogueEvent.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const SheetCatalogueEvent.reviewFilterSelected(
          filter: SheetReviewFilter.toReview,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const SheetCatalogueEvent.reviewFilterSelected(
          filter: SheetReviewFilter.games,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const SheetCatalogueEvent.reviewFilterSelected(
          filter: SheetReviewFilter.games,
        ),
      );
    },
    expect: () => [
      const SheetCatalogueState(),
      isA<SheetCatalogueState>().having(
        (s) => s.reviewFilter,
        'filter',
        SheetReviewFilter.none,
      ),
      isA<SheetCatalogueState>()
          .having((s) => s.reviewFilter, 'filter', SheetReviewFilter.toReview)
          .having((s) => s.visible!.sheetCount, 'visible', 0),
      isA<SheetCatalogueState>()
          .having((s) => s.reviewFilter, 'filter', SheetReviewFilter.games)
          .having((s) => s.visible!.sheetCount, 'visible', 0),
      isA<SheetCatalogueState>()
          .having((s) => s.reviewFilter, 'filter', SheetReviewFilter.none)
          .having((s) => s.visible!.sheetCount, 'visible', 1),
    ],
  );
}
