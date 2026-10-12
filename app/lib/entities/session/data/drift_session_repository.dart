import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Séances planifiées persistées dans SQLite (drift).
@LazySingleton(as: SessionRepository, env: [Environment.prod])
class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<List<Session>> getAll() async {
    final rows =
        await (_db.select(_db.plannedSessions)
              ..where((s) => s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
            .get();
    return List.unmodifiable([
      for (final row in rows)
        Session(
          id: row.id,
          title: row.title,
          audience: Audience.values.byName(row.audience),
        ),
    ]);
  }

  @override
  Future<void> add(Session session) async {
    final now = _clock.now();
    await _db
        .into(_db.plannedSessions)
        .insert(
          PlannedSessionsCompanion.insert(
            id: session.id,
            title: session.title,
            audience: session.audience.name,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => PlannedSessionsCompanion(
              title: Value(session.title),
              audience: Value(session.audience.name),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.plannedSessions.id],
          ),
        );
  }

  @override
  Future<void> delete(String id) =>
      (_db.update(_db.plannedSessions)..where((s) => s.id.equals(id))).write(
        PlannedSessionsCompanion(deletedAt: Value(_clock.now())),
      );
}
