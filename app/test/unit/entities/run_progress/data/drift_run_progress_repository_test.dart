import 'package:billard_cfa/entities/run_progress/data/drift_run_progress_repository.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../contract/run_progress_contract.dart';
import '../../../../support/drift_support.dart';

/// Écrit une ligne brute (sans passer par le dépôt) pour simuler un stockage
/// abîmé ; chaque argument remplace la valeur saine.
Future<void> _insertRaw(
  AppDatabase db, {
  String runKey = 'posture-1|children||',
  String sheetId = 'posture-1',
  String? audience = 'children',
  int step = 1,
  String counts = '{}',
  String checked = '{}',
  int scoreA = 0,
}) => db.customStatement(
  'INSERT INTO run_progress_entries (run_key, sheet_id, audience, step, '
  'counts_json, checked_json, score_a, score_b, timer_seconds, updated_at) '
  'VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?)',
  [
    runKey,
    sheetId,
    audience,
    step,
    counts,
    checked,
    scoreA,
    '2026-10-16T09:00:00.000Z',
  ],
);

void main() {
  late AppDatabase db;
  late DriftRunProgressRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    repository = DriftRunProgressRepository(db);
  });
  tearDown(() => db.close());

  Future<int> rows() async =>
      (await db.select(db.runProgressEntries).get()).length;

  test('reads a healthy raw row', () async {
    await _insertRaw(db, counts: '{"ini":2}', checked: '{"g":[0]}');

    final read = await repository.byKey(runKey('posture-1'));

    expect(read!.counts, {'ini': 2});
    expect(read.checked, {
      'g': {0},
    });
  });

  for (final (label, insert) in <(String, Future<void> Function(AppDatabase))>[
    ('malformed counts JSON', (db) => _insertRaw(db, counts: 'oups')),
    (
      'counts that are not integers',
      (db) => _insertRaw(db, counts: '{"a":"x"}'),
    ),
    ('a malformed grid', (db) => _insertRaw(db, checked: '[1]')),
    ('an unknown audience', (db) => _insertRaw(db, audience: 'seniors')),
    ('an invalid sheet id', (db) => _insertRaw(db, sheetId: 'Pas Valide')),
    ('a negative step', (db) => _insertRaw(db, step: -3)),
    ('a score above the limit', (db) => _insertRaw(db, scoreA: 5000)),
  ]) {
    test('byKey ignores and erases a row with $label', () async {
      await insert(db);

      expect(await repository.byKey(runKey('posture-1')), isNull);
      expect(await rows(), 0);
    });

    test('all skips and erases a row with $label', () async {
      await insert(db);
      await _insertRaw(
        db,
        runKey: 'demi-bille-1|children||',
        sheetId: 'demi-bille-1',
      );

      final all = await repository.all();

      expect(all.map((p) => p.key.sheetId.value), ['demi-bille-1']);
      expect(await rows(), 1);
    });
  }
}
