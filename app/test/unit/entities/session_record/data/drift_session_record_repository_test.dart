import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/drift_support.dart';

Future<void> _insertRaw(AppDatabase db, String tags) => db.customStatement(
  'INSERT INTO session_records (id, created_at, updated_at, group_id, '
  'season_id, date, audience, tags_json) '
  "VALUES ('x1', '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z', "
  "'g1', 's1', '2026-10-05T00:00:00.000', 'children', ?)",
  [tags],
);

void main() {
  late AppDatabase db;
  late DriftSessionRecordRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    repository = DriftSessionRecordRepository(db, TickingClock());
  });
  tearDown(() => db.close());

  Future<Set<SessionTag>> tagsRead() async =>
      (await repository.byId(const SessionId('x1')))!.tags;

  test('reads the tags of a healthy raw row', () async {
    await _insertRaw(db, '["tooShort","gameAppreciated"]');

    expect(await tagsRead(), {SessionTag.tooShort, SessionTag.gameAppreciated});
  });

  test('ignores an unknown code but keeps the known ones', () async {
    await _insertRaw(db, '["freeText","tooEasy"]');

    expect(await tagsRead(), {SessionTag.tooEasy});
  });

  test(
    'never fails on a damaged column: the session opens without tags',
    () async {
      await _insertRaw(db, 'pas du json');

      expect(await tagsRead(), isEmpty);
      expect((await repository.all()).single.id, const SessionId('x1'));
    },
  );
}
