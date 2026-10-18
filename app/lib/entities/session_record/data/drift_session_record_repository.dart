import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Séances données persistées dans SQLite (drift).
@LazySingleton(env: [Environment.prod])
class DriftSessionRecordRepository implements SessionRecordRepository {
  DriftSessionRecordRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> save(SessionRecord session) => _db.transaction(() async {
    final now = _clock.now();
    await _db
        .into(_db.sessionRecords)
        .insert(
          SessionRecordsCompanion.insert(
            id: session.id.value,
            groupId: session.groupId.value,
            seasonId: session.seasonId.value,
            date: session.date,
            audience: session.audience.name,
            mainBlockId: Value(session.mainBlockId),
            recallBlockId: Value(session.recallBlockId),
            sheetId: Value(session.sheetId?.value),
            tagsJson: Value(encodeSessionTags(session.tags)),
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => SessionRecordsCompanion(
              groupId: Value(session.groupId.value),
              seasonId: Value(session.seasonId.value),
              date: Value(session.date),
              audience: Value(session.audience.name),
              mainBlockId: Value(session.mainBlockId),
              recallBlockId: Value(session.recallBlockId),
              sheetId: Value(session.sheetId?.value),
              tagsJson: Value(encodeSessionTags(session.tags)),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.sessionRecords.id],
          ),
        );
    await (_db.delete(
      _db.sessionPresences,
    )..where((p) => p.sessionId.equals(session.id.value))).go();
    await _db.batch(
      (batch) => batch.insertAll(_db.sessionPresences, [
        for (final studentId in session.present)
          SessionPresencesCompanion.insert(
            sessionId: session.id.value,
            studentId: studentId.value,
          ),
      ]),
    );
  });

  @override
  Future<SessionRecord> open(SessionRecord candidate) =>
      _db.transaction(() async {
        final existing = await byId(candidate.id);
        final stored = existing == null
            ? candidate
            : existing.copyWith(
                present: {...existing.present, ...candidate.present},
              );
        await save(stored);
        return stored;
      });

  @override
  Future<SessionRecord> resume(SessionRecord record) =>
      _db.transaction(() async {
        final existing = await byId(record.id);
        final stored = existing == null
            ? record
            : record.copyWith(present: record.present, tags: existing.tags);
        await save(stored);
        return stored;
      });

  @override
  Future<SessionRecord?> byId(SessionId id) async {
    final row =
        await (_db.select(_db.sessionRecords)
              ..where((s) => s.id.equals(id.value) & s.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  @override
  Future<List<SessionRecord>> forGroup(GroupId groupId) async =>
      _byDate(await _where((s) => s.groupId.equals(groupId.value)));

  @override
  Future<List<SessionRecord>> forStudent(StudentId studentId) async => _byDate(
    await _where(
      (s) => s.id.isInQuery(
        _db.selectOnly(_db.sessionPresences)
          ..addColumns([_db.sessionPresences.sessionId])
          ..where(_db.sessionPresences.studentId.equals(studentId.value)),
      ),
    ),
  );

  @override
  Future<Set<SessionId>> idsEverPresent(StudentId studentId) async {
    final rows = await (_db.select(
      _db.sessionPresences,
    )..where((p) => p.studentId.equals(studentId.value))).get();
    return {for (final row in rows) SessionId(row.sessionId)};
  }

  @override
  Future<List<SessionRecord>> all() => _where((_) => const Constant(true));

  @override
  Future<void> setTags(SessionId id, Set<SessionTag> tags) =>
      (_db.update(
        _db.sessionRecords,
      )..where((s) => s.id.equals(id.value) & s.deletedAt.isNull())).write(
        SessionRecordsCompanion(
          tagsJson: Value(encodeSessionTags(tags)),
          updatedAt: Value(_clock.now()),
        ),
      );

  @override
  Future<void> delete(SessionId id) =>
      (_db.update(_db.sessionRecords)..where((s) => s.id.equals(id.value)))
          .write(SessionRecordsCompanion(deletedAt: Value(_clock.now())));

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.sessionPresences,
  )..where((p) => p.studentId.equals(studentId.value))).go();

  Future<List<SessionRecord>> _where(
    Expression<bool> Function($SessionRecordsTable table) filter,
  ) async {
    final rows =
        await (_db.select(_db.sessionRecords)
              ..where((s) => s.deletedAt.isNull() & filter(s))
              ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
            .get();
    return await _hydrate(rows);
  }

  List<SessionRecord> _byDate(List<SessionRecord> sessions) =>
      sessions..sort((a, b) => a.date.compareTo(b.date));

  Future<List<SessionRecord>> _hydrate(List<SessionRecordRow> rows) async {
    final presences = await (_db.select(
      _db.sessionPresences,
    )..where((p) => p.sessionId.isIn([for (final r in rows) r.id]))).get();
    return [
      for (final row in rows)
        SessionRecord(
          id: SessionId(row.id),
          groupId: GroupId(row.groupId),
          seasonId: SeasonId(row.seasonId),
          date: row.date,
          audience: Audience.values.byName(row.audience),
          present: {
            for (final p in presences.where((p) => p.sessionId == row.id))
              StudentId(p.studentId),
          },
          mainBlockId: row.mainBlockId,
          recallBlockId: row.recallBlockId,
          sheetId: SheetId.tryParse(row.sheetId),
          // Donnée durable : un code inconnu est ignoré, jamais bloquant.
          tags: decodeSessionTags(row.tagsJson, strict: false),
        ),
    ];
  }
}
