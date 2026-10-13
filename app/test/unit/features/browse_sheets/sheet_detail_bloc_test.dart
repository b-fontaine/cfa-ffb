import 'package:billard_cfa/features/browse_sheets/domain/get_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/session_sheet_fixtures.dart';

class _MockGetSheet extends Mock implements GetSheet;

void main() {
  late _MockGetSheet getSheet;
  final id = SheetId('demi-bille-1');
  final detail = SheetDetail(sheet: buildSheet(), partCount: 2, timings: {});

  setUpAll(() => registerFallbackValue(SheetId('x-1')));
  setUp(() => getSheet = _MockGetSheet());

  blocTest<SheetDetailBloc, SheetDetailState>(
    'reads the session for the children by default',
    setUp: () => when(() => getSheet(id)).thenAnswer((_) async => Ok(detail)),
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) => bloc.add(SheetDetailEvent.started(sheetId: id)),
    expect: () => [
      SheetDetailState(sheetId: id),
      SheetDetailState(
        status: SheetDetailStatus.ready,
        sheetId: id,
        detail: detail,
      ),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'starts with the audience of the address',
    setUp: () => when(() => getSheet(id)).thenAnswer((_) async => Ok(detail)),
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) => bloc.add(
      SheetDetailEvent.started(sheetId: id, audience: Audience.adults),
    ),
    expect: () => [
      SheetDetailState(audience: Audience.adults, sheetId: id),
      SheetDetailState(
        status: SheetDetailStatus.ready,
        audience: Audience.adults,
        sheetId: id,
        detail: detail,
      ),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'switches the audience without reading again',
    setUp: () => when(() => getSheet(id)).thenAnswer((_) async => Ok(detail)),
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) async {
      bloc.add(SheetDetailEvent.started(sheetId: id));
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const SheetDetailEvent.audienceChanged(audience: Audience.adults),
      );
    },
    verify: (_) => verify(() => getSheet(id)).called(1),
    expect: () => [
      SheetDetailState(sheetId: id),
      isA<SheetDetailState>().having((s) => s.detail, 'detail', detail),
      isA<SheetDetailState>().having(
        (s) => s.audience,
        'audience',
        Audience.adults,
      ),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'reports an unknown session as not found',
    setUp: () =>
        when(() => getSheet(id))
            .thenAnswer((_) async => Err(NotFound('sheet', id.value))),
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) => bloc.add(SheetDetailEvent.started(sheetId: id)),
    expect: () => [
      SheetDetailState(sheetId: id),
      SheetDetailState(status: SheetDetailStatus.notFound, sheetId: id),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'reports any other failure',
    setUp: () => when(() => getSheet(id)).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.invalidSheet)),
    ),
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) => bloc.add(SheetDetailEvent.started(sheetId: id)),
    expect: () => [
      SheetDetailState(sheetId: id),
      isA<SheetDetailState>()
          .having((s) => s.status, 'status', SheetDetailStatus.failure)
          .having((s) => s.failure, 'failure', isA<InvariantViolation>()),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'reads the same session again on retry, with the same audience',
    setUp: () {
      var calls = 0;
      when(() => getSheet(id)).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Err(InvariantViolation(InvariantCode.invalidSheet))
            : Ok(detail);
      });
    },
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) async {
      bloc.add(
        SheetDetailEvent.started(sheetId: id, audience: Audience.adults),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SheetDetailEvent.retried());
    },
    verify: (_) => verify(() => getSheet(id)).called(2),
    expect: () => [
      SheetDetailState(audience: Audience.adults, sheetId: id),
      isA<SheetDetailState>().having(
        (s) => s.status,
        'status',
        SheetDetailStatus.failure,
      ),
      SheetDetailState(audience: Audience.adults, sheetId: id),
      SheetDetailState(
        status: SheetDetailStatus.ready,
        audience: Audience.adults,
        sheetId: id,
        detail: detail,
      ),
    ],
  );

  blocTest<SheetDetailBloc, SheetDetailState>(
    'ignores a retry before any session was asked for',
    build: () => SheetDetailBloc(getSheet),
    act: (bloc) => bloc.add(const SheetDetailEvent.retried()),
    expect: () => const <SheetDetailState>[],
  );
}
