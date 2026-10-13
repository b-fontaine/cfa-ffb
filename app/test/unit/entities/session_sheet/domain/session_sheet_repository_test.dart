import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/session_sheet_fixtures.dart';

/// Une classe qui n'implémente que `getAll` et `getById` doit compiler : si le
/// port gagne une méthode abstraite (écriture comprise), ce fichier ne compile
/// plus. C'est le test de forme « lecture seule » (FORMAT § 8) : pas de
/// réflexion en Flutter.
class _ReadOnlyRepository implements SessionSheetRepository {
  _ReadOnlyRepository(this._sheets);

  final List<SessionSheet> _sheets;

  @override
  Future<List<SessionSheet>> getAll() async => _sheets;

  @override
  Future<SessionSheet?> getById(SheetId id) async {
    for (final sheet in _sheets) {
      if (sheet.id == id) return sheet;
    }
    return null;
  }
}

void main() {
  test('the port is satisfied by a read-only implementation', () async {
    final sheet = buildSheet();
    final SessionSheetRepository repository = _ReadOnlyRepository([sheet]);

    expect(await repository.getAll(), [sheet]);
    expect(await repository.getById(sheet.id), sheet);
    expect(await repository.getById(SheetId('autre-1')), isNull);
  });
}
