import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/session_sheet_fixtures.dart';

class _FailingSheets implements SessionSheetRepository {
  @override
  Future<List<SessionSheet>> getAll() async =>
      throw const InvariantViolation(InvariantCode.invalidSheet);

  @override
  Future<SessionSheet?> getById(SheetId id) async => null;
}

void main() {
  test('groups the sessions by technique, in teaching order', () async {
    final sheets = catalogueFixture().reversed.toList();
    final catalogue = ok(
      await ListSheets(FixtureSessionSheetRepository(sheets))(),
    );

    expect(catalogue.groups.map((g) => g.technique), [
      'posture',
      'demi-bille',
      'quart',
    ]);
    expect(catalogue.groups.map((g) => g.rank), [1, 2, 3]);
    expect(catalogue.techniqueCount, 3);
    expect(catalogue.sheetCount, 4);
  });

  test('lists the parts of a technique by increasing part', () async {
    final catalogue = ok(
      await ListSheets(FixtureSessionSheetRepository(catalogueFixture()))(),
    );
    final demi = catalogue.groups.firstWhere(
      (g) => g.technique == 'demi-bille',
    );

    expect(demi.partCount, 2);
    expect(demi.title, 'Quantité demi-bille');
    expect(demi.sheets.map((s) => s.part), [1, 2]);
  });

  test('returns an empty catalogue for an empty repository', () async {
    final catalogue = ok(await ListSheets(FixtureSessionSheetRepository([]))());

    expect(catalogue.groups, isEmpty);
    expect(catalogue.sheetCount, 0);
  });

  test('turns an unreadable catalogue into a failure', () async {
    final result = await ListSheets(_FailingSheets())();

    expect(codeOf(result), InvariantCode.invalidSheet);
  });
}
