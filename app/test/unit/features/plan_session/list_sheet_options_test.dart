import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_sheet_fixtures.dart';

class _BrokenRepository implements SessionSheetRepository {
  @override
  Future<List<SessionSheet>> getAll() async =>
      throw const InvariantViolation(InvariantCode.invalidSheet);

  @override
  Future<SessionSheet?> getById(SheetId id) async => null;
}

void main() {
  test(
    'lists the sessions in teaching order with technique and parts',
    () async {
      final fixtures = catalogueFixture().reversed.toList();
      final result = await ListSheetOptions(
        FixtureSessionSheetRepository(fixtures),
      )();

      final options = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('échec inattendu : $failure'),
      };
      expect(options.map((o) => o.id.value), [
        'posture-1',
        'demi-bille-1',
        'demi-bille-2',
        'quart-1',
      ]);
      expect(options.map((o) => o.techniqueRank), [1, 2, 2, 3]);
      expect(options.map((o) => o.part), [1, 1, 2, 1]);
      expect(options.map((o) => o.partCount), [1, 2, 2, 1]);
      expect(options[1].technique, 'demi-bille');
      expect(options[1].title, 'Quantité demi-bille');
    },
  );

  test('reports a catalogue failure instead of throwing', () async {
    final result = await ListSheetOptions(_BrokenRepository())();

    expect(result, isA<Err<Object?>>());
  });
}
