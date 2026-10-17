import 'dart:async';

import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: RunProgressRepository, env: [Environment.test])
class InMemoryRunProgressRepository implements RunProgressRepository {
  final Map<RunProgressKey, RunProgress> _progress = {};
  final _erased = StreamController<RunProgressLinks>.broadcast();

  @override
  Stream<RunProgressLinks> get erased => _erased.stream;

  @override
  Future<void> save(RunProgress progress) async =>
      _progress.journaledPut(progress.key, progress);

  @override
  Future<RunProgress?> byKey(RunProgressKey key) async => _progress[key];

  @override
  Future<List<RunProgress>> all() async =>
      _progress.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> delete(RunProgressKey key) async =>
      _progress.journaledRemove(key);

  @override
  Future<void> eraseLinked({
    Set<GroupId> groups = const {},
    Set<SessionId> records = const {},
    Set<String> plannedSessions = const {},
  }) async {
    for (final progress in _progress.values.toList()) {
      if (groups.contains(progress.key.groupId) ||
          records.contains(progress.recordId) ||
          plannedSessions.contains(progress.key.sessionId)) {
        _progress.journaledRemove(progress.key);
      }
    }
    final links = RunProgressLinks(
      groups: groups,
      records: records,
      plannedSessions: plannedSessions,
    );
    if (!links.isEmpty) _erased.add(links);
  }

  @override
  Future<int> purgeOlderThan(DateTime limit) async {
    final stale = [
      for (final progress in _progress.values)
        if (progress.updatedAt.isBefore(limit)) progress.key,
    ]..forEach(_progress.journaledRemove);
    return stale.length;
  }
}
