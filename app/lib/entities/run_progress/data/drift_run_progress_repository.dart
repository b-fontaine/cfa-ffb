import 'dart:async';

import 'package:billard_cfa/entities/run_progress/data/run_progress_json.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Séances guidées en cours persistées dans SQLite (drift, ADR 0020).
///
/// Suppression physique uniquement. Une ligne illisible (JSON mal formé, public
/// inconnu, bornes violées) est supprimée à la lecture : elle ne bloque
/// jamais l'ouverture de l'application.
@LazySingleton(as: RunProgressRepository, env: [Environment.prod])
class DriftRunProgressRepository implements RunProgressRepository {
  DriftRunProgressRepository(this._db);

  final AppDatabase _db;
  final _erased = StreamController<RunProgressLinks>.broadcast();

  @override
  Stream<RunProgressLinks> get erased => _erased.stream;

  @override
  Future<void> save(RunProgress progress) => _db
      .into(_db.runProgressEntries)
      .insertOnConflictUpdate(
        RunProgressEntriesCompanion.insert(
          runKey: progress.key.encoded,
          sheetId: progress.key.sheetId.value,
          audience: Value(progress.key.audience?.name),
          sessionId: Value(progress.key.sessionId),
          groupId: Value(progress.key.groupId?.value),
          recordId: Value(progress.recordId?.value),
          step: progress.step,
          countsJson: RunProgressJson.encodeCounts(progress.counts),
          checkedJson: RunProgressJson.encodeChecked(progress.checked),
          scoreA: progress.scoreA,
          scoreB: progress.scoreB,
          timerSeconds: progress.timerSeconds,
          updatedAt: progress.updatedAt,
        ),
      );

  @override
  Future<RunProgress?> byKey(RunProgressKey key) async {
    final row = await (_db.select(
      _db.runProgressEntries,
    )..where((p) => p.runKey.equals(key.encoded))).getSingleOrNull();
    return row == null ? null : await _readOrErase(row);
  }

  @override
  Future<List<RunProgress>> all() async {
    final rows = await _db.select(_db.runProgressEntries).get();
    final progress = <RunProgress>[];
    for (final row in rows) {
      final read = await _readOrErase(row);
      if (read != null) progress.add(read);
    }
    // Plus récent d'abord ; tri stable (ordre de lecture à égalité).
    return progress..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> delete(RunProgressKey key) => (_db.delete(
    _db.runProgressEntries,
  )..where((p) => p.runKey.equals(key.encoded))).go();

  @override
  Future<void> eraseLinked({
    Set<GroupId> groups = const {},
    Set<SessionId> records = const {},
    Set<String> plannedSessions = const {},
  }) async {
    final links = RunProgressLinks(
      groups: groups,
      records: records,
      plannedSessions: plannedSessions,
    );
    if (links.isEmpty) return;
    await (_db.delete(_db.runProgressEntries)..where(
          (p) =>
              p.groupId.isIn([for (final group in groups) group.value]) |
              p.recordId.isIn([for (final record in records) record.value]) |
              p.sessionId.isIn(plannedSessions),
        ))
        .go();
    _erased.add(links);
  }

  @override
  Future<int> purgeOlderThan(DateTime limit) async {
    final rows = await _db.select(_db.runProgressEntries).get();
    final stale = [
      for (final row in rows)
        if (row.updatedAt.isBefore(limit)) row.runKey,
    ];
    if (stale.isEmpty) return 0;
    final erased = await (_db.delete(
      _db.runProgressEntries,
    )..where((p) => p.runKey.isIn(stale))).go();
    return erased;
  }

  /// La progression de [row], ou `null` (et la ligne est supprimée) si elle
  /// est illisible.
  Future<RunProgress?> _readOrErase(RunProgressRow row) async {
    try {
      return RunProgress(
        key: RunProgressKey(
          sheetId: SheetId(row.sheetId),
          audience: row.audience == null ? null : _audienceNamed(row.audience!),
          sessionId: row.sessionId,
          groupId: row.groupId == null ? null : GroupId(row.groupId!),
        ),
        updatedAt: row.updatedAt,
        step: row.step,
        counts: RunProgressJson.decodeCounts(row.countsJson),
        checked: RunProgressJson.decodeChecked(row.checkedJson),
        scoreA: row.scoreA,
        scoreB: row.scoreB,
        timerSeconds: row.timerSeconds,
        recordId: row.recordId == null ? null : SessionId(row.recordId!),
      );
    } on Exception catch (_) {
      await _erase(row);
    }
    return null;
  }

  static Audience _audienceNamed(String name) =>
      Audience.values.asNameMap()[name] ??
      (throw const FormatException('public inconnu'));

  Future<void> _erase(RunProgressRow row) => (_db.delete(
    _db.runProgressEntries,
  )..where((p) => p.runKey.equals(row.runKey))).go();
}
